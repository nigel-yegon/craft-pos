import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'mpesa_auth.dart';
import 'mpesa_config.dart';
import 'mpesa_models.dart';

class MpesaStkPush {
  final MpesaConfig config;
  final MpesaAuth auth;

  MpesaStkPush(this.config) : auth = MpesaAuth(config);

  Future<StkPushResult> initiate({
    required String phone,
    required int amount,
    required String accountRef,
    required String description,
  }) async {
    final token = await auth.getToken();

    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final password = base64Encode(
      utf8.encode('${config.shortcode}${config.passkey}$timestamp'),
    );

    final body = {
      'BusinessShortCode': config.shortcode,
      'Password': password,
      'Timestamp': timestamp,
      'TransactionType': 'CustomerPayBillOnline',
      'Amount': amount,
      'PartyA': phone,
      'PartyB': config.shortcode,
      'PhoneNumber': phone,
      'CallBackURL': config.callbackUrl,
      'AccountReference': accountRef,
      'TransactionDesc': description,
    };

    final url = Uri.parse(
      '${config.baseUrl}/mpesa/stkpush/v1/processrequest',
    );

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('STK Push failed: ${res.statusCode} ${res.body}');
    }

    return StkPushResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}