// lib/core/services/mpesa/mpesa_config.dart

class MpesaConfig {
  final String backendUrl;

  const MpesaConfig({required this.backendUrl});

  factory MpesaConfig.fromEnvironment() => const MpesaConfig(
    backendUrl: String.fromEnvironment(
      'MPESA_BACKEND_URL',
      defaultValue: 'https://craft.co.ke',
    ),
  );

  Uri stkPushUri() => Uri.parse('$backendUrl/api/mpesa/stkpush');
  Uri statusUri(String checkoutRequestId) =>
      Uri.parse('$backendUrl/api/mpesa/status/$checkoutRequestId');
}