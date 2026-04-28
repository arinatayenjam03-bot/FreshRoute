# FreshRoute

> **AI-Powered Logistics Platform for Farmer Produce Routing**

FreshRoute tells small farmers exactly where to take their produce based on freshness levels, buyer demand, and optimal routing. Using real-time sensor data, weather intelligence, and agentic AI analysis, FreshRoute maximizes profit and minimizes waste.

---

## Demo & Screenshots

### 🎥 Video Demo

Watch FreshRoute in action on YouTube:

<div align="center">
  
[![FreshRoute Demo - AI Routing Platform](https://img.youtube.com/vi/eqnd0IeCWjM/0.jpg)](https://www.youtube.com/watch?v=eqnd0IeCWjM)

**[Click to Watch Full Demo →](https://www.youtube.com/watch?v=eqnd0IeCWjM)**

</div>

### 📱 App Screenshots

#### Dashboard Screen
| main app ui elements | 
|:---:|:---:|:---:|
| ![complete](https://github.com/arinatayenjam03-bot/FreshRoute/blob/main/docs/screenshots/Mandi%20Aggregators(%20e.g.%20Ninjacart,%20Dehaat).png?raw=true) | 
| we have a total of  16 screens but for now here are the main ones |


### Key Features Showcased

✨ **Real-time Freshness Monitoring** — MQ-135 & DHT-22 sensor integration  
✨ **AI Route Optimization** — CrewAI + Ollama intelligent routing  
✨ **Weather-Aware Routing** — Adjusts paths based on rain/storms  
✨ **Demand Matching** — Prioritizes high-demand vendors  
✨ **Profit Analysis** — Cost-benefit breakdown via LLM  
✨ **Regional Market News** — Live market prices & logistics updates  

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Backend Setup](#backend-setup)
- [Frontend Setup (Flutter)](#frontend-setup-flutter)
- [Local Network Configuration](#local-network-configuration)
- [Running the Application](#running-the-application)
- [API Endpoints](#api-endpoints)
- [Application Usage Guide](#application-usage-guide)
- [Application Logic Diagram](#application-logic-diagram)
- [Architecture Overview](#architecture-overview)

---

## Overview

**FreshRoute** is a full-stack application designed for small-scale farmers in North-East India (Assam region) to:

✓ Monitor produce freshness in real-time via IoT sensors  
✓ Get AI-powered routing recommendations to nearby buyers  
✓ Optimize delivery sequences based on demand, distance, and freshness urgency  
✓ Track orders and receive market intelligence  
✓ Maximize profits through efficient logistics  

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Frontend** | Flutter (Dart) — iOS, Android, Web, Desktop |
| **Backend** | Python (FastAPI) — Async REST API |
| **AI/LLM** | CrewAI + Ollama (Qwen 2.5:3b) — Local LLM inference |
| **Database** | Firebase Firestore — Real-time data sync |
| **Geolocation** | GPS + Open-Meteo API (weather), Nominatim (reverse geocoding) |
| **Hardware** | MQ-135 gas sensor, DHT-22 (temp/humidity), IoT sensor array |

---

## Project Structure

```
FreshRoute/
├── backend/                          # Python FastAPI server
│   ├── freshvend_backend.py         # Main API server (agentic routes)
│   ├── firebase_config.py           # Firebase Firestore integration
│   ├── firebase_config.py           # Service account setup
│   ├── vendors.csv                  # Vendor market data
│   ├── sensor_dump.csv              # Sensor data feed
│   └── requirements.txt             # Python dependencies
│
├── freshvend/                       # Flutter mobile app
│   ├── lib/                         # Dart source code
│   │   ├── main.dart                # App entry point
│   │   ├── screens/                 # UI screens
│   │   └── services/                # API services
│   ├── android/                     # Android platform config
│   ├── ios/                         # iOS platform config
│   ├── pubspec.yaml                 # Flutter dependencies
│   └── pubspec.lock                 # Dependency lock file
│
├── hardware/                        # Sensor firmware & schematics
│   └── (sensor calibration, Arduino/ESP sketches)
│
├── docs/
│   └── screenshots/                 # App screenshots
│
└── README.md                        # This file
```

---

## Backend Setup

### Prerequisites

- **Python 3.8+** (3.10+ recommended)
- **Ollama** running locally or on network
- **Firebase project** with Firestore enabled
- **pip** package manager
- **Git**

### Step 1: Clone Repository & Navigate to Backend

```bash
git clone https://github.com/arinatayenjam03-bot/FreshRoute.git
cd FreshRoute/backend
```

### Step 2: Create Virtual Environment

```bash
# macOS / Linux
python3 -m venv venv
source venv/bin/activate

# Windows
python -m venv venv
venv\Scripts\activate
```

### Step 3: Install Dependencies

```bash
pip install fastapi uvicorn pydantic firebase-admin crewai requests python-dotenv
```

Or install from requirements file (if available):
```bash
pip install -r requirements.txt
```

### Step 4: Firebase Credentials Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Enable **Firestore Database**
4. Generate a **service account key** (JSON)
5. Place the JSON file in `backend/` directory and name it `serviceAccountKey.json`

Or set environment variable:
```bash
export FIREBASE_CREDENTIALS="path/to/serviceAccountKey.json"
```

### Step 5: Configure Environment Variables

Create a `.env` file in `backend/` directory:

```bash
# Firebase
FIREBASE_CREDENTIALS=serviceAccountKey.json

# Ollama Configuration
OLLAMA_BASE=http://localhost:11434
OLLAMA_MODEL=qwen2.5:3b

# Sensor Data
SENSOR_CSV_PATH=sensor_dump.csv
VENDOR_CSV_PATH=vendors.csv
POLL_INTERVAL_SECS=600
```

### Step 6: Start Ollama Service

**Option A: Local Machine**
```bash
ollama pull qwen2.5:3b
ollama serve
```

**Option B: Docker**
```bash
docker run -d -p 11434:11434 ollama/ollama
docker exec <container_id> ollama pull qwen2.5:3b
```

### Step 7: Prepare CSV Data Files

Ensure these files exist in `backend/`:

**sensor_dump.csv:**
```csv
temperature,humidity,mq135_ppm,produce_type,farmer_id
22.5,65.3,450.2,tomato,farmer_1
23.1,64.8,455.7,tomato,farmer_1
```

**vendors.csv:**
```csv
id,name,area,demand_kg,lat,lon
v1,City Market Main,Guwahati,50.0,26.1445,91.7362
v2,Kachari Bazaar,Guwahati,35.5,26.1532,91.7412
```

### Step 8: Start Backend Server

```bash
cd backend
python freshvend_backend.py
```

Or with uvicorn directly:
```bash
uvicorn freshvend_backend:app --host 0.0.0.0 --port 8000 --reload
```

**Expected Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

---

## Frontend Setup (Flutter)

### Prerequisites

- **Flutter SDK 3.8+** — [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (comes with Flutter)
- **Android Studio** or **Xcode** (for device emulation)
- **Git**

### Step 1: Check Flutter Installation

```bash
flutter --version
flutter doctor
```

Fix any issues reported by `flutter doctor`.

### Step 2: Clone Repository & Navigate to Frontend

```bash
cd FreshRoute/freshvend
```

### Step 3: Get List of Available Devices

```bash
flutter devices
```

**Output example:**
```
2 connected devices:

Android SDK built for x86    • emulator-5554              • android-x86    • Android 13 (API 33)
iPhone 15 Pro Simulator      • D1234A5B6C7E8F9G           • ios            • iOS 17.0
```

### Step 4: Clean Flutter Build Cache

```bash
flutter clean
```

### Step 5: Fetch Dependencies

```bash
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in freshvend...
Resolving dependencies...
+ provider 6.1.2
+ http 1.2.1
+ geolocator 11.0.0
...
Got dependencies in 15.2s.
```

### Step 6: Analyze Code (Optional)

```bash
flutter analyze
```

### Step 7: Run on Device/Emulator

**Run on default device:**
```bash
flutter run
```

**Run on specific device:**
```bash
flutter run -d emulator-5554      # Android
flutter run -d D1234A5B6C7E8F9G   # iOS Simulator
flutter run -d chrome              # Web
```

**Build APK (Android release):**
```bash
flutter build apk --release
```

**Build IPA (iOS release):**
```bash
flutter build ios --release
```

---

## Local Network Configuration

### Critical: WiFi Network Setup for Device-to-Backend Communication

The Flutter app must communicate with the backend server over your **local WiFi network**. Both devices must be on the **same WiFi network** for this to work.

#### Step 1: Find Your Backend Server's Local IP Address

**On macOS / Linux:**
```bash
ifconfig | grep "inet "
# Look for en0 or wlan0, find 192.168.x.x or 10.0.x.x
```

**On Windows:**
```bash
ipconfig
# Look for IPv4 Address under your WiFi adapter (usually 192.168.x.x)
```

**Example:** `192.168.1.100`

#### Step 2: Verify Backend is Accessible on Network

From your **Flutter development machine**:
```bash
curl http://192.168.1.100:8000/vendors/
```

You should get a JSON response. If not, check:
- Both devices on same WiFi
- Firewall not blocking port 8000
- Backend running and listening on `0.0.0.0:8000`

#### Step 3: Configure Flutter App to Connect to Backend

Edit your Flutter app's API service file (typically `lib/services/api_service.dart`):

```dart
// Replace localhost with your backend IP
const String API_BASE_URL = 'http://192.168.1.100:8000';

// Example endpoint
Future<List<Vendor>> getVendors() async {
  final response = await http.get(
    Uri.parse('$API_BASE_URL/vendors/'),
  );
  return parseVendors(response.body);
}
```

#### Step 4: Configure Geolocation Service

In Flutter app config, set fallback coordinates to your region:

```dart
// Default to Assam region for sensor/weather data
const double DEFAULT_LAT = 26.1445;
const double DEFAULT_LON = 91.7362;
```

#### Step 5: Windows Firewall Configuration (Windows Only)

Allow FastAPI through Windows Defender Firewall:

```powershell
# Run as Administrator in PowerShell:
New-NetFirewallRule -DisplayName "FastAPI 8000" `
  -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

Or via GUI:
1. Windows Defender Firewall → Advanced Settings
2. Inbound Rules → New Rule
3. Port → TCP → 8000 → Allow
4. Name: "FastAPI 8000"

---

## Running the Application

### Quick Start Checklist

#### Backend

- [ ] Virtual environment activated
- [ ] `serviceAccountKey.json` placed in `backend/`
- [ ] Ollama running (`ollama serve`)
- [ ] Environment variables set
- [ ] CSV files (sensors, vendors) present
- [ ] Run: `python freshvend_backend.py`
- [ ] Verify: `curl http://localhost:8000/vendors/`

#### Frontend

- [ ] All Flutter dependencies installed (`flutter pub get`)
- [ ] Device/emulator connected
- [ ] Backend IP configured in API service
- [ ] Same WiFi network verified
- [ ] Run: `flutter run`

### Full Startup Sequence

**Terminal 1 — Backend:**
```bash
cd FreshRoute/backend
source venv/bin/activate  # or: venv\Scripts\activate (Windows)
python freshvend_backend.py # or: python -m uvicorn freshvend_backend:app --reload  
```

**Terminal 2 — Ollama:**
```bash
ollama run qwen2.5:3b
```

**Terminal 3 — Frontend:**
```bash
cd FreshRoute/freshvend
flutter run
```

---

## API Endpoints

### Core Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| **POST** | `/ingest_sensor/` | Manually push sensor CSV row |
| **GET** | `/sensor/latest/` | Get latest freshness reading |
| **GET** | `/vendors/` | List all market vendors |
| **POST** | `/analyse_route/` | AI-powered route analysis & recommendation |
| **GET** | `/routes/recent/` | Last 5 generated routes |
| **POST** | `/order/accept/` | Farmer accepts delivery order |
| **POST** | `/order/modify/` | Modify quantity or drop vendors from route |
| **GET** | `/orders/pending/` | List pending orders |
| **GET** | `/news/` | Regional market/weather/logistics news |
| **POST** | `/ai_insights/` | Location-aware actionable insights |
| **POST** | `/profit_insight/` | Cost-benefit analysis via Qwen LLM |

### Example Requests

**Get All Vendors:**
```bash
curl http://localhost:8000/vendors/
```

**Analyze Route:**
```bash
curl -X POST http://localhost:8000/analyse_route/ \
  -H "Content-Type: application/json" \
  -d '{
    "farmer_id": "farmer_1",
    "available_kg": 100.0,
    "farmer_lat": 26.1445,
    "farmer_lon": 91.7362,
    "selected_vendor_ids": ["v1", "v2"]
  }'
```

**Get News for Location:**
```bash
curl "http://localhost:8000/news/?lat=26.1445&lon=91.7362"
```

---

## Application Usage Guide

### 1. Launch App

```bash
flutter run
```

### 2. Farmer Dashboard

The home screen displays:

- **Freshness Score** — Real-time produce condition (0-100)
- **Urgency Level** — EXCELLENT / GOOD / MODERATE / POOR
- **Available Vendors** — List of nearby buyers
- **Recent Routes** — Last 5 routing suggestions
- **Market News** — Regional updates on prices, weather, road conditions

### 3. Planning a Delivery

**Steps:**

1. **Verify Freshness** — Check sensor readings
2. **Select Vendors** — Choose 2-5 target vendors from list
3. **Specify Quantity** — Enter available kg (e.g., 100 kg)
4. **Tap "Analyze Route"** — AI generates optimal sequence
5. **Review Recommendation** — See distance, time, demand matching
6. **Accept Route** — Confirm and prepare for delivery

### 4. Route Recommendation Details

The AI analyzes:

✓ **Current weather** — Adjusts route if rain/storms expected  
✓ **Produce freshness** — Prioritizes quick-sell options if urgency high  
✓ **Vendor demand** — Visits high-demand vendors first  
✓ **Distance optimization** — Minimizes total km and travel time  

### 5. Modify Route (Mid-Delivery)

If conditions change:

- **Skip a vendor** — Drop from list
- **Reduce quantity** — Adjust kg per stop
- **Reorder stops** — Manually adjust sequence

### 6. View Insights

Dashboard shows:

- **AI Insights** — 3 actionable tips for today (location-specific)
- **Profit Analysis** — Revenue vs. fuel cost
- **Regional News** — Market prices, weather, road updates

---

## Application Logic Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      FRESHROUTE SYSTEM                       │
└──────────────────────────────────────────────────────────────┘

                          ┌─────────────┐
                          │   FARMER    │
                          │   (App)     │
                          └──────┬──────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼──┐  ┌──────▼────┐  ┌───▼─────┐
              │ GPS    │  │ Select    │  │ Provide │
              │ Signal │  │ Vendors   │  │ Qty (kg)│
              └─────┬──┘  └──────┬────┘  └───┬─────┘
                    │           │            │
                    └───────────┼────────────┘
                                │
                    ┌───────────▼──────────┐
                    │   Request to API     │
                    │  /analyse_route/     │
                    └───────────┬──────────┘
                                │
                ┌───────────────▼────────────────┐
                │   BACKEND SERVER (FastAPI)    │
                └───────────────┬────────────────┘
                                │
                ┌───────────────┴──────────────────────┬──────────────┐
                │                                      │              │
         ┌──────▼──────┐                      ┌───────▼────┐   ┌─────▼────┐
         │ Get Latest  │                      │  CrewAI    │   │ Firebase │
         │ Sensor Data │                      │  Agents    │   │ Firestore│
         │ (Freshness) │                      │            │   │          │
         └──────┬──────┘                      └───────┬────┘   └─────┬────┘
                │                                    │              │
                ├────────────────────────────────────┤              │
                │                                    │              │
         ┌──────▼──────┐                  ┌─────────▼───────┐      │
         │ Call Ollama │                  │ Load Vendors    │      │
         │ (Qwen LLM)  │                  │ from Firebase   │      │
         │ for Analysis│                  └────────┬────────┘      │
         └──────┬──────┘                           │               │
                │                           ┌──────▼──────┐        │
                │                           │ Calculate   │        │
                │                           │ Distances   │        │
                │                           │ (Haversine) │        │
                │                           └──────┬──────┘        │
                ├───────────────────────────────────┤               │
                │                                   │               │
                ▼                                   ▼               │
         ┌─────────────────────────────────────────────────┐       │
         │  Agentic Analysis:                              │       │
         │  - Weather context (Open-Meteo API)             │       │
         │  - Produce urgency interpretation               │       │
         │  - Vendor info matching demand                  │       │
         │  - Route optimization (shortest first if rain)  │       │
         │  - Travel time estimates                        │       │
         │  - Profit maximization logic                    │       │
         └────────────┬────────────────────────────────────┘       │
                      │                                             │
                      │    ┌─────────────────────────────────────┐ │
                      └────► Save Route to Firebase ◄────────────┘─┘
                            (ROUTES collection)
                                      │
                      ┌───────────────▼───────────────┐
                      │  Return to App:               │
                      │  - Optimized stop sequence    │
                      │  - Distances & timing         │
                      │  - Freshness urgency          │
                      │  - Reasoning per stop         │
                      └───────────┬───────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   FARMER APP DASHBOARD    │
                    │   - Display Route         │
                    │   - Show Recommendation   │
                    │   - Accept/Modify         │
                    │   - Launch Navigation     │
                    └──────────────────────────┘
```

---

## Architecture Overview

### System Components

```
HARDWARE LAYER
├─ IoT Sensors (Farmer's truck)
│  ├─ DHT-22 (temperature, humidity)
│  ├─ MQ-135 (air quality / produce gas)
│  └─ GPS module
│
└─ Sensor → CSV feed → Backend

BACKEND LAYER (Python FastAPI)
├─ API Server (0.0.0.0:8000)
├─ Firebase Firestore (data persistence)
├─ CrewAI Agent Framework
│  ├─ Produce Routing Analyst
│  ├─ Tools:
│  │  ├─ get_sensor_freshness
│  │  ├─ get_vendor_info
│  │  ├─ calculate_route_distances
│  │  ├─ interpret_produce_urgency
│  │  └─ get_weather_context
│  └─ LLM: Ollama (Qwen 2.5:3b)
└─ Data Sources:
   ├─ Open-Meteo API (real-time weather)
   ├─ Nominatim API (reverse geocoding)
   └─ CSV files (vendors, sensors)

FRONTEND LAYER (Flutter - Cross-Platform)
├─ Mobile (iOS / Android)
├─ Web (Chrome, Safari, Firefox)
├─ UI Components:
│  ├─ Dashboard (freshness, urgency, news)
│  ├─ Vendor selector
│  ├─ Route viewer (map integration)
│  ├─ Order management
│  └─ Insights display
└─ Services:
   ├─ HTTP client (backend API calls)
   ├─ Geolocation service
   ├─ Local storage (SharedPreferences)
   └─ UI state management (Provider)

NETWORK
└─ Local WiFi (192.168.x.x) — Both devices on same network
```

### Data Flow

```
Farmer's Truck (with sensors)
    ↓
Sensor CSV → Backend /ingest_sensor/
    ↓
Firebase Firestore ← Stores sensor + vendor data
    ↓
Flutter App (home screen)
    ↓
[Farmer selects vendors & qty]
    ↓
Request → /analyse_route/ endpoint
    ↓
Backend triggers CrewAI Agent
    ↓
Agent calls Ollama for intelligent analysis
    ↓
Agent uses tools:
  • Fetch freshness score
  • Get vendor demand
  • Calculate distances
  • Check weather
    ↓
LLM generates JSON route plan
    ↓
Backend validates & saves to Firebase
    ↓
Response → Flutter App
    ↓
Farmer sees optimized route on map
    ↓
Farmer accepts → Order recorded
    ↓
Farmer executes delivery
```

### Data Models (Firebase Collections)

**sensor_readings:**
```json
{
  "temperature": 22.5,
  "humidity": 65.3,
  "mq135_ppm": 450.2,
  "produce_type": "tomato",
  "farmer_id": "farmer_1",
  "timestamp": "2026-04-28T10:30:00"
}
```

**vendors:**
```json
{
  "id": "v1",
  "name": "City Market Main",
  "area": "Guwahati",
  "demand_kg": 50.0,
  "lat": 26.1445,
  "lon": 91.7362
}
```

**routes:**
```json
{
  "farmer_id": "farmer_1",
  "created_at": "2026-04-28T10:35:00",
  "result": {
    "freshness_summary": "Good condition",
    "urgency": "GOOD",
    "recommended_route": [
      {
        "vendor_id": "v1",
        "vendor_name": "City Market Main",
        "deliver_kg": 40,
        "lat": 26.1445,
        "lon": 91.7362,
        "leg_km": 5.2,
        "leg_min": 10,
        "reasoning": "Highest demand and closest vendor"
      }
    ],
    "total_km": 12.5,
    "total_time_min": 25,
    "overall_reasoning": "Route prioritizes demand + freshness + distance"
  }
}
```

**orders:**
```json
{
  "route_id": "route_abc123",
  "farmer_id": "farmer_1",
  "status": "pending",
  "created_at": "2026-04-28T10:40:00"
}
```

---

## Troubleshooting

### Backend Won't Start

**Error:** `ModuleNotFoundError: No module named 'crewai'`

**Solution:**
```bash
pip install crewai
```

**Error:** `Firebase credentials not found`

**Solution:**
```bash
# Ensure serviceAccountKey.json in backend/ directory
export FIREBASE_CREDENTIALS="serviceAccountKey.json"
python -m uvicorn freshvend_backend:app --reload  
```

### Ollama Connection Issues

**Error:** `Connection refused: 127.0.0.1:11434`

**Solution:**
```bash
# Start Ollama service
ollama run qwen2.5:3b

# In separate terminal, verify model is available
ollama list
```

### Flutter App Can't Connect to Backend

**Error:** `Failed to connect to http://192.168.1.100:8000`

**Troubleshooting:**
1. Check backend running: `curl http://192.168.1.100:8000/vendors/`
2. Verify same WiFi network: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
3. Check firewall: Windows Defender may block port 8000
4. Ensure API URL correct in `lib/services/api_service.dart`

### Geolocation Permission Denied (Flutter)

**Solution:** Grant location permissions in app settings:
- iOS: Settings → FreshRoute → Location → Always
- Android: Settings → Apps → FreshRoute → Permissions → Location

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the **MIT License** — see the `LICENSE` file for details.

---

## Contact & Support

For issues, questions, or feature requests:

- **GitHub Issues:** [FreshRoute Issues](https://github.com/arinatayenjam03-bot/FreshRoute/issues)
- **Email:** [leimapokpamchingsangamba@gmail.com]

---

**Built with ❤ for small-scale farmers **

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Start Backend | `cd backend && python -m uvicorn freshvend_backend:app --reload  ` |
| Start Ollama | `ollama run qwen2.5:3b` |
| Run Flutter | `flutter run` |
| Check Devices | `flutter devices` |
| Build APK | `flutter build apk --release` |
| Get Local IP | `ifconfig` (Mac) / `ipconfig` (Windows) |
| Test Backend | `curl http://localhost:8000/vendors/` |
| Clean Flutter | `flutter clean && flutter pub get` |
