import 'package:flutter/material.dart';
import 'package:kesh_kart/customer/customer_barber_profile_page.dart';

class CustomerBarberListPage extends StatelessWidget {
  final List<Map<String, dynamic>> barbers;

  const CustomerBarberListPage({super.key, required this.barbers});

  static const Color _primary = Color(0xFF091426);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Barbers near you',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body:
          barbers.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No approved barber shops are live yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF45474C), fontSize: 16),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: barbers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final barber = barbers[index];
                  final name = _text(
                    barber['shopName'],
                    fallback: _text(barber['name'], fallback: 'Barber Shop'),
                  );
                  final address = _text(
                    barber['shopAddress'],
                    fallback: 'Tap to book a slot',
                  );
                  final photo = _firstPhoto(barber);
                  final rating = _ratingLabel(barber);

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openProfile(context, barber),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE1E3E4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child:
                                photo == null
                                    ? Image.asset(
                                      'assets/images/barber.png',
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    )
                                    : Image.network(
                                      photo,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Image.asset(
                                            'assets/images/barber.png',
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          ),
                                    ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF45474C),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      rating,
                                      style: const TextStyle(
                                        color: _primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'View shop',
                            onPressed: () => _openProfile(context, barber),
                            icon: const Icon(
                              Icons.storefront_outlined,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  void _openProfile(BuildContext context, Map<String, dynamic> barber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBarberProfilePage(barber: barber),
      ),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _firstPhoto(Map<String, dynamic> barber) {
    final photos = barber['shopPhotos'];
    final candidates = <dynamic>[
      if (photos is List) ...photos,
      barber['verifiedShopPhotoUrl'],
      barber['shopVerificationPhotoUrl'],
      barber['profileUrl'],
    ];
    for (final candidate in candidates) {
      final photo = candidate?.toString().trim() ?? '';
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return photo;
      }
    }
    return null;
  }

  static String _ratingLabel(Map<String, dynamic> barber) {
    final raw =
        barber['rating'] ??
        barber['averageRating'] ??
        barber['avgRating'] ??
        barber['reviewRating'];
    final rating =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (rating == null || rating <= 0) return 'New';
    return rating.toStringAsFixed(1);
  }
}
