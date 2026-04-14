import 'package:flutter/cupertino.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class HeuristicService {
  static Future<List<Map<String, dynamic>>> getMultiGroomingInsights(
    String userId,
  ) async {
    try {
      // Fetch last 15 appointments to get a good history
      final snapshot =
          await BaasClient.collection('appointments')
              .where('customerId', isEqualTo: userId)
              .orderBy('time', descending: true)
              .limit(15)
              .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Group by barberId
      final Map<String, List<DateTime>> barberVisits = {};
      final Map<String, String> barberNames = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final barberId = data['barberId'];
        final barberName = data['barberName'];
        final rawTime = data['time'];
        DateTime? visitDate;

        if (rawTime is DateTime) {
          visitDate = rawTime;
        } else if (rawTime is String) {
          visitDate = DateTime.tryParse(rawTime);
        } else if (rawTime != null) {
          // Attempt parsing from String version of unknown types
          visitDate = DateTime.tryParse(rawTime.toString());
        }

        if (visitDate != null && barberId != null) {
          if (!barberVisits.containsKey(barberId)) {
            barberVisits[barberId] = [];
            barberNames[barberId] = barberName ?? "KeshKart";
          }
          barberVisits[barberId]!.add(visitDate);
        }
      }

      // Calculate insights for each barber
      List<Map<String, dynamic>> results = [];

      barberVisits.forEach((barberId, dates) {
        // Sort dates descending (just in case)
        dates.sort((a, b) => b.compareTo(a));

        final lastVisit = dates.first;
        final barberName = barberNames[barberId];
        double avgGap = 15;

        if (dates.length >= 2) {
          int totalDays = 0;
          for (int i = 0; i < dates.length - 1; i++) {
            totalDays += dates[i].difference(dates[i + 1]).inDays.abs();
          }
          avgGap = totalDays / (dates.length - 1);
          if (avgGap < 1) avgGap = 15;
        }

        results.add({
          'hasHistory': true,
          'barberId': barberId,
          'barberName': barberName,
          'lastVisit': lastVisit,
          'avgGapDays': avgGap.round(),
        });
      });

      // Sort results by most recent lastVisit
      results.sort((a, b) {
        DateTime dA = a['lastVisit'];
        DateTime dB = b['lastVisit'];
        return dB.compareTo(dA);
      });

      return results;
    } catch (e) {
      debugPrint("HeuristicService Multi Error: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> getGroomingInsights(String userId) async {
    final list = await getMultiGroomingInsights(userId);
    if (list.isNotEmpty) {
      return list.first;
    }
    return {'hasHistory': false};
  }
}
