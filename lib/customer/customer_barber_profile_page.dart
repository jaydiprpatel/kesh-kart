import 'package:flutter/material.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:kesh_kart/customer/service_selection_screen.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';

/// Public, customer-safe view of a barber shop. Editing remains exclusive to
/// the KeshKart Barber app.
class CustomerBarberProfilePage extends StatelessWidget {
  const CustomerBarberProfilePage({super.key, required this.barber});

  final Map<String, dynamic> barber;

  @override
  Widget build(BuildContext context) {
    final services = _services(barber);
    final shopName = _text(
      barber['shopName'],
      fallback: _text(barber['name'], fallback: 'Barber shop'),
    );
    final address = _text(barber['shopAddress']);
    final verified =
        _text(barber['verificationStatus']).toLowerCase() == 'approved' ||
        _text(barber['verifiedShopPhotoUrl']).isNotEmpty;
    final open = _isOpen(barber);

    return Scaffold(
      backgroundColor: KeshColors.warmIvory,
      appBar: AppBar(
        title: const Text('Shop profile'),
        backgroundColor: KeshColors.warmIvory,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: open ? () => _book(context) : null,
            icon: Icon(
              open ? Icons.calendar_month_outlined : Icons.lock_outline,
            ),
            label: Text(open ? 'Book appointment' : 'Shop is closed'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
        children: [
          _PhotoGallery(photoSources: _photoSources(barber)),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
              ),
              if (verified)
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Chip(
                    avatar: Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Color(0xFF167A56),
                    ),
                    label: Text('Verified'),
                  ),
                ),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: KeshColors.signatureCoral,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      color: KeshColors.textSecondary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _InfoCard(
            icon: open ? Icons.storefront_outlined : Icons.lock_outline,
            title: open ? 'Open for bookings' : 'Shop is closed',
            body:
                open
                    ? 'Pick a service and choose an available time.'
                    : 'This shop is currently closed. Check back when it opens.',
          ),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.schedule_outlined,
            title: 'Opening hours',
            body: _openingHours(barber),
          ),
          const SizedBox(height: 22),
          const Text(
            'Service menu',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (services.isEmpty)
            const _InfoCard(
              icon: Icons.content_cut_outlined,
              title: 'Menu not published yet',
              body: 'This shop has not added services and prices yet.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: KeshColors.borderIvory),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < services.length; index++) ...[
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: KeshColors.chipBackground,
                        child: Icon(
                          Icons.content_cut_outlined,
                          color: KeshColors.navyPrimary,
                        ),
                      ),
                      title: Text(
                        services[index]['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing:
                          services[index]['price']!.isEmpty
                              ? null
                              : Text(
                                services[index]['price']!,
                                style: const TextStyle(
                                  color: KeshColors.signatureCoral,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                    ),
                    if (index != services.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _book(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceSelectionScreen(barber: barber)),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static bool _isOpen(Map<String, dynamic> barber) =>
      barber.containsKey('isOpen')
          ? barber['isOpen'] == true
          : barber['isActive'] == true;

  static List<String> _photoSources(Map<String, dynamic> barber) {
    final gallery = barber['shopPhotos'];
    final candidates = <dynamic>[
      barber['displayShopPhotoUrl'],
      if (gallery is List) ...gallery,
      barber['verifiedShopPhotoUrl'],
      barber['shopVerificationPhotoUrl'],
      barber['profileUrl'],
    ];
    final unique = <String>{};
    for (final candidate in candidates) {
      final source = _photoSource(candidate);
      if (source.isNotEmpty && !source.startsWith('shimmer_')) {
        unique.add(source);
      }
    }
    return unique.toList();
  }

  static String _photoSource(dynamic value) {
    if (value is Map) {
      value =
          value['url'] ??
          value['downloadUrl'] ??
          value['download_url'] ??
          value['path'] ??
          value['storagePath'];
    }
    return value?.toString().trim() ?? '';
  }

  static String _openingHours(Map<String, dynamic> barber) {
    final opening = _text(barber['openingTime']);
    final closing = _text(barber['closingTime']);
    if (opening.isEmpty && closing.isEmpty) {
      return 'Hours are confirmed when you choose a time.';
    }
    if (opening.isEmpty) return 'Closes at $closing';
    if (closing.isEmpty) return 'Opens at $opening';
    return '$opening – $closing';
  }

  static List<Map<String, String>> _services(Map<String, dynamic> barber) {
    final raw = barber['services'];
    if (raw is! List) return const [];
    final services = <Map<String, String>>[];
    for (final service in raw) {
      if (service is Map) {
        final name = _text(service['name']);
        if (name.isEmpty) continue;
        final price = _text(service['price']);
        services.add({
          'name': name,
          'price':
              price.isEmpty
                  ? ''
                  : price.startsWith('₹')
                  ? price
                  : '₹$price',
        });
      } else {
        final name = _text(service);
        if (name.isNotEmpty) services.add({'name': name, 'price': ''});
      }
    }
    return services;
  }
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.photoSources});

  final List<String> photoSources;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final PageController _controller = PageController();
  List<String> _photos = const [];
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _resolvePhotos();
  }

  @override
  void didUpdateWidget(covariant _PhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoSources.join('|') != widget.photoSources.join('|')) {
      _resolvePhotos();
    }
  }

  Future<void> _resolvePhotos() async {
    final resolved = <String>[];
    for (final source in widget.photoSources) {
      try {
        // Older barber profiles stored a time-limited download URL instead of
        // its storage path. getDownloadUrl extracts the path from those URLs
        // and gives the customer a fresh URL before it can expire again.
        final url = await BedrockClient().getDownloadUrl(source);
        if (url != null && url.isNotEmpty) resolved.add(url);
      } catch (_) {
        // One unavailable photo must not hide the rest of the shop gallery.
      }
    }
    if (mounted) setState(() => _photos = resolved.toSet().toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) return _emptyGallery();
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _photos.length,
                onPageChanged:
                    (index) => setState(() => _selectedIndex = index),
                itemBuilder:
                    (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        _photos[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _emptyGallery(),
                      ),
                    ),
              ),
              if (_photos.length > 1)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        '${_selectedIndex + 1} / ${_photos.length} photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_photos.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder:
                  (_, index) => GestureDetector(
                    onTap:
                        () => _controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                    child: Container(
                      width: 72,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              index == _selectedIndex
                                  ? KeshColors.signatureCoral
                                  : KeshColors.borderIvory,
                          width: index == _selectedIndex ? 2 : 1,
                        ),
                      ),
                      child: Image.network(_photos[index], fit: BoxFit.cover),
                    ),
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyGallery() => Container(
    height: 240,
    decoration: BoxDecoration(
      color: KeshColors.chipBackground,
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Center(
      child: Icon(
        Icons.storefront_outlined,
        color: KeshColors.navyPrimary,
        size: 72,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: KeshColors.borderIvory),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: KeshColors.chipBackground,
          child: Icon(icon, color: KeshColors.navyPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(color: KeshColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
