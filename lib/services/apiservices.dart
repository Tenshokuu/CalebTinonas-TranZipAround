import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiServices {
  static const _baseUrl = 'https://datamall2.mytransport.sg/ltaodataservice';
  static const _apiKey = 'hDk1BfHDTYahruSQr2myMg==';
  static const _headers = {'AccountKey': _apiKey, 'accept': 'application/json'};

  static Future<List<dynamic>> getBusStops({int skip = 0}) async {
    final url = Uri.parse('$_baseUrl/BusStops?\$skip=$skip');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['value'];
    } else {
      throw Exception('Failed to fetch bus stops');
    }
  }

  static Future<Map<String, dynamic>> getBusArrivals(String busStopCode) async {
    final url = Uri.parse('$_baseUrl/v3/BusArrival?BusStopCode=$busStopCode');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch bus arrivals');
    }
  }

  static Future<List<dynamic>> getBusServices() async {
    final url = Uri.parse('$_baseUrl/BusServices');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['value'];
    } else {
      throw Exception('Failed to fetch bus services');
    }
  }

  static Future<List<dynamic>> getBusRoutes() async {
    final url = Uri.parse('$_baseUrl/BusRoutes');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['value'];
    } else {
      throw Exception('Failed to fetch bus routes');
    }
  }

  static Future<List<dynamic>> getTrafficIncidents() async {
    final url = Uri.parse('$_baseUrl/TrafficIncidents');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['value'];
    } else {
      throw Exception('Failed to fetch traffic incidents');
    }
  }

  static Future<List<dynamic>> getTrainCrowdLevel(String lineCode) async {
    final url = Uri.parse('$_baseUrl/PCDRealTime?TrainLine=$lineCode');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['value'];
    } else {
      throw Exception('Failed to fetch train crowd level');
    }
  }

  static Future<List<dynamic>> getTrainNews() async {
    final url = Uri.parse('$_baseUrl/TrainServiceAlerts');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['value'] is List) {
        final List<dynamic> alerts = body['value'];

        return alerts.where((alert) {
          final status = alert['Status']?.toString() ?? '1';
          return status != '1';
        }).toList();
      }
      return [];
    } else {
      throw Exception('Failed to fetch train service alerts');
    }
  }
}
