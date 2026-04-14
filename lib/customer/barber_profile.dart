import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/backend/loyalty_service.dart';
import 'package:kesh_kart/customer/chat_screen.dart';
import 'select_slot.dart';
import 'dart:ui';

class BarberProfileScreen extends StatelessWidget {
  final Map<String, dynamic> barberData;
  final String barberId;
  final double? distance;

  const BarberProfileScreen({
    super.key,
    required this.barberData,
    required this.barberId,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: BaasClient.collection('users').doc(barberId).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> currentBarberData = barberData;
        if (snapshot.hasData && (snapshot.data as dynamic).exists) {
          currentBarberData =
              (snapshot.data as dynamic).data() as Map<String, dynamic>;
        }

        // Extract Data
        final name =
            currentBarberData['shopName'] ??
            currentBarberData['name'] ??
            'Barber Shop';
        final photos = List<String>.from(currentBarberData['shopPhotos'] ?? []);
        final imageUrl = photos.isNotEmpty ? photos.first : null;
        final rating = currentBarberData['rating'] ?? 4.8;
        final address = currentBarberData['address'] ?? 'No address provided';

        // Parse Services
        final services = List<Map<String, dynamic>>.from(
          currentBarberData['services'] ?? [],
        );

        return Scaffold(
          backgroundColor: Colors.black,
          body: CustomScrollView(
            slivers: [
              // 1. Sliver App Bar with Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: Colors.black,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatScreen(
                                otherUserId: barberId,
                                otherUserName: name,
                              ),
                        ),
                      );
                    },
                  ),
                  StreamBuilder(
                    stream: BaasClient.collection('users').doc(BaasClient.instance.sdk.auth.currentUser?.id ?? '').snapshots(),
                    builder: (context, snapshot) {
                      final List<String> favorites = snapshot.hasData && (snapshot.data as dynamic).exists
                          ? List<String>.from((snapshot.data as dynamic).data()['favoriteBarbers'] ?? [])
                          : [];
                      final isFav = favorites.contains(barberId);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () async {
                          final uId = BaasClient.instance.sdk.auth.currentUser?.id;
                          if (uId == null) return;
                          
                          if (isFav) {
                            favorites.remove(barberId);
                          } else {
                            favorites.add(barberId);
                          }
                          
                          await BaasClient.collection('users').doc(uId).update({
                            'favoriteBarbers': favorites,
                          });
                        },
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null
                          ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade900,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFE5B80B),
                                  ),
                                ),
                              );
                            },
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade900,
                                  child: const Center(
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white24,
                                      size: 60,
                                    ),
                                  ),
                                ),
                          )
                          : Container(color: Colors.grey.shade900),
                      // Gradient Overlay for readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Info Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          StreamBuilder(
                            stream:
                                BaasClient.collection('reviews')
                                    .where('barberId', isEqualTo: barberId)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              int reviewCount = 0;
                              if (snapshot.hasData) {
                                reviewCount =
                                    (snapshot.data as dynamic).docs.length;
                              }
                              return Text(
                                "$rating ($reviewCount Reviews)",
                                style: const TextStyle(color: Colors.white70),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          if (currentBarberData['verificationStatus'] ==
                              'approved')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D189).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00D189,
                                  ).withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    color: Color(0xFF00D189),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "VERIFIED",
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF00D189),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          if (distance != null)
                            Chip(
                              label: Text(
                                distance! < 1
                                    ? "Nearby"
                                    : "${distance!.toStringAsFixed(1)} km",
                              ),
                              backgroundColor: Colors.white10,
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "About",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        address,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),

                      // Loyalty Progress Card
                      StreamBuilder(
                        stream: LoyaltyService.loyaltyStream(
                          BaasClient.instance.sdk.auth.currentUser?.id ?? '',
                          barberId,
                        ),
                        builder: (context, snapshot) {
                          int points = 0;
                          if (snapshot.hasData &&
                              (snapshot.data as dynamic).exists) {
                            points =
                                (snapshot.data as dynamic).data()['points'] ??
                                0;
                          }
                          final progress = (points / 5).clamp(0.0, 1.0);
                          final isReady = points >= 5;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00D189).withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    isReady
                                        ? const Color(0xFF00D189)
                                        : Colors.white10,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Loyalty Program",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isReady)
                                      const Icon(
                                        Icons.auto_awesome,
                                        color: Color(0xFF00D189),
                                        size: 20,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white10,
                                    color: const Color(0xFF00D189),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isReady
                                          ? "Ready for a free service!"
                                          : "$points / 5 visits to your reward",
                                      style: TextStyle(
                                        color:
                                            isReady
                                                ? const Color(0xFF00D189)
                                                : Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isReady)
                                      ElevatedButton(
                                        onPressed: () async {
                                          final success =
                                              await LoyaltyService.claimReward(
                                                BaasClient
                                                        .instance
                                                        .sdk
                                                        .auth
                                                        .currentUser
                                                        ?.id ??
                                                    '',
                                                barberId,
                                              );
                                          if (success && context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Reward claimed! Let the barber know.",
                                                ),
                                                backgroundColor: Color(
                                                  0xFF00D189,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF00D189,
                                          ),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 0,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          "Claim",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (currentBarberData['portfolio'] != null &&
                          (currentBarberData['portfolio'] as List)
                              .isNotEmpty) ...[
                        const Text(
                          "Lookbook",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                (currentBarberData['portfolio'] as List).length,
                            itemBuilder: (context, index) {
                              final pEntry =
                                  currentBarberData['portfolio'][index];
                              final pUrl =
                                  pEntry is String ? pEntry : pEntry['url'];
                              final likes =
                                  pEntry is String ? 0 : (pEntry['likes'] ?? 0);

                              return Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child:
                                          pUrl != null
                                              ? Image.network(
                                                pUrl,
                                                fit: BoxFit.cover,
                                                height: double.infinity,
                                                width: double.infinity,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      color: Colors.white10,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                color: Colors.white10,
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                    ),
                                    // Like Overlay
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () async {
                                          // Logic to increment like
                                          final currentPortfolio =
                                              List<dynamic>.from(
                                                currentBarberData['portfolio'],
                                              );
                                          final item = currentPortfolio[index];

                                          if (item is String) {
                                            currentPortfolio[index] = {
                                              'url': item,
                                              'likes': 1,
                                            };
                                          } else {
                                            final updatedItem =
                                                Map<String, dynamic>.from(item);
                                            updatedItem['likes'] =
                                                (updatedItem['likes'] ?? 0) + 1;
                                            currentPortfolio[index] =
                                                updatedItem;
                                          }

                                          await BaasClient.collection(
                                            'users',
                                          ).doc(barberId).update({
                                            'portfolio': currentPortfolio,
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white24,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.favorite,
                                                color: Colors.redAccent,
                                                size: 16,
                                              ),
                                              if (likes > 0) ...[
                                                const SizedBox(width: 2),
                                                Text(
                                                  "$likes",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (currentBarberData['products'] != null &&
                          (currentBarberData['products'] as List)
                              .isNotEmpty) ...[
                        const Text(
                          "Shop Products",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                (currentBarberData['products'] as List).length,
                            itemBuilder: (context, index) {
                              final product =
                                  currentBarberData['products'][index];
                              return Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child:
                                          product['image'] != null
                                              ? Image.network(
                                                product['image'],
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      height: 80,
                                                      color: Colors.white10,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                height: 80,
                                                color: Colors.white10,
                                                child: const Icon(
                                                  Icons.shopping_bag,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            product['name'] ?? 'Product',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "₹${product['price'] ?? '0'}",
                                            style: const TextStyle(
                                              color: Colors.orangeAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 24,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "Product added to cart!",
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white24,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                              child: const Text(
                                                "Add",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      const Text(
                        "Services",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Categorized Services List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Group services by category
                    Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (var s in services) {
                      final cat = s['category'] ?? 'General';
                      grouped.putIfAbsent(cat, () => []).add(s);
                    }

                    final categories = grouped.keys.toList();
                    if (index >= categories.length) return null;

                    final category = categories[index];
                    final categoryServices = grouped[category]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            category.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ...categoryServices.map((service) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ExpansionTile(
                              iconColor: Colors.greenAccent,
                              collapsedIconColor: Colors.white54,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cut,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              title: Text(
                                service['name'] ?? 'Service',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                (service['variants'] != null &&
                                        (service['variants'] as List)
                                            .isNotEmpty)
                                    ? "${(service['variants'] as List).length} styles available"
                                    : "${service['duration'] ?? 30} mins",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: _buildPriceWidget(service['price']),
                              children: [
                                if (service['description'] != null &&
                                    service['description']
                                        .toString()
                                        .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        service['description'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (service['variants'] != null &&
                                    (service['variants'] as List).isNotEmpty)
                                  ...(service['variants'] as List).map(
                                    (v) => ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                          ),
                                      title: Text(
                                        v['name'] ?? 'Variant',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${v['duration'] ?? 30} min",
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                      trailing: Text(
                                        "\u20b9${v['price'] ?? '0'}",
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  childCount: () {
                    Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (var s in services) {
                      final cat = s['category'] ?? 'General';
                      grouped.putIfAbsent(cat, () => []).add(s);
                    }
                    return grouped.length;
                  }(),
                ),
              ),

              // Padding for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => SelectSlotScreen(
                        barberId: barberId,
                        barberName: name,
                      ),
                ),
              );
            },
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.calendar_today),
            label: const Text("Book Appointment"),
          ),
        );
      },
    );
  }

  Widget _buildPriceWidget(dynamic price) {
    String priceStr = price.toString();
    bool startsFrom = false;

    if (priceStr.startsWith('*')) {
      startsFrom = true;
      priceStr = priceStr.substring(1);
    }

    if (startsFrom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            "Starts from",
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            "₹$priceStr",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    return Text(
      "₹$priceStr",
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}
