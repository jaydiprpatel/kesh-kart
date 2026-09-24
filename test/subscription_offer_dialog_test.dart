import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesh_kart/barber/subscription_offer_dialog.dart';

Map<String, dynamic> quote({int amount = 19900}) => {
  'amount': amount,
  'original_amount': 19900,
  'discount': 19900 - amount,
  'duration_days': 7,
  'terms': 'Test subscription terms',
  'terms_version': 'test',
  'quote_token': 'signed-test',
  'coupon': '',
};

void main() {
  testWidgets('payment requires explicit consent and coupon changes clear it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionOfferDialog(
            plan: 'pro',
            quoteLoader: (_, _) async => quote(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.enterText(find.byType(TextField), 'NEWCODE');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('free quote shows zero payment and access period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionOfferDialog(
            plan: 'pro',
            quoteLoader: (_, _) async => quote(amount: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total due: ₹0.00'), findsOneWidget);
    expect(find.text('Activate free access'), findsOneWidget);
    expect(
      find.text('Access for 7 days. No automatic renewal.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Read terms & conditions'));
    await tester.pumpAndSettle();
    expect(find.text('Test subscription terms'), findsOneWidget);
  });

  testWidgets('invalid coupon never enables confirmation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionOfferDialog(
            plan: 'pro',
            quoteLoader: (_, _) async => {'error': 'Coupon expired'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coupon expired'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(Checkbox), findsNothing);
  });
}
