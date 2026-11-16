// lib/core/services/business_registration_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BusinessRegistrationService {
  static const _baseUrl = 'https://craft.co.ke/api';

  /// Registers the local business with the server so the admin panel
  /// can send notifications to it. Idempotent — safe to call multiple
  /// times.
  static Future<bool> register({
    required String id,
    required String name,
    String? phone,
    String? email,
  }) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_baseUrl/businesses/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'name': name,
          'phone': phone,
          'email': email,
        }),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '📡 [register] POST /businesses/register → ${res.statusCode}');

      if (res.statusCode == 201 || res.statusCode == 200) {
        debugPrint('📡 [register] success: ${res.body}');
        return true;
      }
      debugPrint('📡 [register] failed body: ${res.body}');
      return false;
    } catch (e) {
      debugPrint('📡 [register] error: $e');
      return false;
    }
  }
}