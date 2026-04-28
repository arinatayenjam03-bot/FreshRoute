import os
import firebase_admin
from firebase_admin import credentials, firestore, db
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# Firebase Initialization
# ─────────────────────────────────────────────
# Place your Firebase service account JSON as "serviceAccountKey.json"
# OR set FIREBASE_CREDENTIALS env var to the JSON path

_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return

    cred_path = os.getenv("FIREBASE_CREDENTIALS", "serviceAccountKey.json")

    if os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
    else:
        # Use application default credentials (for Cloud Run / GCP)
        cred = credentials.ApplicationDefault()

    firebase_admin.initialize_app(cred)
    _firebase_initialized = True
    logger.info("Firebase initialized successfully")


def get_db():
    init_firebase()
    return firestore.client()


# ─────────────────────────────────────────────
# Collection helpers
# ─────────────────────────────────────────────
SENSOR_COLLECTION   = "sensor_readings"
VENDORS_COLLECTION  = "vendors"
ORDERS_COLLECTION   = "orders"
ROUTES_COLLECTION   = "routes"


def save_sensor_reading(data: dict):
    """Persist a sensor snapshot to Firestore."""
    db_client = get_db()
    data["timestamp"] = datetime.utcnow().isoformat()
    db_client.collection(SENSOR_COLLECTION).add(data)
    logger.info(f"Sensor reading saved: {data}")


def get_latest_sensor_reading() -> dict | None:
    """Return the most recent sensor reading."""
    db_client = get_db()
    docs = (
        db_client.collection(SENSOR_COLLECTION)
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )
    for doc in docs:
        return doc.to_dict()
    return None


def get_all_vendors() -> list[dict]:
    """Return all vendor documents."""
    db_client = get_db()
    return [doc.to_dict() | {"id": doc.id}
            for doc in db_client.collection(VENDORS_COLLECTION).stream()]


def save_vendor(vendor: dict):
    db_client = get_db()
    db_client.collection(VENDORS_COLLECTION).add(vendor)


def save_route_result(result: dict):
    db_client = get_db()
    result["created_at"] = datetime.utcnow().isoformat()
    db_client.collection(ROUTES_COLLECTION).add(result)


def get_recent_routes(limit: int = 5) -> list[dict]:
    db_client = get_db()
    docs = (
        db_client.collection(ROUTES_COLLECTION)
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .limit(limit)
        .stream()
    )
    return [doc.to_dict() | {"id": doc.id} for doc in docs]


def save_order(order: dict):
    db_client = get_db()
    order["created_at"] = datetime.utcnow().isoformat()
    db_client.collection(ORDERS_COLLECTION).add(order)


def get_pending_orders() -> list[dict]:
    db_client = get_db()
    docs = (
        db_client.collection(ORDERS_COLLECTION)
        .where("status", "==", "pending")
        .stream()
    )
    return [doc.to_dict() | {"id": doc.id} for doc in docs]


def update_order_status(order_id: str, status: str):
    db_client = get_db()
    db_client.collection(ORDERS_COLLECTION).document(order_id).update({"status": status})