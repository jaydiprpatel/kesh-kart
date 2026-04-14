import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiUrl = 'http://192.168.31.81:8002';
const String projectKey = 'pk_dev_15cff12b887b469c';

final List<String> shopNames = [
  'The Modern Man',
  'Royal Cuts',
  'Style Junction',
  'Urban Fade',
  'Classic Grooming',
  'Elite Barbers',
  'Sharp Looks',
  'Gold Standard',
  'The Hair Port',
  'Vintage Vibes',
  'Precision Barbers',
  'Kingsmen Studio',
  'Gentlemens Choice',
  'Pro Cut Hub',
  'The Groom Room',
  'Trendsetters',
  'Masterpiece Cuts',
  'Signature Style',
  'Dapper Den',
  'The Cut Above',
  'Velvet Scissors',
  'Titanium Fade',
  'Luxe Grooming',
  'The Shave Shop',
  'Barber Blue',
  'Silver Lining',
  'The Mane Event',
  'Urban Edge',
  'Regal Cuts',
  'The Barber Bar',
  'Pristine Perfection',
  'Heritage Barbers',
  'Modish Cuts',
  'The Style Lab',
  'Imperial Grooming',
  'Top Notch Barbers',
  'Ace of Fades',
  'The Sharp Shop',
  'Finishing Touches',
  'Prime Cuts',
];

final List<String> pincodes = [
  '390001',
  '390002',
  '390005',
  '390007',
  '390010',
  '390011',
  '390015',
  '390020',
  '390022',
  '390024',
  '390025',
];

final List<String> images = [
  'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800&q=80',
  'https://images.unsplash.com/photo-1621605815841-aa8801b72e5c?w=800&q=80',
  'https://images.unsplash.com/photo-1599351431247-f13b384668a8?w=800&q=80',
  'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800&q=80',
  'https://images.unsplash.com/photo-1622286332915-a276578a7dc6?w=800&q=80',
  'https://images.unsplash.com/photo-1501625056708-3165b4c4897f?w=800&q=80',
  'https://images.unsplash.com/photo-1493256338651-d82f7acb2b38?w=800&q=80',
  'https://images.unsplash.com/photo-1512690196252-09c3132e185b?w=800&q=80',
  'https://images.unsplash.com/photo-1521446704128-66299944fc6b?w=800&q=80',
  'https://images.unsplash.com/photo-1634151252726-5f3f0f63907c?w=800&q=80',
];

Future<void> seed() async {
  final Random random = Random();
  print('--- Starting Seeding (Target: 75 Barbers) ---');

  for (int i = 0; i < 75; i++) {
    final String name =
        shopNames[random.nextInt(shopNames.length)] + ' ${i + 1}';
    final String pincode = pincodes[random.nextInt(pincodes.length)];

    // Lat: 22.25 to 22.35, Lng: 73.15 to 73.25
    final double lat = 22.25 + (random.nextDouble() * 0.1);
    final double lng = 73.15 + (random.nextDouble() * 0.1);

    final Map<String, dynamic> doc = {
      'name': name,
      'userType': 'barber',
      'pincode': pincode,
      'city': 'Vadodara',
      'location': {'_type': 'geopoint', 'lat': lat, 'lng': lng},
      'rating': 4.0 + (random.nextDouble() * 1.0),
      'todayBookings': random.nextInt(15),
      'profileImage': images[random.nextInt(images.length)],
      'isTrending': random.nextBool(),
      'isTopRated': random.nextDouble() > 0.7,
      'isAvailable': random.nextBool(),
      'services': ['Haircut', 'Beard Trim', 'Shaving', 'Hair Color', 'Facial'],
      'priceRange': '₹200 - ₹800',
      'experience': '${random.nextInt(15) + 3} years',
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/v1/collections/users/documents'),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Key': projectKey,
        },
        body: jsonEncode(doc),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('SUCCESS [${i + 1}/75]: $name added.');
      } else {
        debugPrint('FAILED [${i + 1}/75]: ${response.body}');
      }
    } catch (e) {
      debugPrint('ERROR [${i + 1}/75]: $e');
    }

    // Small delay to avoid hammering
    await Future.delayed(const Duration(milliseconds: 50));
  }

  debugPrint('--- Seeding Completed ---');
}

void main() => seed();
