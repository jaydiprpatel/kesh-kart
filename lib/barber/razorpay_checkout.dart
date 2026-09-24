import 'razorpay_checkout_stub.dart'
    if (dart.library.io) 'razorpay_checkout_mobile.dart'
    if (dart.library.js_interop) 'razorpay_checkout_web.dart'
    as implementation;

Future<Map<String, String>> openKeshKartRazorpayCheckout(
  Map<String, dynamic> options,
) => implementation.openKeshKartRazorpayCheckout(options);
