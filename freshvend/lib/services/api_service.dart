// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final String _base = AppConstants.baseUrl;

  Future<Map<String, dynamic>> ingestSensor(Map<String, dynamic> data) async {
    final r = await http
        .post(
          Uri.parse('$_base/ingest_sensor/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> getLatestSensor() async {
    final r = await http
        .get(Uri.parse('$_base/sensor/latest/'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 404) return {};
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> getVendors() async {
    final r = await http
        .get(Uri.parse('$_base/vendors/'))
        .timeout(const Duration(seconds: 8));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> analyseRoute({
    required String farmerId,
    required double availableKg,
    required double lat,
    required double lon,
    required List<String> vendorIds,
  }) async {
    final r = await http
        .post(
          Uri.parse('$_base/analyse_route/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'farmer_id': farmerId,
            'available_kg': availableKg,
            'farmer_lat': lat,
            'farmer_lon': lon,
            'selected_vendor_ids': vendorIds,
          }),
        )
        .timeout(const Duration(seconds: 120));
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> acceptOrder(
      String routeId, String farmerId) async {
    final r = await http
        .post(
          Uri.parse('$_base/order/accept/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'route_id': routeId, 'farmer_id': farmerId}),
        )
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> getPendingOrders() async {
    final r = await http
        .get(Uri.parse('$_base/orders/pending/'))
        .timeout(const Duration(seconds: 8));
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> getRecentRoutes() async {
    final r = await http
        .get(Uri.parse('$_base/routes/recent/'))
        .timeout(const Duration(seconds: 8));
    return jsonDecode(r.body);
  }

  Future<List<Map<String, dynamic>>> getRegionNews() async {
    final r = await http
        .get(Uri.parse('$_base/news/'))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as List;
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<String>> getAiInsights({
    required double lat,
    required double lon,
    required int batches,
    required int vendors,
  }) async {
    final r = await http
        .post(
          Uri.parse('$_base/ai_insights/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'lat': lat,
            'lon': lon,
            'batches': batches,
            'vendors': vendors,
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      return List<String>.from(data['insights'] ?? []);
    }
    return [];
  }

  Future<Map<String, dynamic>> getProfitInsight({
    required double revenue,
    required double km,
    required int orders,
    required String period,
  }) async {
    final r = await http
        .post(
          Uri.parse('$_base/profit_insight/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'revenue': revenue,
            'km': km,
            'orders': orders,
            'period': period,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode == 200) return jsonDecode(r.body);
    return {'insight': 'Could not load insight. Check backend connection.'};
  }

  Future<Map<String, dynamic>> getProfitAnalysis({
    required List<Map<String, dynamic>> completedOrders,
    required double totalKm,
  }) async {
    final double petrolCost = (totalKm / AppConstants.avgFuelEfficiency) *
        AppConstants.avgPetrolPriceIndia;
    final double revenue = completedOrders.fold(
        0.0, (sum, o) => sum + (o['revenue'] ?? 0.0));
    final double profit = revenue - petrolCost;
    return {
      'revenue': revenue,
      'petrol_cost': petrolCost,
      'profit': profit,
      'total_km': totalKm,
      'orders_count': completedOrders.length,
    };
  }
}