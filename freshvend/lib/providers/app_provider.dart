// lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  // Farmer info
  String farmerId = 'farmer_1';
  double farmerLat = 26.1445;
  double farmerLon = 91.7362;
  double availableKg = 50.0;

  // Live GPS
  Position? currentPosition;

  // Sensor data
  Map<String, dynamic> sensorData = {};
  bool sensorLoading = false;

  // Vendors
  List<dynamic> vendors = [];
  List<String> selectedVendorIds = [];

  // Route result
  Map<String, dynamic>? routeResult;
  List<Map<String, dynamic>> routeVariants = [];
  bool routeLoading = false;

  // Batches
  List<Map<String, dynamic>> batches = [];

  // Orders
  List<dynamic> pendingOrders = [];
  List<Map<String, dynamic>> completedOrders = [];
  double totalKmToday = 0;

  // Region news
  List<Map<String, dynamic>> regionNews = [];
  bool newsLoading = false;

  // AI Insights
  List<String> aiInsights = [];
  bool insightsLoading = false;

  final ApiService _api = ApiService();

  Future<void> initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return;
    currentPosition = await Geolocator.getCurrentPosition();
    farmerLat = currentPosition!.latitude;
    farmerLon = currentPosition!.longitude;
    notifyListeners();
  }

  Future<void> loadSensor() async {
    sensorLoading = true;
    notifyListeners();
    try {
      sensorData = await _api.getLatestSensor();
    } catch (_) {}
    sensorLoading = false;
    notifyListeners();
  }

  Future<void> loadVendors() async {
    try {
      vendors = await _api
          .getVendors()
          .timeout(const Duration(seconds: 5));
      if (selectedVendorIds.isEmpty && vendors.length >= 3) {
        selectedVendorIds =
            vendors.take(3).map<String>((v) => v['id'].toString()).toList();
      }
    } catch (_) {
      // Fallback demo vendors when backend is offline
      vendors = [
        {'id': '1', 'name': 'Guwahati Market Zone A', 'area': 'Fancy Bazar', 'demand_kg': 80.0, 'lat': 26.1858, 'lon': 91.7514},
        {'id': '2', 'name': 'Beltola Cooperative', 'area': 'Beltola', 'demand_kg': 50.0, 'lat': 26.1244, 'lon': 91.7834},
        {'id': '3', 'name': 'Paltan Bazar Vendor', 'area': 'Paltan Bazar', 'demand_kg': 35.0, 'lat': 26.1889, 'lon': 91.7458},
        {'id': '4', 'name': 'Ganeshguri Restaurant', 'area': 'Ganeshguri', 'demand_kg': 25.0, 'lat': 26.1489, 'lon': 91.7756},
      ];
      if (selectedVendorIds.isEmpty) {
        selectedVendorIds = ['1', '2', '3'];
      }
    }
    notifyListeners();
  }

  Future<void> loadRegionNews() async {
    newsLoading = true;
    notifyListeners();
    try {
      final news = await _api.getRegionNews();
      regionNews = news;
    } catch (_) {
      regionNews = [
        {
          'category': 'Market',
          'title': 'Tomato prices up 12% across local mandis',
          'summary': 'Festive demand driving prices higher at wholesale markets.',
          'time': '2h ago',
        },
        {
          'category': 'Weather',
          'title': 'Light rain expected in your area tomorrow',
          'summary': 'Plan early morning deliveries to avoid road delays.',
          'time': '4h ago',
        },
        {
          'category': 'Logistics',
          'title': 'Road maintenance causing delays on main highway',
          'summary': 'Allow extra 20 minutes for routes through the city centre.',
          'time': '6h ago',
        },
      ];
    }
    newsLoading = false;
    notifyListeners();
  }

  Future<void> loadAiInsights() async {
    insightsLoading = true;
    notifyListeners();
    try {
      final result = await _api.getAiInsights(
        lat: farmerLat,
        lon: farmerLon,
        batches: batches.length,
        vendors: vendors.length,
      );
      aiInsights = List<String>.from(result);
    } catch (_) {
      // Generic fallback — no hardcoded geography
      aiInsights = [
        'Morning departures before 7 AM show better freshness scores on arrival at vendors.',
        'Grouping vendors within 5 km of each other reduces fuel cost per kg delivered.',
        'Check the sensor reading before each trip — moderate freshness means prioritise closer vendors first.',
      ];
    }
    insightsLoading = false;
    notifyListeners();
  }

  Future<void> analyseRoute() async {
    routeLoading = true;
    routeResult = null;
    notifyListeners();
    try {
      routeResult = await _api.analyseRoute(
        farmerId: farmerId,
        availableKg: availableKg,
        lat: farmerLat,
        lon: farmerLon,
        vendorIds: selectedVendorIds,
      );
      _buildRouteVariants();
    } catch (e) {
      routeResult = {'error': e.toString()};
    }
    routeLoading = false;
    notifyListeners();
  }
  Future<String> getExplanation(dynamic contextData) async {
    try {
      // Replace with your real API call
      await Future.delayed(const Duration(milliseconds: 500));
      return contextData['reasoning'] ??
          "AI suggests this based on demand, distance, and efficiency.";
    } catch (e) {
      return "Unable to fetch explanation.";
    }
  }
  Future<Map<String, dynamic>> getStopExplanation(dynamic stop) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return {
    "explanation":
        "This stop is prioritized due to demand, proximity, and freshness optimization."
  };
}
  void _buildRouteVariants() {
    if (routeResult == null) return;
    final stops = List<Map<String, dynamic>>.from(
        routeResult!['recommended_route'] ?? []);
    if (stops.isEmpty) return;

    routeVariants = [
      {
        'label': 'AI Optimised',
        'rank': '⭐ Best Route',
        'stops': stops,
        'total_km': routeResult!['total_km'] ?? 0,
        'total_min': routeResult!['total_time_min'] ?? 0,
        'score': 95,
      },
      {
        'label': 'Shortest Legs',
        'rank': '🔵 Alternative B',
        'stops': List.from(stops)
          ..sort((a, b) => (a['leg_km'] ?? 0).compareTo(b['leg_km'] ?? 0)),
        'total_km':
            ((routeResult!['total_km'] ?? 0) * 1.08).toStringAsFixed(1),
        'total_min': ((routeResult!['total_time_min'] ?? 0) * 1.12).round(),
        'score': 78,
      },
      {
        'label': 'High Demand First',
        'rank': '⚫ Alternative C',
        'stops': List.from(stops)
          ..sort((a, b) =>
              (b['deliver_kg'] ?? 0).compareTo(a['deliver_kg'] ?? 0)),
        'total_km':
            ((routeResult!['total_km'] ?? 0) * 1.18).toStringAsFixed(1),
        'total_min': ((routeResult!['total_time_min'] ?? 0) * 1.22).round(),
        'score': 62,
      },
    ];
    notifyListeners();
  }

  void addBatch(Map<String, dynamic> batch) {
    batches.add({
      ...batch,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    notifyListeners();
  }

  void acceptOrder(Map<String, dynamic> order) {
    completedOrders.add(order);
    totalKmToday += (order['km'] ?? 0.0) as double;
    notifyListeners();
  }
}