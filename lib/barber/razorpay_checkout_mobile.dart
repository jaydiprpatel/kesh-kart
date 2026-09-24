import 'dart:async';
import 'dart:io' show Platform;

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Opens native Razorpay Standard Checkout on Android/iOS only.
///
/// The backend, not this app, creates the order and supplies the public key.
/// A successful native callback is returned to the caller for server-side
/// signature verification; it never grants access by itself.
Future<Map<String, String>> openKeshKartRazorpayCheckout(
  Map<String, dynamic> options,
) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw UnsupportedError(
      'Razorpay checkout is available on Android and iOS.',
    );
  }

  final key = options['key']?.toString().trim() ?? '';
  final orderId = options['order_id']?.toString().trim() ?? '';
  final amount = options['amount'];
  if (key.isEmpty || orderId.isEmpty || amount is! num || amount < 100) {
    throw ArgumentError('A valid server-created payment order is required.');
  }

  final result = Completer<Map<String, String>>();
  final razorpay = Razorpay();

  void finish(Map<String, String> value) {
    if (!result.isCompleted) result.complete(value);
  }

  void fail(Object error, StackTrace stackTrace) {
    if (!result.isCompleted) result.completeError(error, stackTrace);
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
    final payment = response as PaymentSuccessResponse;
    final paymentId = payment.paymentId?.trim() ?? '';
    final callbackOrderId = payment.orderId?.trim() ?? '';
    final signature = payment.signature?.trim() ?? '';
    if (paymentId.isEmpty || callbackOrderId.isEmpty || signature.isEmpty) {
      fail(
        StateError('Razorpay returned an incomplete payment confirmation.'),
        StackTrace.current,
      );
      return;
    }
    finish({
      'razorpay_payment_id': paymentId,
      'razorpay_order_id': callbackOrderId,
      'razorpay_signature': signature,
    });
  });
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
    final failure = response as PaymentFailureResponse;
    fail(
      StateError('Razorpay checkout was not completed (code ${failure.code}).'),
      StackTrace.current,
    );
  });
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
    // The wallet hand-off is informational. Completion still comes through the
    // success/failure callback, so this must not resolve the checkout early.
  });

  try {
    razorpay.open({
      ...options,
      'retry': {'enabled': true, 'max_count': 4},
    });
    return await result.future;
  } finally {
    razorpay.clear();
  }
}
