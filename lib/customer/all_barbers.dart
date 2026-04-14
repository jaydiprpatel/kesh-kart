import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/customer/barber_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kesh_kart/services/seeder_service.dart';
import 'package:kesh_kart/backend/baas_query_snapshot.dart';

class AllBarbersPage extends StatefulWidget {
  final String? initialQuery;
  const AllBarbersPage({super.key, this.initialQuery});

  @override
  State<AllBarbersPage> createState() => _AllBarbersPageState();
}

class _AllBarbersPageState extends State<AllBarbersPage> {
  final TextEditingController _searchController = TextEditingController();
  late Stream<BaasQuerySnapshot> _barberStream;
  String _selectedCategory = "All";
  String _sortBy = "Top Rated"; // Top Rated, Nearest, Popular
  double _minRating = 0.0;
  String? _userId;
  List<String> _favoriteBarberIds = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? "";
    _barberStream = _buildQuery();
    
    _loadData();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });

    if (_userId != null) {
      BaasClient.collection('users').doc(_userId!).snapshots().listen((
        snapshot,
      ) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _favoriteBarberIds = List<String>.from(
              data['favoriteBarbers'] ?? [],
            );
          });
        }
      });
    }
  }

  Future<void> _toggleFavorite(String barberId) async {
    if (_userId == null) return;

    final newFavorites = List<String>.from(_favoriteBarberIds);
    if (newFavorites.contains(barberId)) {
      newFavorites.remove(barberId);
    } else {
      newFavorites.add(barberId);
    }

    try {
      await BaasClient.collection(
        'users',
      ).doc(_userId!).update({'favoriteBarbers': newFavorites});
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "All Barbers",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<BaasQuerySnapshot>(
              stream: _barberStream, // Use stable typed stream
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Error: ${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D189)),
                  );
                }

                final barbers = snapshot.data!.docs;

                if (barbers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          "No barbers found",
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Apply client-side sorting and filtering for complex criteria
                List<Map<String, dynamic>> barberList =
                    barbers.map((b) {
                    final data = Map<String, dynamic>.from(b.data() ?? {});
                    data['id'] = b.id;

                      // Calculate distance if location available
                      if (_currentPosition != null &&
                          data['location'] != null) {
                        data['_distance'] =
                            Geolocator.distanceBetween(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                              ((data['location']['lat'] ?? 0) as num).toDouble(),
                              ((data['location']['lng'] ?? 0) as num).toDouble(),
                            ) /
                            1000;
                      } else {
                        data['_distance'] = 999.0;
                      }
                      return data;
                    }).toList();

                // 🔍 Apply Search Filter (Barber Name or Shop Name)
                final query = _searchController.text.toLowerCase().trim();
                if (query.isNotEmpty) {
                  barberList =
                      barberList.where((b) {
                        final name = (b['name'] ?? "").toString().toLowerCase();
                        final shop =
                            (b['shopName'] ?? "").toString().toLowerCase();
                        return name.contains(query) || shop.contains(query);
                      }).toList();
                }

                // 1. Filter by Min Rating
                if (_minRating > 0) {
                  barberList =
                      barberList.where((b) {
                        final r = ((b['rating'] ?? 4.8) as num).toDouble();
                        return r >= _minRating;
                      }).toList();
                }

                // 2. Sort
                if (_sortBy == "Top Rated") {
                  barberList.sort(
                    (a, b) => ((b['rating'] ?? 4.8) as num).toDouble().compareTo(
                      ((a['rating'] ?? 4.8) as num).toDouble(),
                    ),
                  );
                } else if (_sortBy == "Nearest") {
                  barberList.sort(
                    (a, b) => (a['_distance'] as double).compareTo(
                      b['_distance'] as double,
                    ),
                  );
                } else if (_sortBy == "Popular") {
                  // Assuming popular means more reviews or views if available
                  // For now using rating as fallback
                  barberList.sort(
                    (a, b) => ((b['rating'] ?? 4.8) as num).toDouble().compareTo(
                      ((a['rating'] ?? 4.8) as num).toDouble(),
                    ),
                  );
                }

                if (barberList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "No barbers match your filters",
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Seeding 75 Barbers... Please wait.")),
                            );
                            await SeederService.seedBarbers();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Seeding Complete!"), backgroundColor: Colors.green),
                            );
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text("Seed 75 Barbers"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D189),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: barberList.length,
                  itemBuilder: (context, index) {
                    final bData = barberList[index];
                    final barberId = bData['id'];
                    final imgUrl =
                        (bData['shopPhotos'] != null &&
                                (bData['shopPhotos'] as List).isNotEmpty)
                            ? bData['shopPhotos'][0]
                            : null;
                    final distance = (bData['_distance'] as num).toDouble();

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => BarberProfileScreen(
                                  barberData: bData,
                                  barberId: barberId,
                                  distance:
                                      distance == double.infinity
                                          ? null
                                          : distance,
                                ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child:
                                        imgUrl != null
                                            ? Image.network(
                                              imgUrl,
                                              fit: BoxFit.cover,
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
                                                Icons.store,
                                                color: Colors.white24,
                                              ),
                                            ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bData['shopName'] ?? 'Shop',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${bData['rating'] ?? 4.8}",
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (distance != double.infinity) ...[
                                            const SizedBox(width: 6),
                                            const Text(
                                              "•",
                                              style: TextStyle(
                                                color: Colors.white24,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "${distance.toStringAsFixed(1)} km",
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _toggleFavorite(barberId),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _favoriteBarberIds.contains(barberId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color:
                                      _favoriteBarberIds.contains(barberId)
                                          ? Colors.redAccent
                                          : Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<BaasQuerySnapshot> _buildQuery() {
    var query = BaasClient.collection(
      'users',
    ).where('userType', isEqualTo: 'barber')
     .where('verificationStatus', isEqualTo: 'approved')
     .where('isDiscoverable', isEqualTo: true);

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search barbers or shops...",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF00D189)),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      'All',
      'Haircut',
      'Beard',
      'Facial',
      'Color',
      'Shave',
      'Spa',
    ];
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children:
              categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat;
                        _barberStream = _buildQuery(); // Refresh stream
                      });
                    },
                    labelStyle: GoogleFonts.poppins(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    selectedColor: const Color(0xFF00D189),
                    disabledColor: Colors.white10,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            isSelected
                                ? const Color(0xFF00D189)
                                : Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            "Sort: $_sortBy",
            Icons.sort,
            () => _showSortOptions(),
            true,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            _minRating > 0 ? "$_minRating+" : "Rating",
            Icons.star_outline,
            () => _showRatingFilter(),
            _minRating > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isActive,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isActive
                  ? const Color(0xFF00D189).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isActive
                    ? const Color(0xFF00D189).withOpacity(0.5)
                    : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF00D189) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isActive ? const Color(0xFF00D189) : Colors.white70,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    final options = ["Top Rated", "Nearest", "Popular"];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Sort By",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (opt) => ListTile(
                  title: Text(
                    opt,
                    style: TextStyle(
                      color:
                          _sortBy == opt
                              ? const Color(0xFF00D189)
                              : Colors.white,
                    ),
                  ),
                  trailing:
                      _sortBy == opt
                          ? const Icon(Icons.check, color: Color(0xFF00D189))
                          : null,
                  onTap: () {
                    setState(() => _sortBy = opt);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showRatingFilter() {
    final ratings = [0.0, 4.0, 4.5, 4.8];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Minimum Rating",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...ratings.map(
                (r) => ListTile(
                  title: Text(
                    r == 0.0 ? "All Ratings" : "$r+ Stars",
                    style: TextStyle(
                      color:
                          _minRating == r
                              ? const Color(0xFF00D189)
                              : Colors.white,
                    ),
                  ),
                  trailing:
                      _minRating == r
                          ? const Icon(Icons.check, color: Color(0xFF00D189))
                          : null,
                  onTap: () {
                    setState(() => _minRating = r);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
