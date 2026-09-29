import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode = 500, this.details});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _tokenKey = 'auth_jwt_token';
  static const String _userKey = 'auth_user_data';

  String? _token;
  Map<String, dynamic>? _currentUser;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final userDataStr = prefs.getString(_userKey);
      if (userDataStr != null) {
        _currentUser = jsonDecode(userDataStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error inicializando ApiClient: $e');
    }
  }

  Future<void> setSession(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      debugPrint('Error persistiendo sesion: $e');
    }
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    _currentUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      debugPrint('Error actualizando usuario local: $e');
    }
  }

  Future<void> clearSession() async {
    _token = null;
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      debugPrint('Error limpiando sesion: $e');
    }
  }

  Map<String, String> _getHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final base = ApiConfig.baseUrl;
    final fullUrl = '$base$cleanEndpoint';
    final uri = Uri.parse(fullUrl);

    if (queryParams != null && queryParams.isNotEmpty) {
      final queryMap = <String, String>{};
      queryParams.forEach((key, value) {
        if (value != null) {
          queryMap[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: queryMap);
    }
    return uri;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body);
      }
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        if (body.containsKey('data')) {
          return body['data'];
        }
        return body;
      }
      return body;
    }

    String errorMessage = 'Error en el servidor (${response.statusCode})';
    dynamic details;

    if (body is Map<String, dynamic>) {
      if (body['message'] is List) {
        errorMessage = (body['message'] as List).join(', ');
      } else if (body['message'] != null) {
        errorMessage = body['message'].toString();
      }
      details = body['details'] ?? body['error'];
    }

    throw ApiException(errorMessage, statusCode: response.statusCode, details: details);
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      final response = await http.get(uri, headers: _getHeaders(extraHeaders: headers)).timeout(
        const Duration(seconds: 15),
      );
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException('No se pudo conectar con el servidor ($e)');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexion: $e');
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint);
    try {
      final response = await http.post(
        uri,
        headers: _getHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException('No se pudo conectar con el servidor ($e)');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexion: $e');
    }
  }

  Future<dynamic> put(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint);
    try {
      final response = await http.put(
        uri,
        headers: _getHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException('No se pudo conectar con el servidor ($e)');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexion: $e');
    }
  }

  Future<dynamic> patch(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint);
    try {
      final response = await http.patch(
        uri,
        headers: _getHeaders(extraHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException('No se pudo conectar con el servidor ($e)');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexion: $e');
    }
  }

  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      final response = await http.delete(uri, headers: _getHeaders(extraHeaders: headers)).timeout(
        const Duration(seconds: 15),
      );
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException('No se pudo conectar con el servidor ($e)');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexion: $e');
    }
  }
}
