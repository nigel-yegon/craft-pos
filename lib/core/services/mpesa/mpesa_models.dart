enum PaymentState { idle, initiating, awaitingPin, success, failed, timeout }

class StkPushRequest {
  final String phone;        // 2547XXXXXXXX
  final int amount;          // whole KES
  final String accountRef;   // max 12 chars
  final String description;  // max 13 chars

  const StkPushRequest({
    required this.phone,
    required this.amount,
    required this.accountRef,
    required this.description,
  });

  Map<String, dynamic> toJson(String timestamp, String password) => {
    'BusinessShortCode': _shortcodePlaceholder,
    'Password': password,
    'Timestamp': timestamp,
    'TransactionType': 'CustomerPayBillOnline',
    'Amount': amount,
    'PartyA': phone,
    'PartyB': _shortcodePlaceholder,
    'PhoneNumber': phone,
    'CallBackURL': _callbackPlaceholder,
    'AccountReference': accountRef,
    'TransactionDesc': description,
  };

  // These get overwritten in MpesaStkPush before sending.
  static String _shortcodePlaceholder = '';
  static String _callbackPlaceholder = '';
  static void configure(String shortcode, String callback) {
    _shortcodePlaceholder = shortcode;
    _callbackPlaceholder = callback;
  }
}

class StkPushResult {
  final String merchantRequestId;
  final String checkoutRequestId;
  final String responseCode;
  final String responseDescription;
  final String customerMessage;

  StkPushResult({
    required this.merchantRequestId,
    required this.checkoutRequestId,
    required this.responseCode,
    required this.responseDescription,
    required this.customerMessage,
  });

  factory StkPushResult.fromJson(Map<String, dynamic> j) => StkPushResult(
    merchantRequestId: j['MerchantRequestID'] ?? '',
    checkoutRequestId: j['CheckoutRequestID'] ?? '',
    responseCode: j['ResponseCode'] ?? '',
    responseDescription: j['ResponseDescription'] ?? '',
    customerMessage: j['CustomerMessage'] ?? '',
  );
}

class PaymentStatus {
  final PaymentState state;
  final String? receipt;      // M-Pesa receipt number on success
  final String? message;
  final String? checkoutRequestId;

  const PaymentStatus({
    required this.state,
    this.receipt,
    this.message,
    this.checkoutRequestId,
  });

  static const idle = PaymentStatus(state: PaymentState.idle);
}