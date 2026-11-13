import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mpesa_config.dart';

class MpesaAuth {
  final MpesaConfig config;
  MpesaAuth(this.config);

  String? _token;
  DateTime? _expiry;

  Future<String> getToken() async {
    if (_token != null && _expiry != null && DateTime.now().isBefore(_expiry!)) {
      return _token!;
    }

    final creds = base64Encode(
      utf8.encode('${config.consumerKey}:${config.consumerSecret}'),
    );

    final url = Uri.parse(
      '${config.baseUrl}/oauth/v1/generate?grant_type=client_credentials',
    );

    final res = await http.get(
      url,
      headers: {'Authorization': 'Basic $creds'},
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('M-Pesa auth failed: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _token = body['access_token'] as String;
    final expiresIn = int.tryParse('${body['expires_in'] ?? 3599}') ?? 3599;
    // Refresh 60s early
    _expiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    return _token!;
  }

  void clear() {
    _token = null;
    _expiry = null;
  }
}