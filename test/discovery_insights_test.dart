import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kesh_kart/customer/discovery_view.dart';
import 'package:kesh_kart/customer/customer_bookings_page.dart';
import 'package:kesh_kart/barber/insights_screen.dart';
import 'package:kesh_kart/barber/home.dart';
import 'package:kesh_kart/services/realtime_service.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';

class OfflineRealtime extends KeshKartRealtimeService {
  @override
  Stream<Map<String, dynamic>> get events => const Stream.empty();
  @override
  Future<void> connect({bool batching = true}) async {}
  @override
  void ping() {}
  @override
  Future<void> disconnect() async {}
}

final shops = <Map<String, dynamic>>[
  {
    'id': 'a',
    'shopName': 'The Gentlemen’s Studio',
    'shopAddress': 'Main Road, Khambhat',
    'isOpen': true,
    'services': ['Haircut', 'Beard styling'],
  },
  {
    'id': 'b',
    'shopName': 'Classic Cuts',
    'isOpen': false,
    'services': ['Haircut'],
  },
];
Map<String, dynamic> visit(String shop, String status, int days) => {
  'shopId': shop,
  'shopName': shop == 'a' ? 'The Gentlemen’s Studio' : 'Classic Cuts',
  'status': status,
  'slotStart':
      DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch,
};
Map<String, dynamic> report() => {
  'summary': {
    'bookings': 24,
    'completed': 18,
    'customers': 12,
    'cancelled': 3,
    'new_customers': 5,
    'returning_customers': 7,
    'returning_customer_rate': 58.3,
    'completion_rate': 85.7,
  },
  'period': {'end': '2026-09-09T12:00:00+05:30'},
  'change_percent': {'bookings': 20},
  'daily': List.generate(
    7,
    (i) => {'date': '2026-09-0${i + 1}', 'bookings': i + 1, 'completed': i},
  ),
  'weekdays': [
    {'label': 'Mon', 'count': 5},
  ],
  'hours': [
    {'label': '10:00', 'count': 4},
  ],
  'customers': [
    {
      'id': 'one',
      'name': 'Customer One',
      'segment': 'Regular',
      'completed': 4,
      'bookings': 5,
      'period_visits': 2,
      'cancelled': 1,
      'no_shows': 0,
      'last_visit': '2026-09-08',
      'first_visit': '2026-05-01',
      'average_gap_days': 20,
    },
  ],
  'pagination': {'total': 1, 'has_next': false},
  'customer_totals': {'regular': 1},
  'data_quality': {'records_scanned': 24},
  'definitions': ['Only your shop appointments.'],
};
Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: KeshTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);
Future<void> size(WidgetTester tester, Size value) async {
  await tester.binding.setSurfaceSize(value);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

CustomerDiscoveryView discovery({
  List<Map<String, dynamic>>? barbers,
  VoidCallback? history,
  void Function(Map<String, dynamic>)? book,
}) => CustomerDiscoveryView(
  name: 'Jay',
  location: 'Khambhat',
  loading: false,
  barbers: barbers ?? shops,
  appointments: [visit('a', 'completed', 2), visit('a', 'completed', 20)],
  onRefresh: () async {},
  onLocation: () {},
  onHistory: history ?? () {},
  onProfile: () {},
  onBook: book ?? (_) {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Popins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('regular barber ignores cancelled, future and unavailable shops', () {
    final appointments = [
      visit('a', 'completed', 10),
      visit('a', 'completed', 20),
      visit('b', 'cancelled', 1),
      visit('b', 'completed', -1),
      visit('missing', 'completed', 2),
    ];
    expect(regularBarber(shops, appointments)?['id'], 'a');
    expect(regularBarber(shops, [visit('b', 'cancelled', 1)]), isNull);
  });
  testWidgets('customer mobile navigation and regular rebooking', (
    tester,
  ) async {
    await size(tester, const Size(390, 844));
    var booked = '', history = 0;
    await tester.pumpWidget(
      app(discovery(book: (b) => booked = b['id'], history: () => history++)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Book your next visit'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Book your next visit'));
    expect(booked, 'a');
    await tester.tap(find.text('Appointments'));
    expect(history, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer search and open filter', (tester) async {
    await size(tester, const Size(1100, 1000));
    await tester.pumpWidget(app(discovery()));
    await tester.scrollUntilVisible(
      find.byType(TextField),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Classic');
    await tester.pump();
    expect(find.text('1 shops'), findsOneWidget);
    await tester.tap(find.text('Open now'));
    await tester.pump();
    expect(find.text('0 shops'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer narrow large text and first-visit empty state', (
    tester,
  ) async {
    await size(tester, const Size(320, 740));
    await tester.pumpWidget(app(discovery(barbers: []), scale: 1.6));
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('insights mobile filters and customer details', (tester) async {
    await size(tester, const Size(390, 844));
    final calls = <int>[];
    await tester.pumpWidget(
      app(
        BarberInsightsScreen(
          loader: (days, page, search, segment) async {
            calls.add(days);
            return report();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(calls.last, 7);
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Customer One'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Customer One'));
    await tester.pumpAndSettle();
    expect(find.text('Total past bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('insights failures are retryable, not zero reports', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(BarberInsightsScreen(loader: (a, b, c, d) async => null)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No comparison baseline'), findsNothing);
  });
  testWidgets('insights large text does not overflow while scrolling', (
    tester,
  ) async {
    await size(tester, const Size(320, 740));
    await tester.pumpWidget(
      app(
        BarberInsightsScreen(loader: (a, b, c, d) async => report()),
        scale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 25; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('appointment tabs separate active future visits from history', (
    tester,
  ) async {
    await size(tester, const Size(390, 844));
    await tester.pumpWidget(
      app(
        CustomerBookingsPage(
          loader:
              () async => [
                visit('a', 'confirmed', -1),
                visit('b', 'completed', 1),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Gentlemen’s Studio'), findsOneWidget);
    expect(find.text('Classic Cuts'), findsNothing);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Classic Cuts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer desktop visual preview', (tester) async {
    await size(tester, const Size(1200, 1100));
    await tester.pumpWidget(
      app(RepaintBoundary(key: const Key('preview'), child: discovery())),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/customer_discovery.png'),
    );
  });
  testWidgets('barber workspace narrow large text', (tester) async {
    await size(tester, const Size(320, 740));
    await tester.pumpWidget(
      app(BarberHome(realtime: OfflineRealtime()), scale: 1.6),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('barber workspace mobile preview', (tester) async {
    await size(tester, const Size(390, 1000));
    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: const Key('preview'),
          child: BarberHome(
            realtime: OfflineRealtime(),
            clock: () => DateTime(2026, 9, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/barber_workspace.png'),
    );
  });
  testWidgets('barber insights desktop visual preview', (tester) async {
    await size(tester, const Size(1200, 1100));
    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: const Key('preview'),
          child: BarberInsightsScreen(loader: (a, b, c, d) async => report()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/barber_insights.png'),
    );
  });
}
