import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kesh_kart/backend/config.dart';
import 'package:kesh_kart/models/style.dart';

class StyleService {
  Future<List<Style>> getRecommendations({
    required String faceShape,
    required String hairType,
    required String hairDensity,
  }) async {
    try {
      final queryParams = {
        'faceShape': faceShape.toLowerCase(),
        'hairType': hairType.toLowerCase(),
        'hairDensity': hairDensity.toLowerCase(),
      };
      
      final uri = Uri.parse('${BaasConfig.restUrl}/styles/recommendations')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(BaasConfig.timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Style.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load style recommendations');
      }
    } catch (e) {
      print('Error fetching style recommendations: $e');
      return _getMockRecommendations();
    }
  }

  Future<List<dynamic>> getBarbersByStyle(String styleId) async {
    try {
      final uri = Uri.parse('${BaasConfig.restUrl}/barbers/by-style/$styleId');
      final response = await http.get(uri).timeout(BaasConfig.timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load barbers for style');
      }
    } catch (e) {
      print('Error fetching barbers for style: $e');
      return _getMockBarbersForStyle();
    }
  }

  List<Style> _getMockRecommendations() {
    return [
      Style(
        styleId: 'textured_crop',
        name: 'Textured Crop',
        description: 'Short layered haircut with natural texture.',
        imageUrl: 'https://images.unsplash.com/photo-1595152772835-219674b2a8a6?auto=format&fit=crop&q=80&w=800',
        difficulty: 'medium',
        popularityScore: 4.8,
      ),
      Style(
        styleId: 'low_taper_fade',
        name: 'Low Taper Fade',
        description: 'Clean fade with longer hair on top.',
        imageUrl: 'https://images.unsplash.com/photo-1622286332618-f2802b9c74bc?auto=format&fit=crop&q=80&w=800',
        difficulty: 'easy',
        popularityScore: 4.5,
      ),
      Style(
        styleId: 'modern_pompadour',
        name: 'Modern Pompadour',
        description: 'High volume classic look with a modern twist.',
        imageUrl: 'https://images.unsplash.com/photo-1522529599102-193c0d76b5b6?auto=format&fit=crop&q=80&w=800',
        difficulty: 'hard',
        popularityScore: 4.2,
      ),
    ];
  }

  List<Map<String, dynamic>> _getMockBarbersForStyle() {
    return [
      {
        "barberId": "b123",
        "name": "Rahul Barber",
        "rating": 4.9,
        "shopName": "Rahul Men's Salon",
        "distance": 1.2,
        "profileImage": "https://ui-avatars.com/api/?name=Rahul+Barber&background=00D189&color=fff",
        "nextAvailableSlot": "2026-03-12T18:30:00"
      },
      {
        "barberId": "b456",
        "name": "Amit Sharma",
        "rating": 4.7,
        "shopName": "Precision Cuts",
        "distance": 2.5,
        "profileImage": "https://ui-avatars.com/api/?name=Amit+Sharma&background=00D189&color=fff",
        "nextAvailableSlot": "2026-03-12T17:00:00"
      }
    ];
  }
}
