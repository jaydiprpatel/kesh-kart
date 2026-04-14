import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class SeederService {
  static Future<void> seedBarbers() async {
    final List<Map<String, dynamic>> neighborhoods = [
      {'name': 'Alkapuri', 'lat': 22.3129, 'lng': 73.1677},
      {'name': 'Gotri', 'lat': 22.3149, 'lng': 73.1361},
      {'name': 'Sayajigunj', 'lat': 22.3102, 'lng': 73.1812},
      {'name': 'Akota', 'lat': 22.2988, 'lng': 73.1685},
      {'name': 'Nizampura', 'lat': 22.3361, 'lng': 73.1789},
      {'name': 'Fatehgunj', 'lat': 22.3214, 'lng': 73.1895},
      {'name': 'Manjalpur', 'lat': 22.2741, 'lng': 73.1822},
      {'name': 'Waghodia Road', 'lat': 22.2995, 'lng': 73.2205},
    ];

    final List<String> categories = ['Haircut', 'Beard', 'Facial', 'Color', 'Shave', 'Spa'];
    
    final List<String> images = [
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800&q=80',
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800&q=80',
      'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800&q=80',
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800&q=80',
      'https://images.unsplash.com/photo-1512690199101-8d0092147101?w=800&q=80',
      'https://images.unsplash.com/photo-1593702295094-ada74bc4a39d?w=800&q=80',
      'https://images.unsplash.com/photo-1532710093739-9470acff878f?w=800&q=80',
      'https://images.unsplash.com/photo-1521449633842-9a7edb7cf665?w=800&q=80',
    ];

    final List<String> firstNames = ['Arjun', 'Vikram', 'Rohan', 'Aditya', 'Siddharth', 'Kabir', 'Aryan', 'Ishaan', 'Rahul', 'Pranav'];
    final List<String> lastNames = ['Sharma', 'Patel', 'Mehta', 'Shah', 'Verma', 'Gupta', 'Singh', 'Desai', 'Mishra', 'Joshi'];
    final List<String> shopSuffixes = ['Studio', 'Parlour', 'Groomers', 'Cuts', 'Styles', 'Hair Craft', 'Legendary', 'Urban', 'Classic'];

    final random = Random();

    debugPrint("🚀 Starting Seeding of 75 Barbers...");

    for (int i = 0; i < 75; i++) {
        final neighborhood = neighborhoods[random.nextInt(neighborhoods.length)];
        final firstName = firstNames[random.nextInt(firstNames.length)];
        final lastName = lastNames[random.nextInt(lastNames.length)];
        final shopSuffix = shopSuffixes[random.nextInt(shopSuffixes.length)];
        
        final barberName = "$firstName $lastName";
        final shopName = "$firstName's $shopSuffix";
        
        // Jitter coordinates within ~1-2km
        final latJitter = (random.nextDouble() - 0.5) * 0.02;
        final lngJitter = (random.nextDouble() - 0.5) * 0.02;
        
        final id = "seeded_barber_$i";
        final phone = "+91${9000000000 + i}";
        final rating = 4.2 + (random.nextDouble() * 0.8);
        final category = categories[random.nextInt(categories.length)];
        final image = images[random.nextInt(images.length)];

        final barberData = {
            'uid': id,
            'phone': phone,
            'name': barberName,
            'email': "${firstName.toLowerCase()}_$i@dvsptech.com",
            'userType': 'barber',
            'hasPassword': true,
            'profileCompleted': true,
            'createdAt': DateTime.now().toIso8601String(),
            'pincode': "390001", // Base pincode for Vadodara
            'cityId': 'vadodara_main',
            'shopName': shopName,
            'shopAddress': "${neighborhood['name']}, Vadodara, Gujarat",
            'location': {
                'lat': (neighborhood['lat'] as double) + latJitter,
                'lng': (neighborhood['lng'] as double) + lngJitter,
            },
            'shopPhotos': [image],
            'verificationStatus': 'verified',
            'rating': double.parse(rating.toStringAsFixed(1)),
            'category': category,
            'successfulBarberInvites': random.nextInt(50),
            'processedReferralEvents': [],
            'highestRewardTierUnlocked': 0,
            'currentSubscriptionPrice': 199,
        };

        try {
            await BaasClient.collection('users').doc(id).set(barberData);
            if (i % 10 == 0) debugPrint("✅ Seeded $i/75 barbers...");
        } catch (e) {
            debugPrint("❌ Error seeding barber $i: $e");
        }
    }

    debugPrint("✨ Seeding Complete! 75 Barbers added.");
  }
}
