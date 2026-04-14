import 'package:flutter/cupertino.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/models/hairstyle.dart';

class HairstyleRepository {
  static const String collectionPath = 'hairstyles';

  Future<List<Hairstyle>> getAllStyles() async {
    try {
      final snapshot = await BaasClient.collection(collectionPath).get();
      final docs = (snapshot as dynamic).docs;
      final styles =
          docs
              .map<Hairstyle>(
                (doc) => Hairstyle.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
      if (styles.isEmpty) return getMockStyles();
      return styles;
    } catch (e) {
      debugPrint("Error fetching all styles: $e");
      return getMockStyles(); // Fallback to mock for now
    }
  }

  Future<List<Hairstyle>> getTrendingStyles() async {
    try {
      final snapshot =
          await BaasClient.collection(
            collectionPath,
          ).where('isTrending', isEqualTo: true).get();
      final docs = (snapshot as dynamic).docs;
      final styles =
          docs
              .map<Hairstyle>(
                (doc) => Hairstyle.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
      if (styles.isEmpty) {
        return getMockStyles().where((s) => s.isTrending).toList();
      }
      return styles;
    } catch (e) {
      debugPrint("Error fetching trending styles: $e");
      return getMockStyles().where((s) => s.isTrending).toList();
    }
  }

  Future<List<Hairstyle>> getStylesByPurpose(String purpose) async {
    try {
      final snapshot =
          await BaasClient.collection(
            collectionPath,
          ).where('purposes', arrayContains: purpose).get();
      final docs = (snapshot as dynamic).docs;
      final styles =
          docs
              .map<Hairstyle>(
                (doc) => Hairstyle.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList();
      if (styles.isEmpty) {
        return getMockStyles()
            .where((s) => s.purposes.contains(purpose))
            .toList();
      }
      return styles;
    } catch (e) {
      debugPrint("Error fetching styles by purpose: $e");
      return getMockStyles()
          .where((s) => s.purposes.contains(purpose))
          .toList();
    }
  }

  List<Hairstyle> getMockStyles() {
    final now = DateTime.now().toIso8601String();
    final data = [
      {
        "id": "classic_gentleman",
        "name": "Classic Gentleman Cut",
        "category": "hair",
        "purposes": ["office", "formal"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "low",
          "beard_compatible": true,
        },
        "description":
            "A clean, timeless haircut suitable for daily office wear and formal occasions.",
        "media": {
          "cover_image": "assets/styles/classic_gentleman.png",
          "gallery": [],
        },
        "flags": {"trending": true, "recommended": true, "active": true},
        "metrics": {"views": 120, "saves": 45, "bookings": 12},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "low_fade_side_part",
        "name": "Low Fade with Side Part",
        "category": "hair",
        "purposes": ["office", "casual"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "medium",
          "beard_compatible": true,
        },
        "description":
            "A modern fade paired with a neat side part for a professional yet stylish look.",
        "media": {"cover_image": "assets/styles/low_fade.png", "gallery": []},
        "flags": {"trending": true, "recommended": false, "active": true},
        "metrics": {"views": 250, "saves": 80, "bookings": 34},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "textured_crop_fade",
        "name": "Textured Crop Fade",
        "category": "hair",
        "purposes": ["casual", "trendy"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "medium",
          "beard_compatible": false,
        },
        "description":
            "A sharp and youthful cut with texture on top and a clean fade on sides.",
        "media": {
          "cover_image": "assets/styles/textured_crop.png",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": true, "active": true},
        "metrics": {"views": 180, "saves": 60, "bookings": 22},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "french_crop",
        "name": "French Crop",
        "category": "hair",
        "purposes": ["office", "low_maintenance"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "low",
          "beard_compatible": true,
        },
        "description":
            "Ideal for men who want a stylish look with minimal daily styling effort.",
        "media": {
          "cover_image": "assets/styles/french_crop.png",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": false, "active": true},
        "metrics": {"views": 90, "saves": 30, "bookings": 8},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "buzz_cut",
        "name": "Buzz Cut",
        "category": "hair",
        "purposes": ["low_maintenance", "summer"],
        "attributes": {
          "hair_length": "very_short",
          "maintenance": "very_low",
          "beard_compatible": true,
        },
        "description":
            "A no-nonsense cut that’s easy to manage and perfect for hot climates.",
        "media": {"cover_image": "assets/styles/buzz_cut.png", "gallery": []},
        "flags": {"trending": true, "recommended": false, "active": true},
        "metrics": {"views": 300, "saves": 110, "bookings": 54},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "taper_fade_beard",
        "name": "Taper Fade with Beard Shape",
        "category": "hair",
        "purposes": ["casual", "daily_wear"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "medium",
          "beard_compatible": true,
        },
        "description":
            "Clean taper fade complemented with a well-defined beard shape.",
        "media": {"cover_image": "assets/styles/taper_fade.png", "gallery": []},
        "flags": {"trending": true, "recommended": false, "active": true},
        "metrics": {"views": 420, "saves": 150, "bookings": 82},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "slick_back_classic",
        "name": "Slick Back Classic",
        "category": "hair",
        "purposes": ["wedding", "party"],
        "attributes": {
          "hair_length": "medium",
          "maintenance": "high",
          "beard_compatible": true,
        },
        "description":
            "A polished, elegant style best suited for weddings and formal events.",
        "media": {
          "cover_image":
              "https://images.unsplash.com/photo-1595152772835-219674b2a8a6?auto=format&fit=crop&q=80&w=800",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": true, "active": true},
        "metrics": {"views": 210, "saves": 75, "bookings": 40},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "modern_pompadour",
        "name": "Modern Pompadour",
        "category": "hair",
        "purposes": ["party", "trendy"],
        "attributes": {
          "hair_length": "medium",
          "maintenance": "high",
          "beard_compatible": true,
        },
        "description":
            "A bold hairstyle that adds height and volume for a confident appearance.",
        "media": {
          "cover_image":
              "https://images.unsplash.com/photo-1622286332618-f2802b9c74bc?auto=format&fit=crop&q=80&w=800",
          "gallery": [],
        },
        "flags": {"trending": true, "recommended": false, "active": true},
        "metrics": {"views": 380, "saves": 130, "bookings": 68},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "curly_top_fade",
        "name": "Curly Top with Fade",
        "category": "hair",
        "purposes": ["casual", "trendy"],
        "attributes": {
          "hair_length": "medium",
          "maintenance": "medium",
          "beard_compatible": true,
        },
        "description":
            "Keeps natural curls on top with a clean fade on the sides.",
        "media": {"cover_image": "assets/styles/curly_top.png", "gallery": []},
        "flags": {"trending": false, "recommended": false, "active": true},
        "metrics": {"views": 150, "saves": 55, "bookings": 28},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "medium_layered",
        "name": "Medium Length Layered Cut",
        "category": "hair",
        "purposes": ["casual", "office"],
        "attributes": {
          "hair_length": "medium",
          "maintenance": "medium",
          "beard_compatible": false,
        },
        "description":
            "Balanced and versatile cut suitable for both work and casual outings.",
        "media": {
          "cover_image": "assets/styles/medium_layered.png",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": false, "active": true},
        "metrics": {"views": 110, "saves": 40, "bookings": 18},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "full_beard_sculpt",
        "name": "Full Beard Sculpt",
        "category": "beard",
        "purposes": ["style_upgrade"],
        "attributes": {
          "hair_length": "n_a",
          "maintenance": "medium",
          "beard_compatible": true,
        },
        "description":
            "A professionally sculpted beard that enhances facial structure.",
        "media": {"cover_image": "assets/styles/full_beard.png", "gallery": []},
        "flags": {"trending": true, "recommended": true, "active": true},
        "metrics": {"views": 500, "saves": 200, "bookings": 105},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "short_beard_sharp",
        "name": "Short Beard with Sharp Lines",
        "category": "beard",
        "purposes": ["office", "daily_wear"],
        "attributes": {
          "hair_length": "n_a",
          "maintenance": "low",
          "beard_compatible": true,
        },
        "description":
            "Clean and sharp beard lines for a neat everyday appearance.",
        "media": {
          "cover_image": "assets/styles/short_beard.png",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": false, "active": true},
        "metrics": {"views": 160, "saves": 65, "bookings": 38},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "wedding_groom_special",
        "name": "Wedding Groom Special",
        "category": "hair",
        "purposes": ["wedding"],
        "attributes": {
          "hair_length": "medium",
          "maintenance": "high",
          "beard_compatible": true,
        },
        "description":
            "A premium groom-focused style with precise finishing and detailing.",
        "media": {
          "cover_image":
              "https://images.unsplash.com/photo-1522529599102-193c0d76b5b6?auto=format&fit=crop&q=80&w=800",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": true, "active": true},
        "metrics": {"views": 270, "saves": 100, "bookings": 62},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "party_fade_look",
        "name": "Party Fade Look",
        "category": "hair",
        "purposes": ["party", "trendy"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "medium",
          "beard_compatible": true,
        },
        "description":
            "A sharp fade designed to stand out at parties and social events.",
        "media": {"cover_image": "assets/styles/party_fade.png", "gallery": []},
        "flags": {"trending": true, "recommended": false, "active": true},
        "metrics": {"views": 440, "saves": 170, "bookings": 88},
        "created_at": now,
        "updated_at": now,
      },
      {
        "id": "minimalist_daily",
        "name": "Minimalist Daily Cut",
        "category": "hair",
        "purposes": ["office", "low_maintenance"],
        "attributes": {
          "hair_length": "short",
          "maintenance": "low",
          "beard_compatible": true,
        },
        "description":
            "Simple, clean, and easy to maintain for daily routines.",
        "media": {
          "cover_image":
              "https://images.unsplash.com/photo-1544348817-5f2cf14b88c8?auto=format&fit=crop&q=80&w=800",
          "gallery": [],
        },
        "flags": {"trending": false, "recommended": false, "active": true},
        "metrics": {"views": 130, "saves": 50, "bookings": 24},
        "created_at": now,
        "updated_at": now,
      },
    ];
    return data.map((item) => Hairstyle.fromJson(item)).toList();
  }
}
