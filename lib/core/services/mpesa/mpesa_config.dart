/// M-Pesa Daraja configuration.
///
/// OFFLINE-FIRST NOTE:
/// This config is only read when the app is online and the user
/// attempts a payment. It is never used during normal offline operation.
class MpesaConfig {
  /// Either point this at your own proxy (Cloudflare Worker /
  /// Appwrite Function) OR at Safaricom directly for dev/sandbox only.
  ///
  /// Production: 'https://your-proxy.example.com'
  /// Sandbox dev: 'https://sandbox.safaricom.co.ke'
  final String baseUrl;

  /// Consumer key/secret come from Daraja portal.
  /// NOTE: If you ship these in the binary, assume they are public.
  /// Use a proxy in production.
  final String consumerKey;
  final String consumerSecret;

  /// Lipa na M-Pesa Online shortcode (sandbox = 174379).
  final String shortcode;

  /// Lipa na M-Pesa passkey.
  final String passkey;

  /// Callback URL Safaricom will POST results to.
  /// Must be publicly reachable HTTPS — this is why a proxy is needed
  /// for a purely client-side app.
  final String callbackUrl;

  /// 'sandbox' | 'production'
  final String environment;

  const MpesaConfig({
    required this.baseUrl,
    required this.consumerKey,
    required this.consumerSecret,
    required this.shortcode,
    required this.passkey,
    required this.callbackUrl,
    required this.environment,
  });

  bool get isSandbox => environment == 'sandbox';

  /// Build from compile-time env or fallback constants.
  /// You can pass these with --dart-define.
  factory MpesaConfig.fromEnvironment() {
    return const MpesaConfig(
      baseUrl: String.fromEnvironment(
        'MPESA_BASE_URL',
        defaultValue: 'https://sandbox.safaricom.co.ke',
      ),
      consumerKey: String.fromEnvironment('MPESA_CONSUMER_KEY'),
      consumerSecret: String.fromEnvironment('MPESA_CONSUMER_SECRET'),
      shortcode: String.fromEnvironment(
        'MPESA_SHORTCODE',
        defaultValue: '174379',
      ),
      passkey: String.fromEnvironment('MPESA_PASSKEY'),
      callbackUrl: String.fromEnvironment('MPESA_CALLBACK_URL'),
      environment: String.fromEnvironment(
        'MPESA_ENV',
        defaultValue: 'sandbox',
      ),
    );
  }
}