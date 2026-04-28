"""
freshvend_backend.py
──────────────────────────────────────────────────────────────
FreshRoute – Agentic AI backend for farmer produce routing.

Endpoints
  POST /ingest_sensor/          – Manually push sensor CSV row
  GET  /sensor/latest/          – Latest freshness reading
  GET  /vendors/                – All market vendors
  POST /analyse_route/          – Core: run agentic analysis & return best route
  GET  /routes/recent/          – Last 5 generated routes
  POST /order/accept/           – Farmer accepts a delivery order
  POST /order/modify/           – Farmer modifies quantity / drops a stop
  GET  /orders/pending/         – Pending orders
  GET  /news/                   – Regional market/weather/logistics news
  POST /profit_insight/         – AI cost-benefit analysis via Qwen
"""

import os, csv, asyncio, logging, math, json, requests
from datetime import datetime
from functools import lru_cache
from typing import Optional
import requests
import uvicorn
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
from datetime import datetime
from crewai import Agent, Task, Crew, Process, LLM
from crewai.tools import tool

import firebase_config as fb

# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────
os.environ["OPEN_API_KEY"] = "NA"
SENSOR_CSV_PATH = os.getenv("SENSOR_CSV_PATH", "sensor_dump.csv")
VENDOR_CSV_PATH = os.getenv("VENDOR_CSV_PATH", "vendors.csv")
POLL_INTERVAL   = int(os.getenv("POLL_INTERVAL_SECS", "600"))
OLLAMA_BASE     = os.getenv("OLLAMA_BASE", "http://localhost:11434")
OLLAMA_MODEL    = os.getenv("OLLAMA_MODEL", "qwen2.5:3b")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="FreshRoute Agentic API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ──────────────────────────────────────────────
# LLM
# ──────────────────────────────────────────────
@lru_cache(maxsize=1)
def get_llm():
    return LLM(
        model=f"ollama/{OLLAMA_MODEL}",
        base_url=OLLAMA_BASE,
    )


def call_ollama(prompt: str, system: str = "", timeout: int = 60) -> str:
    """
    Direct Ollama call using requests — no CrewAI overhead.
    Used for simple single-turn tasks like profit insight and news generation.
    """
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "system": system,
        "stream": False,
    }
    try:
        r = requests.post(
            f"{OLLAMA_BASE}/api/generate",
            json=payload,
            timeout=timeout,
        )
        r.raise_for_status()
        return r.json().get("response", "").strip()
    except Exception as e:
        logger.warning(f"Ollama call failed: {e}")
        return ""


# ──────────────────────────────────────────────
# Pydantic models
# ──────────────────────────────────────────────
class AiInsightsRequest(BaseModel):
    lat: float
    lon: float
    batches: int = 0
    vendors: int = 0
 
class SensorRow(BaseModel):
    temperature: float
    humidity: float
    mq135_ppm: float
    produce_type: str = "vegetable"
    farmer_id: str = "farmer_1"

class AnalyseRequest(BaseModel):
    farmer_id: str
    available_kg: float
    farmer_lat: float
    farmer_lon: float
    selected_vendor_ids: list[str]

class ModifyRouteRequest(BaseModel):
    route_id: str
    drop_vendor_ids: list[str] = []
    reduce_quantities: dict = {}

class AcceptOrderRequest(BaseModel):
    route_id: str
    farmer_id: str

class ProfitInsightRequest(BaseModel):
    revenue: float
    km: float
    orders: int
    period: str = "Today"


# ──────────────────────────────────────────────
# Helper: parse vendor CSV
# ──────────────────────────────────────────────
def load_vendors_from_csv() -> list[dict]:
    vendors = []
    if not os.path.exists(VENDOR_CSV_PATH):
        logger.warning(f"Vendor CSV not found at {VENDOR_CSV_PATH}")
        return vendors
    with open(VENDOR_CSV_PATH, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            row["demand_kg"] = float(row.get("demand_kg", 0))
            row["lat"]       = float(row.get("lat", 0))
            row["lon"]       = float(row.get("lon", 0))
            vendors.append(row)
    return vendors


def sync_vendors_to_firebase():
    vendors = load_vendors_from_csv()
    db = fb.get_db()
    for v in vendors:
        db.collection(fb.VENDORS_COLLECTION).document(
            str(v.get("id", v.get("vendor_id")))
        ).set(v)
    logger.info(f"Synced {len(vendors)} vendors to Firebase")


# ──────────────────────────────────────────────
# Haversine distance
# ──────────────────────────────────────────────
def haversine_km(lat1, lon1, lat2, lon2) -> float:
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1))
         * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(a))


def estimate_travel_time_min(km: float, speed_kmph: float = 30) -> float:
    return round((km / speed_kmph) * 60, 1)


# ──────────────────────────────────────────────
# Background sensor polling
# ──────────────────────────────────────────────
async def poll_sensor_csv():
    while True:
        await asyncio.sleep(POLL_INTERVAL)
        try:
            if not os.path.exists(SENSOR_CSV_PATH):
                logger.warning(f"sensor_dump.csv not found at '{SENSOR_CSV_PATH}' — skipping poll")
                continue
            with open(SENSOR_CSV_PATH, newline="") as f:
                rows = list(csv.DictReader(f))
            if not rows:
                continue
            row = rows[-1]
            fb.save_sensor_reading({
                "temperature":  float(row.get("temperature", 0)),
                "humidity":     float(row.get("humidity", 0)),
                "mq135_ppm":    float(row.get("mq135_ppm", 0)),
                "produce_type": row.get("produce_type", "vegetable"),
                "farmer_id":    row.get("farmer_id", "farmer_1"),
            })
            logger.info(f"Sensor CSV polled — saved row: {row}")
        except Exception as e:
            logger.warning(f"Sensor poll error: {e}")


@app.on_event("startup")
async def startup():
    asyncio.create_task(poll_sensor_csv())
    try:
        sync_vendors_to_firebase()
    except Exception as e:
        logger.warning(f"Vendor sync failed (Firebase may be offline): {e}")


# ──────────────────────────────────────────────
# CrewAI Tools
# ──────────────────────────────────────────────

@tool("get_sensor_freshness")
def get_sensor_freshness(farmer_id: str = "farmer_1") -> str:
    """Returns the latest sensor reading and freshness score for the farmer's produce."""
    reading = fb.get_latest_sensor_reading()
    if not reading:
        return "No sensor data available."
    temp  = reading.get("temperature", 0)
    humid = reading.get("humidity", 0)
    gas   = reading.get("mq135_ppm", 0)
    temp_score  = max(0, 100 - abs(temp - 10) * 5)
    humid_score = max(0, 100 - abs(humid - 80) * 2)
    gas_score   = max(0, 100 - gas * 0.2)
    freshness   = round((temp_score + humid_score + gas_score) / 3, 1)
    status = ("EXCELLENT" if freshness > 80 else "GOOD" if freshness > 60
              else "MODERATE" if freshness > 40 else "POOR")
    return (
        f"Sensor Reading @ {reading.get('timestamp', 'N/A')}\n"
        f"  Temperature : {temp}°C\n"
        f"  Humidity    : {humid}%\n"
        f"  MQ135 gas   : {gas} ppm\n"
        f"  Freshness   : {freshness}/100 ({status})\n"
        f"  Produce     : {reading.get('produce_type', 'vegetable')}"
    )


@tool("get_vendor_info")
def get_vendor_info(vendor_ids: str) -> str:
    """Returns demand and location info for comma-separated vendor IDs. Example: 'v1,v2,v3'"""
    ids = [v.strip() for v in vendor_ids.split(",")]
    vendors = fb.get_all_vendors()
    selected = [v for v in vendors if v.get("id") in ids]
    if not selected:
        return "No matching vendors found."
    lines = ["Vendor Market Information:"]
    for v in selected:
        lines.append(
            f"  [{v['id']}] {v['name']} – Area: {v['area']}, "
            f"Demand: {v['demand_kg']}kg, "
            f"GPS: ({v['lat']}, {v['lon']})"
        )
    return "\n".join(lines)


@tool("calculate_route_distances")
def calculate_route_distances(route_json: str) -> str:
    """
    Calculates distances between route points.
    Input JSON: {"origin": [lat, lon], "stops": [[lat, lon], ...]}
    """
    try:
        data     = json.loads(route_json)
        origin   = data["origin"]
        stops    = data["stops"]
        results  = []
        prev     = origin
        total_km = 0
        for i, stop in enumerate(stops):
            km   = haversine_km(prev[0], prev[1], stop[0], stop[1])
            mins = estimate_travel_time_min(km)
            total_km += km
            results.append(f"  Leg {i+1}: {round(km, 2)} km, ~{mins} min")
            prev = stop
        return (
            "Route distance breakdown:\n" + "\n".join(results) +
            f"\n  TOTAL: {round(total_km, 2)} km, ~{estimate_travel_time_min(total_km)} min"
        )
    except Exception as e:
        return f"Route calculation error: {e}"


@tool("interpret_produce_urgency")
def interpret_produce_urgency(sensor_summary: str) -> str:
    """Given a sensor summary string, returns dispatch urgency recommendation."""
    if "POOR" in sensor_summary:
        return "URGENT: Produce freshness is poor. Dispatch IMMEDIATELY to maximise value."
    elif "MODERATE" in sensor_summary:
        return "MODERATE: Freshness degrading. Aim to dispatch within 3-4 hours."
    elif "GOOD" in sensor_summary:
        return "GOOD: Produce is in good shape. Dispatch within 12 hours is fine."
    else:
        return "EXCELLENT: Produce is very fresh. Flexible dispatch window up to 24 hours."


@tool("get_weather_context")
def get_weather_context(lat: str = "26.14", lon: str = "91.74") -> str:
    """Fetches real-time weather using Open-Meteo (free, no API key needed)."""
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            f"&current=temperature_2m,precipitation,windspeed_10m,weathercode"
            f"&timezone=Asia%2FKolkata"
        )
        r    = requests.get(url, timeout=8)
        data = r.json().get("current", {})
        temp  = data.get("temperature_2m", "N/A")
        rain  = data.get("precipitation", 0)
        wind  = data.get("windspeed_10m", 0)
        wcode = data.get("weathercode", 0)
        if wcode >= 95:
            road_risk = "SEVERE — thunderstorm likely, avoid longer routes"
        elif wcode >= 51 or rain > 5:
            road_risk = "HIGH — rainfall active, rural roads may be waterlogged"
        elif rain > 0:
            road_risk = "MODERATE — light rain, allow extra travel time"
        else:
            road_risk = "LOW — clear conditions, normal routing"
        return (
            f"Weather @ ({lat}, {lon}):\n"
            f"  Temperature : {temp}°C\n"
            f"  Precipitation: {rain} mm\n"
            f"  Wind Speed  : {wind} km/h\n"
            f"  Road Risk   : {road_risk}\n"
            f"  Advisory    : "
            f"{'Prefer shorter routes and high-demand stops first.' if rain > 2 else 'Normal routing is safe.'}"
        )
    except Exception as e:
        return f"Weather unavailable ({e}). Assume normal conditions."


# ──────────────────────────────────────────────
# Agentic route analysis
# ──────────────────────────────────────────────
async def run_agent_analysis(
    farmer_lat: float,
    farmer_lon: float,
    available_kg: float,
    vendors: list[dict],
) -> dict:
    llm            = get_llm()
    vendor_ids_str = ",".join(v["id"] for v in vendors)
    stops          = [[v["lat"], v["lon"]] for v in vendors]
    route_input    = json.dumps({"origin": [farmer_lat, farmer_lon], "stops": stops})

    route_agent = Agent(
        role="Produce Routing Analyst",
        goal=(
            "Analyse vendor demand, produce freshness, weather, and route distances "
            "to recommend the best delivery sequence for a farmer."
        ),
        backstory=(
            "Expert in agri-logistics for North-East India. Understands rural road "
            "conditions, produce perishability, and Assam market demand dynamics."
        ),
        tools=[
            get_sensor_freshness,
            get_vendor_info,
            calculate_route_distances,
            interpret_produce_urgency,
            get_weather_context,
        ],
        llm=llm,
        verbose=False,
    )

    task = Task(
        description=f"""
You are helping a farmer plan deliveries.

Farmer GPS: ({farmer_lat}, {farmer_lon})
Available produce: {available_kg} kg
Vendors (IDs): {vendor_ids_str}

Step 1 – Call get_weather_context with lat="{farmer_lat}" lon="{farmer_lon}".
Step 2 – Call get_sensor_freshness to check produce condition.
Step 3 – Call interpret_produce_urgency with that summary.
Step 4 – Call get_vendor_info with vendor IDs: {vendor_ids_str}
Step 5 – Call calculate_route_distances with: {route_input}
Step 6 – Combine weather + freshness + demand + distance to plan the best route.
         If weather road risk is HIGH or SEVERE, prioritise shorter legs first.

Return ONLY valid JSON with this exact structure, no markdown fences:
{{
  "freshness_summary": "<one sentence>",
  "urgency": "<URGENT|MODERATE|GOOD|EXCELLENT>",
  "recommended_route": [
    {{
      "vendor_id": "v1",
      "vendor_name": "...",
      "deliver_kg": 10,
      "area": "...",
      "lat": 26.15,
      "lon": 91.74,
      "leg_km": 5.2,
      "leg_min": 10,
      "reasoning": "<50-80 word reason for this stop>"
    }}
  ],
  "total_km": 15.4,
  "total_time_min": 31,
  "overall_reasoning": "<50-80 words on the full route choice>"
}}
        """,
        agent=route_agent,
        expected_output="Valid JSON route plan.",
    )

    crew   = Crew(agents=[route_agent], tasks=[task], process=Process.sequential, verbose=False)
    result = await asyncio.to_thread(crew.kickoff)
    raw    = str(result).strip().replace("```json", "").replace("```", "").strip()

    try:
        parsed = json.loads(raw)
    except Exception:
        parsed = {"raw_output": raw, "error": "Could not parse JSON from LLM output"}

    # Inject real vendor coords (LLM may hallucinate)
    vendor_coord_map = {v["id"]: (v["lat"], v["lon"]) for v in vendors}
    for stop in parsed.get("recommended_route", []):
        vid = stop.get("vendor_id", "")
        if vid in vendor_coord_map:
            stop["lat"] = vendor_coord_map[vid][0]
            stop["lon"] = vendor_coord_map[vid][1]

    return parsed

def _reverse_geocode(lat: float, lon: float) -> str:
    """Returns a short human-readable location name using Nominatim."""
    try:
        url = (
            f"https://nominatim.openstreetmap.org/reverse"
            f"?lat={lat}&lon={lon}&format=json&zoom=12&addressdetails=1"
        )
        r = requests.get(
            url,
            timeout=6,
            headers={"User-Agent": "FreshRoute/1.0"}
        )
        r.raise_for_status()  # ✅ prevents silent failures

        data = r.json()
        addr = data.get("address", {})

        parts = []
        for key in ["suburb", "neighbourhood", "village", "town", "city", "county", "state"]:
            if addr.get(key):
                parts.append(addr[key])
                if len(parts) == 2:
                    break

        return ", ".join(parts) if parts else f"{lat:.2f}, {lon:.2f}"

    except Exception:
        return f"{lat:.2f}, {lon:.2f}"
def generate_location_news(lat: float, lon: float) -> list[dict]:
    location = _reverse_geocode(lat, lon)
    today = datetime.now().strftime("%d %B %Y")

    prompt = f"""
Today is {today}. The farmer is located near: {location} ({lat:.4f}, {lon:.4f}).

Generate 4 short news items relevant to this location.

Return ONLY JSON array.
"""

    system = "Return only valid JSON."

    raw = call_ollama(prompt, system=system, timeout=45)

    try:
        raw = raw.replace("```json", "").replace("```", "").strip()
        news = json.loads(raw)

        if isinstance(news, list) and len(news) > 0:
            return news

    except Exception as e:
        logger.warning(f"Location news parse failed: {e}")

    return [
        {"category": "Road", "title": f"Check roads near {location}", "summary": "Verify routes.", "time": "1h ago"},
        {"category": "Weather", "title": f"Weather in {location}", "summary": "Check forecast.", "time": "3h ago"},
        {"category": "Market", "title": "Prices stable", "summary": "Demand steady.", "time": "5h ago"},
        {"category": "Alert", "title": "No disruptions", "summary": "Normal operations.", "time": "2h ago"},
    ]
def generate_ai_insights(lat: float, lon: float, batches: int, vendors: int) -> list[str]:
    location = _reverse_geocode(lat, lon)
    
    # Call the raw weather API directly — NOT the CrewAI tool
    weather_summary = "normal conditions"
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            f"&current=temperature_2m,precipitation,windspeed_10m,weathercode"
            f"&timezone=Asia%2FKolkata"
        )
        r = requests.get(url, timeout=6)
        data = r.json().get("current", {})
        rain = data.get("precipitation", 0)
        temp = data.get("temperature_2m", "N/A")
        wcode = data.get("weathercode", 0)
        if wcode >= 95:
            weather_summary = f"thunderstorm warning, temperature {temp}°C"
        elif wcode >= 51 or rain > 5:
            weather_summary = f"active rainfall {rain}mm, roads may be affected"
        elif rain > 0:
            weather_summary = f"light rain {rain}mm, temperature {temp}°C"
        else:
            weather_summary = f"clear conditions, temperature {temp}°C"
    except Exception:
        pass

    prompt = f"""
A vegetable farmer near {location} is using a logistics app.
They have {batches} produce batches and {vendors} vendors in their network.
Current weather: {weather_summary}

Generate exactly 3 short practical insights (one sentence each) to help this farmer
plan better deliveries TODAY. Make them specific to {location} and current conditions.
Cover: timing, route efficiency, and produce handling.

Return ONLY a JSON array of 3 strings, no markdown:
["insight 1", "insight 2", "insight 3"]
"""
    system = (
        "You are a practical agri-logistics advisor for Indian farmers. "
        "Give direct, location-specific one-sentence tips. "
        "Return only a JSON array of 3 strings."
    )
    raw = call_ollama(prompt, system=system, timeout=40)
    try:
        raw = raw.replace("```json", "").replace("```", "").strip()
        insights = json.loads(raw)
        if isinstance(insights, list) and len(insights) >= 1:
            return insights[:3]
    except Exception as e:
        logger.warning(f"AI insights parse failed: {e}")

    return [
        f"Morning departures before 7 AM from {location} show better freshness on arrival.",
        "Group vendors within 5 km of each other to reduce fuel cost per kg delivered.",
        "Check sensor readings before each trip — moderate freshness means prioritise closer vendors first.",
    ]
# ──────────────────────────────────────────────
# News helper — generates regional news via Qwen
# ──────────────────────────────────────────────
def generate_regional_news() -> list[dict]:
    """
    Calls Qwen via Ollama to generate 3 realistic regional market/weather/logistics
    news items relevant to Assam / North-East India produce farmers.
    Falls back to hardcoded items if Ollama is offline.
    """
    today = datetime.now().strftime("%d %B %Y")
    prompt = f"""
Today is {today}. Generate 3 short news items relevant to vegetable/produce farmers 
in Assam, North-East India. Cover: one market price update, one weather advisory, 
one road/logistics update. 

Return ONLY a JSON array, no markdown:
[
  {{"category": "Market", "title": "...", "summary": "...", "time": "2h ago"}},
  {{"category": "Weather", "title": "...", "summary": "...", "time": "4h ago"}},
  {{"category": "Logistics", "title": "...", "summary": "...", "time": "6h ago"}}
]
"""
    system = (
        "You are a regional news aggregator for farmers in Assam, India. "
        "Return only valid JSON arrays. No extra text."
    )
    raw = call_ollama(prompt, system=system, timeout=45)

    try:
        raw = raw.replace("```json", "").replace("```", "").strip()
        news = json.loads(raw)
        if isinstance(news, list) and len(news) > 0:
            return news
    except Exception as e:
        logger.warning(f"News JSON parse failed: {e} — using fallback")

    # Hardcoded fallback
    return [
        {
            "category": "Market",
            "title": "Tomato prices up 12% across Assam mandis",
            "summary": "Festive demand driving prices higher at Guwahati wholesale markets.",
            "time": "2h ago",
        },
        {
            "category": "Weather",
            "title": "Light rain expected in Brahmaputra valley tomorrow",
            "summary": "Plan early morning deliveries to avoid road delays on NH-27.",
            "time": "4h ago",
        },
        {
            "category": "Logistics",
            "title": "Roadwork near Jalukbari causing 20-min delays",
            "summary": "Use Khanapara bypass for faster routes into Guwahati city.",
            "time": "6h ago",
        },
    ]


# ──────────────────────────────────────────────
# API Endpoints
# ──────────────────────────────────────────────

@app.post("/ingest_sensor/")
async def ingest_sensor(row: SensorRow):
    fb.save_sensor_reading(row.dict())
    return {"status": "saved", "data": row.dict()}


@app.get("/sensor/latest/")
async def latest_sensor():
    data = fb.get_latest_sensor_reading()
    if not data:
        raise HTTPException(status_code=404, detail="No sensor data yet")
    return data


@app.get("/vendors/")
async def list_vendors():
    return fb.get_all_vendors()


@app.post("/analyse_route/")
async def analyse_route(req: AnalyseRequest):
    all_vendors = fb.get_all_vendors()
    selected    = [v for v in all_vendors if v.get("id") in req.selected_vendor_ids]
    if not selected:
        raise HTTPException(status_code=404, detail="No matching vendors found.")
    result = await run_agent_analysis(
        farmer_lat=req.farmer_lat,
        farmer_lon=req.farmer_lon,
        available_kg=req.available_kg,
        vendors=selected,
    )
    fb.save_route_result({"farmer_id": req.farmer_id, "result": result})
    return result


@app.post("/order/accept/")
async def accept_order(req: AcceptOrderRequest):
    fb.save_order({
        "route_id":  req.route_id,
        "farmer_id": req.farmer_id,
        "status":    "pending",
    })
    return {"status": "accepted", "route_id": req.route_id}


@app.post("/order/modify/")
async def modify_route(req: ModifyRouteRequest):
    routes = fb.get_recent_routes(limit=20)
    target = next((r for r in routes if r.get("id") == req.route_id), None)
    if not target:
        raise HTTPException(status_code=404, detail="Route not found")
    route_plan = target.get("result", {})
    stops = route_plan.get("recommended_route", [])
    stops = [s for s in stops if s["vendor_id"] not in req.drop_vendor_ids]
    for stop in stops:
        if stop["vendor_id"] in req.reduce_quantities:
            stop["deliver_kg"] = req.reduce_quantities[stop["vendor_id"]]
    route_plan["recommended_route"] = stops
    return {"modified_route": route_plan}


@app.get("/routes/recent/")
async def recent_routes():
    return fb.get_recent_routes()


@app.get("/orders/pending/")
async def pending_orders():
    return fb.get_pending_orders()


@app.get("/news/")
async def get_news(lat: float = 26.14, lon: float = 91.74):
    """
    Location-aware news: road blocks, shutdowns, market prices, weather
    near the farmer's GPS coordinates. Uses reverse geocoding + Qwen.
    """
    news = await asyncio.to_thread(generate_location_news, lat, lon)
    return news

@app.post("/ai_insights/")
async def ai_insights(req: AiInsightsRequest):
    """
    Returns 3 location-aware actionable insights for the farmer's dashboard.
    """
    insights = await asyncio.to_thread(
        generate_ai_insights,
        req.lat,
        req.lon,
        req.batches,
        req.vendors
    )
    return {"insights": insights}
@app.post("/profit_insight/")
async def profit_insight(req: ProfitInsightRequest):
    """
    Returns an AI-generated 3-sentence cost-benefit insight using Qwen.
    Calculates fuel cost internally — never exposes formula to client.
    """
    petrol_price_per_litre = 102.0
    fuel_efficiency_kmpl   = 18.0
    petrol_cost = (req.km / fuel_efficiency_kmpl) * petrol_price_per_litre
    net_profit  = req.revenue - petrol_cost

    prompt = f"""
A vegetable farmer in Assam completed {req.orders} deliveries over {req.period}.
Total revenue: ₹{req.revenue:.0f}
Fuel cost: ₹{petrol_cost:.0f} (for {req.km:.1f} km driven)
Net profit: ₹{net_profit:.0f}

Write exactly 3 sentences of practical business advice for this farmer.
Focus on whether the trips were profitable, what to improve, and one specific actionable tip.
Do not mention any formulas or calculations. Write in plain English.
"""
    system = (
        "You are a practical agri-business advisor for small farmers in India. "
        "Give direct, useful advice. No bullet points, no headings, just 3 sentences."
    )

    insight = await asyncio.to_thread(call_ollama, prompt, system, 60)

    if not insight:
        # Fallback if Ollama is offline
        if net_profit > 0:
            insight = (
                f"Your {req.period.lower()} was profitable with ₹{net_profit:.0f} net earnings after fuel. "
                f"With {req.orders} deliveries across {req.km:.0f} km, your per-trip efficiency looks reasonable. "
                f"To improve further, try grouping nearby vendors into the same trip to reduce fuel spend."
            )
        else:
            insight = (
                f"Your fuel costs exceeded revenue this {req.period.lower()} by ₹{abs(net_profit):.0f}. "
                f"With only {req.orders} deliveries over {req.km:.0f} km, the trips were spread too thin. "
                f"Focus on vendors within 15 km and prioritise those with the highest demand per stop."
            )

    return {"insight": insight, "net_profit": round(net_profit, 2)}


# ──────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
    # To allow phone access, run:
    # New-NetFirewallRule -DisplayName "FastAPI 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow