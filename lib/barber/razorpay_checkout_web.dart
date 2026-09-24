import 'dart:convert';
import 'dart:js_interop';

@JS('openKeshKartRazorpayCheckout')
external JSPromise<JSString> _openKeshKartRazorpayCheckout(
  JSString optionsJson,
);

Future<Map<String, String>> openKeshKartRazorpayCheckout(
  Map<String, dynamic> options,
) async {
  final resultJson =
      (await _openKeshKartRazorpayCheckout(jsonEncode(options).toJS).toDart)
          .toDart;
  final decoded = jsonDecode(resultJson) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value.toString()));
}
