import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'mpesa_auth.dart';
import 'mpesa_config.dart';

class MpesaQuery {
  final MpesaConfig config;
  final MpesaAuth auth;
  MpesaQuery(this.config, this.auth);

  /// Returns raw JSON from Safaricom:
  /// - ResultCode '0'     => success
  /// - ResultCode '1032'  => cancelled by user
  /// - ResultCode '1037'  => timeout / no response
  /// - '1032'/'1037'      => failed
  /// - anything else      => failed
  Future<Map<String, dynamic>> query(String checkoutRequestId) async {
    final token = await auth.getToken();
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final password = base64Encode(
      utf8.encode('${config.shortcode}${config.passkey}$timestamp'),
    );

    final body = {
      'BusinessShortCode': config.shortcode,
      'Password': password,
      'Timestamp': timestamp,
      'CheckoutRequestID': checkoutRequestId,
    };

    final url = Uri.parse('${config.baseUrl}/mpesa/stkpushquery/v1/query');
    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('STK Query failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}