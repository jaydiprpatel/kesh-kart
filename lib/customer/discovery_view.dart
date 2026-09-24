import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kesh_kart/customer/customer_barber_profile_page.dart';
import '../theme/keshkart_theme.dart';

int appointmentMillis(dynamic value) =>
    value is num
        ? value.toInt()
        : DateTime.tryParse('$value')?.millisecondsSinceEpoch ?? 0;
String shopId(Map<String, dynamic> row) =>
    '${row['shopId'] ?? row['barberId'] ?? row['id'] ?? row['_id'] ?? ''}';

/// Only completed visits create a regular relationship; cancelled/future visits do not.
Map<String, dynamic>? regularBarber(
  List<Map<String, dynamic>> shops,
  List<Map<String, dynamic>> appointments, {
  DateTime? now,
}) {
  final end = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final visits = <String, int>{}, latest = <String, int>{};
  for (final a in appointments) {
    final time = appointmentMillis(a['slotStart']);
    if (a['status'] != 'completed' || time <= 0 || time > end) continue;
    final id = shopId(a);
    visits[id] = (visits[id] ?? 0) + 1;
    if (time > (latest[id] ?? 0)) latest[id] = time;
  }
  final matched =
      shops.where((s) => visits.containsKey(shopId(s))).toList()..sort((a, b) {
        final count = visits[shopId(b)]!.compareTo(visits[shopId(a)]!);
        return count != 0
            ? count
            : latest[shopId(b)]!.compareTo(latest[shopId(a)]!);
      });
  return matched.isEmpty
      ? null
      : {...matched.first, 'completedVisits': visits[shopId(matched.first)]};
}

class CustomerDiscoveryView extends StatefulWidget {
  const CustomerDiscoveryView({
    super.key,
    required this.name,
    required this.location,
    required this.loading,
    this.error,
    required this.barbers,
    required this.appointments,
    required this.onRefresh,
    required this.onLocation,
    required this.onHistory,
    required this.onProfile,
    required this.onBook,
    this.onPrivacy,
    this.onTerms,
  });
  final String name, location;
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> barbers, appointments;
  final Future<void> Function() onRefresh;
  final VoidCallback onLocation, onHistory, onProfile;
  final void Function(Map<String, dynamic>) onBook;
  final VoidCallback? onPrivacy, onTerms;
  @override
  State<CustomerDiscoveryView> createState() => _CustomerDiscoveryViewState();
}

class _CustomerDiscoveryViewState extends State<CustomerDiscoveryView> {
  String _query = '';
  bool _openOnly = false;
  bool _isOpen(Map<String, dynamic> b) =>
      b.containsKey('isOpen') ? b['isOpen'] == true : b['isActive'] == true;
  String _name(Map<String, dynamic> b) =>
      '${b['shopName'] ?? b['name'] ?? 'Barber shop'}';
  List<String> _services(Map<String, dynamic> b) =>
      (b['services'] as List? ?? [])
          .map((s) => s is Map ? '${s['name'] ?? ''}' : '$s')
          .where((s) => s.isNotEmpty)
          .toList();
  String _shopPhoto(Map<String, dynamic> barber) {
    final gallery = barber['shopPhotos'];
    final candidates = <dynamic>[
      barber['displayShopPhotoUrl'],
      if (gallery is List) ...gallery,
      barber['verifiedShopPhotoUrl'],
      barber['shopVerificationPhotoUrl'],
      barber['profileUrl'],
    ];
    for (final candidate in candidates) {
      final url = candidate?.toString().trim() ?? '';
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final regular = regularBarber(widget.barbers, widget.appointments);
    final matches =
        widget.barbers
            .where(
              (b) =>
                  (!_openOnly || _isOpen(b)) &&
                  '${_name(b)} ${b['shopAddress'] ?? ''} ${_services(b).join(' ')}'
                      .toLowerCase()
                      .contains(_query.trim().toLowerCase()),
            )
            .toList();
    final upcoming =
        widget.appointments
            .where(
              (a) =>
                  [
                    'booked',
                    'scheduled',
                    'confirmed',
                    'arrived',
                    'in_progress',
                  ].contains(a['status']) &&
                  appointmentMillis(a['slotStart']) >=
                      DateTime.now().millisecondsSinceEpoch,
            )
            .toList()
          ..sort(
            (a, b) => appointmentMillis(
              a['slotStart'],
            ).compareTo(appointmentMillis(b['slotStart'])),
          );
    return Scaffold(
      backgroundColor: KeshColors.warmIvory,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) widget.onHistory();
          if (i == 2) widget.onProfile();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.content_cut_outlined),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Appointments',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'KeshKart',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh',
                                onPressed:
                                    widget.loading ? null : widget.onRefresh,
                                icon: const Icon(Icons.refresh),
                              ),
                              IconButton(
                                tooltip: 'Your profile',
                                onPressed: widget.onProfile,
                                icon: const Icon(Icons.account_circle_outlined),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: widget.onLocation,
                            icon: const Icon(Icons.near_me_outlined, size: 16),
                            label: Text(
                              widget.location,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.name.trim().isEmpty
                                ? 'A good day starts\nwith a great haircut.'
                                : 'Your next great\nhaircut, ${widget.name.trim().split(' ').first}.',
                            style: const TextStyle(
                              fontSize: 36,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your familiar chair. Or a fresh find.',
                            style: TextStyle(
                              fontSize: 16,
                              color: KeshColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (widget.loading)
                            const Padding(
                              padding: EdgeInsets.all(36),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (widget.error != null)
                            _empty(
                              Icons.cloud_off_outlined,
                              'Let’s try that again',
                              widget.error!,
                              action: 'Retry',
                              onTap: widget.onRefresh,
                            )
                          else ...[
                            if (upcoming.isNotEmpty) _upcoming(upcoming.first),
                            _section('01 / YOUR USUAL', 'Your barber'),
                            if (regular != null)
                              _regular(regular)
                            else
                              _empty(
                                Icons.chair_outlined,
                                'Your usual spot starts here',
                                'After a completed visit, your regular barber will appear here for easy rebooking.',
                              ),
                            const SizedBox(height: 28),
                            _section(
                              '02 / FIND YOUR NEXT CHAIR',
                              'Discover barbers',
                            ),
                            TextField(
                              onChanged: (q) => setState(() => _query = q),
                              decoration: const InputDecoration(
                                hintText: 'Search shop, area or service',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilterChip(
                                  label: const Text('Open now'),
                                  selected: _openOnly,
                                  onSelected:
                                      (v) => setState(() => _openOnly = v),
                                ),
                                Text(
                                  '${matches.length} shops',
                                  style: const TextStyle(
                                    color: KeshColors.textSecondary,
                                  ),
                                ),
                                const Text(
                                  'Choose a shop to see available slots',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: KeshColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.barbers.length >= 100 ||
                                widget.appointments.length >= 100)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Showing up to 100 loaded shops and appointments. Your barber is based on loaded completed visits.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!widget.loading && widget.error == null) ...[
                    if (matches.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverToBoxAdapter(
                          child: _empty(
                            Icons.search_off,
                            'No matching barbers',
                            'Try another shop name, area or service, or turn off the Open now filter.',
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverLayoutBuilder(
                        builder:
                            (context, c) => SliverList.builder(
                              itemCount:
                                  (matches.length /
                                          (c.crossAxisExtent >= 720 ? 2 : 1))
                                      .ceil(),
                              itemBuilder: (context, index) {
                                final cols = c.crossAxisExtent >= 720 ? 2 : 1;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var j = 0; j < cols; j++) ...[
                                        if (j > 0) const SizedBox(width: 16),
                                        Expanded(
                                          child:
                                              index * cols + j < matches.length
                                                  ? _shop(
                                                    matches[index * cols + j],
                                                  )
                                                  : const SizedBox(),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _section(
                              '03 / YOUR JOURNEY',
                              'Appointments, all in one place',
                            ),
                            _empty(
                              Icons.history_rounded,
                              'Your visits, organised',
                              'See upcoming appointments, booking receipts and your appointment history.',
                              action: 'View appointments',
                              onTap: widget.onHistory,
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              children: [
                                if (widget.onPrivacy != null)
                                  TextButton(
                                    onPressed: widget.onPrivacy,
                                    child: const Text('Privacy'),
                                  ),
                                if (widget.onTerms != null)
                                  TextButton(
                                    onPressed: widget.onTerms,
                                    child: const Text('Terms & conditions'),
                                  ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _section(String eyebrow, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
            color: KeshColors.signatureCoral,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
      ],
    ),
  );
  Widget _regular(Map<String, dynamic> b) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: KeshColors.navyPrimary,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.content_cut_rounded,
          color: KeshColors.proGold,
          size: 30,
        ),
        const SizedBox(height: 20),
        Text(
          _name(b),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${b['completedVisits']} completed visits in your loaded history',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _isOpen(b) ? () => widget.onBook(b) : null,
          icon: Icon(_isOpen(b) ? Icons.arrow_forward : Icons.lock_outline),
          label: Text(_isOpen(b) ? 'Book your next visit' : 'Shop is closed'),
        ),
      ],
    ),
  );
  Widget _upcoming(Map<String, dynamic> a) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1E8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOU’RE BOOKED IN',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${a['shopName'] ?? 'Your barber'}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            DateFormat('EEE, d MMM · h:mm a').format(
              DateTime.fromMillisecondsSinceEpoch(
                appointmentMillis(a['slotStart']),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onHistory,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('View appointment & receipt'),
          ),
        ],
      ),
    ),
  );
  Widget _shop(Map<String, dynamic> b) {
    final photo = _shopPhoto(b);
    final distance = b['distanceKm'] as num?;
    final isOpen = _isOpen(b);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KeshColors.borderIvory),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child:
                photo.isEmpty
                    ? _photoPlaceholder()
                    : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => _photoPlaceholder(),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      isOpen ? 'Open now' : 'Shop closed',
                      style: TextStyle(
                        color:
                            isOpen
                                ? KeshColors.textSecondary
                                : const Color(0xFFB54734),
                        fontSize: 12,
                        fontWeight: isOpen ? FontWeight.w500 : FontWeight.w800,
                      ),
                    ),
                    if (distance != null)
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _name(b),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ('${b['shopAddress'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${b['shopAddress']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: KeshColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _services(b).take(3).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isOpen ? () => widget.onBook(b) : null,
                    icon: Icon(
                      isOpen ? Icons.arrow_forward : Icons.lock_outline,
                      size: 18,
                    ),
                    label: Text(isOpen ? 'Choose a time' : 'Shop is closed'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerBarberProfilePage(barber: b),
                        ),
                      ),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('Shop details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
    color: KeshColors.chipBackground,
    child: const Center(
      child: Icon(
        Icons.storefront_outlined,
        size: 48,
        color: KeshColors.navyPrimary,
      ),
    ),
  );
  Widget _empty(
    IconData icon,
    String title,
    String subtitle, {
    String? action,
    VoidCallback? onTap,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: KeshColors.borderIvory),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 30, color: KeshColors.signatureCoral),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: KeshColors.textSecondary, height: 1.5),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward),
              label: Text(action),
            ),
          ),
      ],
    ),
  );
}
