import 'package:flutter/cupertino.dart';
import 'package:kesh_kart/backend/baas_client.dart';

class LoyaltyService {
  static const int rewardThreshold = 5;

  static Future<int> getPoints(String userId, String barberId) async {
    try {
      final docId = "${userId}_$barberId";
      final doc =
          await BaasClient.collection('loyalty_points').doc(docId).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['points'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint("Error getting loyalty points: $e");
      return 0;
    }
  }

  static Future<void> incrementPoints(String userId, String barberId) async {
    try {
      final docId = "${userId}_$barberId";
      final doc =
          await BaasClient.collection('loyalty_points').doc(docId).get();

      if (doc.exists) {
        final currentPoints =
            (doc.data() as Map<String, dynamic>)['points'] ?? 0;
        await BaasClient.collection('loyalty_points').doc(docId).update({
          'points': currentPoints + 1,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        await BaasClient.collection('loyalty_points').doc(docId).set({
          'customerId': userId,
          'barberId': barberId,
          'points': 1,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint("Error incrementing loyalty points: $e");
    }
  }

  static Future<bool> claimReward(String userId, String barberId) async {
    try {
      final docId = "${userId}_$barberId";
      final doc =
          await BaasClient.collection('loyalty_points').doc(docId).get();

      if (doc.exists) {
        final currentPoints =
            (doc.data() as Map<String, dynamic>)['points'] ?? 0;
        if (currentPoints >= rewardThreshold) {
          await BaasClient.collection('loyalty_points').doc(docId).update({
            'points': currentPoints - rewardThreshold,
            'updatedAt': DateTime.now().toIso8601String(),
            'rewardsClaimed':
                ((doc.data() as Map<String, dynamic>)['rewardsClaimed'] ?? 0) +
                1,
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error claiming reward: $e");
      return false;
    }
  }

  static Stream loyaltyStream(String userId, String barberId) {
    final docId = "${userId}_$barberId";
    return BaasClient.collection('loyalty_points').doc(docId).snapshots();
  }
}
