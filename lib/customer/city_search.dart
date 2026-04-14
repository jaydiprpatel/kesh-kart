import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CitySearchScreen extends StatefulWidget {
  const CitySearchScreen({super.key});

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _allCities = [
    "Ahmedabad",
    "Agra",
    "Amritsar",
    "Aurangabad",
    "Bangalore",
    "Bhopal",
    "Bhubaneswar",
    "Bikaner",
    "Borsad",
    "Bhavnagar",
    "Chandigarh",
    "Chennai",
    "Coimbatore",
    "Cuttack",
    "Dehradun",
    "Delhi",
    "Dhanbad",
    "Faridabad",
    "Gandhinagar",
    "Ghaziabad",
    "Guwahati",
    "Gwalior",
    "Goa",
    "Hyderabad",
    "Hubli",
    "Indore",
    "Imphal",
    "Jaipur",
    "Jabalpur",
    "Jalandhar",
    "Jammu",
    "Jamshedpur",
    "Jodhpur",
    "Kanpur",
    "Kochi",
    "Kolkata",
    "Kota",
    "Khambhat",
    "Kurnool",
    "Lucknow",
    "Ludhiana",
    "Madurai",
    "Mangalore",
    "Meerut",
    "Mumbai",
    "Mysore",
    "Nagpur",
    "Nashik",
    "Noida",
    "Navsari",
    "Patna",
    "Pune",
    "Pondicherry",
    "Petlad",
    "Raipur",
    "Rajkot",
    "Ranchi",
    "Rourkela",
    "Salem",
    "Shimla",
    "Siliguri",
    "Srinagar",
    "Surat",
    "Thiruvananthapuram",
    "Tiruchirappalli",
    "Tirupati",
    "Thane",
    "Udaipur",
    "Ujjain",
    "Vadodara",
    "Varanasi",
    "Vijayawada",
    "Visakhapatnam",
    "Vellore",
    "Warangal",
  ];
  List<String> _filteredCities = [];
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _filteredCities = _allCities;
  }

  String? _getCityForPincodePrefix(String prefix) {
    if (prefix.isEmpty) return null;
    if (prefix.startsWith("56")) return "Bangalore";
    if (prefix.startsWith("40")) return "Mumbai";
    if (prefix.startsWith("11")) return "Delhi";
    if (prefix.startsWith("390")) return "Vadodara";
    if (prefix.startsWith("388")) return "Khambhat";
    if (prefix.startsWith("380")) return "Ahmedabad";
    if (prefix.startsWith("395")) return "Surat";
    if (prefix.startsWith("360")) return "Rajkot";
    return null;
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = _allCities;
      } else {
        // 1. Standard city name match
        final nameMatches =
            _allCities
                .where(
                  (city) => city.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

        // 2. Pincode prefix match logic
        if (RegExp(r'^[0-9]+$').hasMatch(query)) {
          final suggestedCity = _getCityForPincodePrefix(query);
          if (suggestedCity != null && !nameMatches.contains(suggestedCity)) {
            nameMatches.insert(0, suggestedCity); // Prioritize the mapped city
          }
        }

        _filteredCities = nameMatches;
      }
    });
  }

  Future<void> _handleSearchSubmit(String val) async {
    if (val.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    // 1. Try Pincode
    if (RegExp(r'^[0-9]+$').hasMatch(val)) {
      await _submitPincode(val);
      return;
    }

    // 2. Try Geocoding/City Search
    setState(() => _isLoadingLocation = true);
    try {
      List<Location> locations = await locationFromAddress(val);
      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final city = place.locality ?? place.subAdministrativeArea ?? val;
          final pincode = place.postalCode ?? "000000";

          if (mounted) {
            Navigator.pop(context, {
              'city': city,
              'pincode': pincode,
              'lat': locations.first.latitude,
              'lng': locations.first.longitude,
            });
          }
          return; // Success
        }
      }
      _selectCity(val);
    } catch (e) {
      _selectCity(val);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
      }

      Position position = await Geolocator.getCurrentPosition();

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String detectedCity = "Unknown";
      String detectedPincode = "000000";

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        detectedCity =
            place.locality ?? place.subAdministrativeArea ?? "Unknown";
        detectedPincode = place.postalCode ?? "000000";
      }

      if (mounted) {
        Navigator.pop(context, {
          'city': detectedCity,
          'pincode': detectedPincode,
          'lat': position.latitude,
          'lng': position.longitude,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _selectCity(String city) {
    // Default Pincode for city (Mock)
    // In real app, user might select specific locality or we ask pincode next.
    // For now, mapping some defaults.
    String pincode = "560001";
    if (city == "Mumbai") pincode = "400001";
    if (city == "Delhi") pincode = "110001";
    if (city == "Khambhat") pincode = "388620";
    if (city == "Petlad") pincode = "388620";
    if (city == "Vadodara") pincode = "390001";

    // For selected city, we don't have coords immediately.
    // We could geocode here or let Home do it. Let's try to geocode or return null.
    // To keep UI fast, we return null and let Home handle it or just have 0.0 (which is acceptable for manual city pick without GPS).
    // Or we could trigger a background look up.

    // Attempt basic known coords for demo cities to avoid 0.0
    double? lat;
    double? lng;
    if (city == "Bangalore") {
      lat = 12.9716;
      lng = 77.5946;
    }
    if (city == "Mumbai") {
      lat = 19.0760;
      lng = 72.8777;
    }
    if (city == "Delhi") {
      lat = 28.7041;
      lng = 77.1025;
    }
    if (city == "Khambhat") {
      lat = 22.3131;
      lng = 72.6190;
    }
    if (city == "Vadodara") {
      lat = 22.3072;
      lng = 73.1812;
    }

    Navigator.pop(context, {
      'city': city,
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<void> _submitPincode(String input) async {
    if (input.length == 6 && int.tryParse(input) != null) {
      // 1. Hardcoded quick resolution
      String city = "Unknown City";
      if (input.startsWith("56")) {
        city = "Bangalore";
      } else if (input.startsWith("40")) {
        city = "Mumbai";
      } else if (input.startsWith("11")) {
        city = "Delhi";
      } else if (input.startsWith("390")) {
        city = "Vadodara";
      } else if (input == "388620") {
        city = "Khambhat"; // Or Petlad, default to Khambhat
      }

      double? lat;
      double? lng;

      // 2. If Unknown, try geocoding for better robustness
      if (city == "Unknown City") {
        try {
          List<Location> locations = await locationFromAddress(input);
          if (locations.isNotEmpty) {
            lat = locations.first.latitude;
            lng = locations.first.longitude;
            List<Placemark> placemarks = await placemarkFromCoordinates(
              lat,
              lng,
            );
            if (placemarks.isNotEmpty) {
              city =
                  placemarks.first.locality ??
                  placemarks.first.subAdministrativeArea ??
                  city;
            }
          }
        } catch (e) {
          debugPrint("Geocoding failed for pincode: $e");
        }
      }

      if (mounted) {
        Navigator.pop(context, {
          'city': city,
          'pincode': input,
          'lat': lat,
          'lng': lng,
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-digit pincode")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Select Location",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _handleSearchSubmit,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search City or Enter Pincode",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: Color(0xFF00D189),
                  ),
                  onPressed: () => _handleSearchSubmit(_searchController.text),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Use Current Location
            InkWell(
              onTap: _isLoadingLocation ? null : _useCurrentLocation,
              child: Row(
                children: [
                  _isLoadingLocation
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.my_location, color: Color(0xFF00D189)),
                  const SizedBox(width: 15),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Use Current Location",
                        style: TextStyle(
                          color: Color(0xFF00D189),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Using GPS",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),

            // City List
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCities.length,
                itemBuilder: (context, index) {
                  final city = _filteredCities[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.location_city,
                      color: Colors.white54,
                    ),
                    title: Text(
                      city,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _selectCity(city),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
