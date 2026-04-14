import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:kesh_kart/backend/config.dart';
import 'package:kesh_kart/models/radar_barber.dart';

class BarberService {
  Future<List<RadarBarber>> getRadarBarbers(double lat, double lng) async {
    try {
      final uri = Uri.parse('${BaasConfig.restUrl}/barbers/radar').replace(
        queryParameters: {'lat': lat.toString(), 'lng': lng.toString()},
      );

      final response = await http.get(uri).timeout(BaasConfig.timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RadarBarber.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load radar barbers');
      }
    } catch (e) {
      debugPrint('Error fetching radar barbers: $e');
      return _getMockRadarBarbers();
    }
  }

  List<RadarBarber> _getMockRadarBarbers() {
    final now = DateTime.now();
    return [
      RadarBarber(
        barberId: '00000000-0000-0000-0000-00000000b123',
        name: 'Rahul Barber',
        rating: 4.9,
        todayBookings: 8,
        nextAvailableSlot: now.add(const Duration(minutes: 15)),
        profileImage: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800&q=80',
        distance: 1.4,
      ),
      RadarBarber(
        barberId: '00000000-0000-0000-0000-00000000b245',
        name: 'Imran Salon',
        rating: 4.8,
        todayBookings: 6,
        nextAvailableSlot: now.add(const Duration(hours: 2)),
        profileImage: 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800&q=80',
        distance: 0.8,
      ),
      RadarBarber(
        barberId: 'b567',
        name: 'Vikas Cuts',
        rating: 4.5,
        todayBookings: 3,
        nextAvailableSlot: now.add(const Duration(minutes: 45)),
        profileImage: 'https://images.unsplash.com/photo-1621605815841-db897c4733dd?w=800&q=80',
        distance: 2.1,
      ),
    ];
  }
}
