import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../bedrock_client.dart';
import '../theme/keshkart_theme.dart';

typedef InsightsLoader =
    Future<Map<String, dynamic>?> Function(
      int days,
      int page,
      String search,
      String segment,
    );

class BarberInsightsScreen extends StatefulWidget {
  const BarberInsightsScreen({
    super.key,
    this.customersFirst = false,
    this.loader,
  });
  final bool customersFirst;
  final InsightsLoader? loader;
  @override
  State<BarberInsightsScreen> createState() => _BarberInsightsScreenState();
}

class _BarberInsightsScreenState extends State<BarberInsightsScreen> {
  int _days = 30, _page = 1, _request = 0;
  late bool _customers;
  String _search = '', _segment = '';
  final _searchController = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _customers = widget.customersFirst;
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await (widget.loader?.call(_days, _page, _search, _segment) ??
              BedrockClient().barberAnalytics(
                days: _days,
                page: _page,
                search: _search,
                segment: _segment,
              ));
      if (!mounted || request != _request) return;
      if (data == null || data['summary'] is! Map) {
        throw StateError('Insights unavailable');
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = 'We could not load your shop insights. Please retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(String key) =>
      Map<String, dynamic>.from(_data?[key] as Map? ?? {});
  List<Map<String, dynamic>> _rows(String key) =>
      (_data?[key] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeshColors.warmIvory,
      appBar: AppBar(
        title: const Text('Your business, understood'),
        backgroundColor: KeshColors.warmIvory,
        actions: [
          IconButton(
            tooltip: 'Refresh insights',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _hero(),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final days in [7, 30, 90, 365])
                        ChoiceChip(
                          label: Text(days == 365 ? '1 year' : '$days days'),
                          selected: _days == days,
                          onSelected:
                              _loading
                                  ? null
                                  : (_) {
                                    setState(() {
                                      _days = days;
                                      _page = 1;
                                    });
                                    _load();
                                  },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.insights_outlined),
                        label: Text('Overview'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.people_outline),
                        label: Text('Customers'),
                      ),
                    ],
                    selected: {_customers},
                    onSelectionChanged:
                        (value) => setState(() => _customers = value.first),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _panel(
                      Column(
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (_map('data_quality')['truncated'] == true)
                      _notice(
                        'Partial history: the latest 50,000 updated records are included. Customer cohorts and totals may be incomplete.',
                      ),
                    if (_customers) ..._customerContent() else ..._overview(),
                    const SizedBox(height: 24),
                    _panel(
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('How these numbers are calculated'),
                        subtitle: const Text(
                          'Privacy, definitions & data coverage',
                        ),
                        children: [
                          for (final text
                              in (_data?['definitions'] as List? ?? []))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text('• $text'),
                            ),
                          Text(
                            'Records checked: ${_map('data_quality')['records_scanned'] ?? 0} · Invalid dates: ${_map('data_quality')['invalid_dates'] ?? 0} · Unknown statuses: ${_map('data_quality')['unknown_statuses'] ?? 0} · Missing customer IDs: ${_map('data_quality')['missing_customer_ids'] ?? 0} · Future completed records excluded: ${_map('data_quality')['future_completed_excluded'] ?? 0}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: KeshColors.navyPrimary,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'K E S H K A R T  /  I N S I G H T S',
          style: TextStyle(
            color: KeshColors.proGold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _customers
              ? 'Know the people\nbehind every visit.'
              : 'See your progress.\nPlan your next move.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your shop only. Real appointments. No guessed revenue.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
  List<Widget> _overview() {
    final s = _map('summary'), changes = _map('change_percent');
    return [
      _section('THE BIG PICTURE', 'Your last $_days days'),
      Text(
        'Through ${_date(_map('period')['end'])} · Asia/Kolkata · Today is partial',
        style: const TextStyle(color: KeshColors.textMuted),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) {
          final columns =
              c.maxWidth >= 800
                  ? 4
                  : c.maxWidth >= 440
                  ? 2
                  : 1;
          final width = (c.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in [
                ('bookings', 'Appointments', Icons.calendar_today_outlined),
                ('completed', 'Completed visits', Icons.task_alt),
                ('customers', 'Booking customers', Icons.people_outline),
                ('cancelled', 'Cancellations', Icons.event_busy_outlined),
              ])
                SizedBox(
                  width: width,
                  child: _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$3, color: KeshColors.signatureCoral),
                        const SizedBox(height: 20),
                        Text(
                          '${s[item.$1] ?? 0}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(item.$2),
                        const SizedBox(height: 10),
                        Text(
                          changes[item.$1] == null
                              ? 'No comparison baseline'
                              : '${(changes[item.$1] as num) >= 0 ? '+' : ''}${changes[item.$1]}% vs previous period',
                          style: const TextStyle(
                            fontSize: 11,
                            color: KeshColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 26),
      _section('MOMENTUM', 'Appointment activity'),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booked slot dates · scroll to explore',
              style: TextStyle(color: KeshColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _activityChart(),
            const SizedBox(height: 12),
            const Text(
              'Coral: all appointments · Ink: completed visits',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      _section('CUSTOMER RELATIONSHIPS', 'Give them a reason to return'),
      _panel(
        Column(
          children: [
            _value(
              'New completed-visit customers',
              '${s['new_customers'] ?? 0}',
            ),
            _value(
              'Returning completed-visit customers',
              '${s['returning_customers'] ?? 0}',
            ),
            _value('Returning share', _percent(s['returning_customer_rate'])),
            _value(
              'Customers with 3+ completed visits · all history',
              '${_map('customer_totals')['regular'] ?? 0}',
            ),
            _value(
              'No completed visit in 60+ days · all history',
              '${_map('customer_totals')['inactive'] ?? 0}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _customers = true),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Explore your customers'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      _section('OPERATIONS', 'Where the day gets busy'),
      _panel(
        Column(
          children: [
            _value(
              'Completion rate · resolved appointments',
              _percent(s['completion_rate']),
            ),
            _value(
              'Cancellation rate · resolved appointments',
              _percent(s['cancellation_rate']),
            ),
            _value(
              'No-show rate · resolved appointments',
              _percent(s['no_show_rate']),
            ),
            _value('No-shows in period', '${s['no_shows'] ?? 0}'),
            _value('Unresolved in period', '${s['unresolved'] ?? 0}'),
            _value(
              'Unresolved before this period · review your queue',
              '${s['overdue'] ?? 0}',
            ),
            _value(
              'Future active bookings · all dates',
              '${s['upcoming'] ?? 0}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(_bars('By weekday', _rows('weekdays'))),
      const SizedBox(height: 16),
      _panel(
        _bars(
          'By hour · Asia/Kolkata',
          _rows('hours').where((r) => (r['count'] as num? ?? 0) > 0).toList(),
        ),
      ),
      const SizedBox(height: 16),
      _panel(_bars('Appointment outcomes', _rows('statuses'))),
      const SizedBox(height: 16),
      _notice(
        'Financial and service reports are not yet available. Existing bookings do not record reliable service selection, charges or settlement data.',
      ),
    ];
  }

  List<Widget> _customerContent() => [
    _section('YOUR CUSTOMER BOOK', 'Relationships, not just bookings'),
    const Text(
      'All observed shop history. Visit counts in this period follow the date filter. No other shop’s customer data is included.',
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (v) {
        _search = v;
        _page = 1;
        _load();
      },
      decoration: InputDecoration(
        prefixIcon: IconButton(
          tooltip: 'Search customers',
          icon: const Icon(Icons.search),
          onPressed: () {
            _search = _searchController.text;
            _page = 1;
            _load();
          },
        ),
        suffixIcon: IconButton(
          tooltip: 'Clear customer search',
          icon: const Icon(Icons.close),
          onPressed: () {
            _searchController.clear();
            _search = '';
            _page = 1;
            _load();
          },
        ),
        labelText: 'Search customer name',
        helperText: 'Press Enter or Search to apply',
      ),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children: [
        for (final segment in [
          ('', 'All customers'),
          ('regular', 'Regulars'),
          ('inactive', 'Inactive 60+ days'),
        ])
          ChoiceChip(
            label: Text(segment.$2),
            selected: _segment == segment.$1,
            onSelected: (_) {
              _segment = segment.$1;
              _page = 1;
              _load();
            },
          ),
      ],
    ),
    const SizedBox(height: 16),
    if (_rows('customers').isEmpty)
      _notice(
        'No customers match this view. Customer insights appear after appointments are recorded.',
      ),
    for (final c in _rows('customers'))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _panel(
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: KeshColors.warmIvory,
              child: const Icon(
                Icons.person_outline,
                color: KeshColors.navyPrimary,
              ),
            ),
            title: Text(
              '${c['name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${c['segment']} · ${c['completed']} completed visits',
            ),
            children: [
              _value(
                'Completed visits in selected period',
                '${c['period_visits']}',
              ),
              _value('Total past bookings', '${c['bookings']}'),
              _value('First completed visit', _date(c['first_visit'])),
              _value('Last completed visit', _date(c['last_visit'])),
              _value(
                'Average gap between completed visits',
                c['average_gap_days'] == null
                    ? 'Not enough visits'
                    : '${c['average_gap_days']} days',
              ),
              _value('Cancellations · all history', '${c['cancelled']}'),
              _value('No-shows · all history', '${c['no_shows']}'),
            ],
          ),
        ),
      ),
    Row(
      children: [
        TextButton(
          onPressed:
              _page > 1
                  ? () {
                    _page--;
                    _load();
                  }
                  : null,
          child: const Text('Previous'),
        ),
        Expanded(
          child: Text(
            'Page $_page · ${_map('pagination')['total'] ?? 0} customers',
            textAlign: TextAlign.center,
          ),
        ),
        TextButton(
          onPressed:
              _map('pagination')['has_next'] == true
                  ? () {
                    _page++;
                    _load();
                  }
                  : null,
          child: const Text('Next'),
        ),
      ],
    ),
  ];
  Widget _activityChart() {
    final rows = _rows('daily');
    final max = rows.fold<num>(
      1,
      (m, r) => (r['bookings'] as num? ?? 0) > m ? r['bookings'] as num : m,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in rows)
            Semantics(
              label:
                  '${r['date']}: ${r['bookings']} appointments, ${r['completed']} completed',
              child: Tooltip(
                message:
                    '${r['date']}\n${r['bookings']} appointments · ${r['completed']} completed',
                child: SizedBox(
                  width: 38,
                  child: Column(
                    children: [
                      Text(
                        '${r['bookings']}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 10,
                              height: 2 + 98 * (r['bookings'] as num) / max,
                              decoration: BoxDecoration(
                                color: KeshColors.signatureCoral,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Container(
                              width: 10,
                              height: 2 + 98 * (r['completed'] as num) / max,
                              decoration: BoxDecoration(
                                color: KeshColors.navyPrimary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${r['date']}'.substring(5),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bars(String title, List<Map<String, dynamic>> rows) {
    final max = rows.fold<num>(
      1,
      (m, r) => (r['count'] as num) > m ? r['count'] as num : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty) const Text('No activity in this period.'),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${r['label']}')),
                    Text(
                      '${r['count']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (r['count'] as num) / max,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: KeshColors.warmIvory,
                  color: KeshColors.signatureCoral,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _panel(Widget child) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: KeshColors.borderIvory),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget _section(String eyebrow, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
            color: KeshColors.signatureCoral,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
      ],
    ),
  );
  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: _panel(Text(text)),
  );
  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(color: KeshColors.textSecondary),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  String _percent(dynamic value) =>
      value == null ? 'Not enough data' : '$value%';
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null
        ? 'No completed visit'
        : DateFormat(
          'd MMM y',
        ).format(date.toUtc().add(const Duration(hours: 5, minutes: 30)));
  }
}
