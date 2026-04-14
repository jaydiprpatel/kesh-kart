import 'package:kesh_kart/backend/baas_client.dart';
import 'package:flutter/foundation.dart';

class ReferralService {
  /// Triggers rewards for the inviter when a barber completes their first appointment.
  static Future<void> processBarberFirstAppointment(String barberId) async {
    try {
      // 1. Fetch the invited barber's data
      final barberSnap =
          await BaasClient.collection('users').doc(barberId).get();
      if (!barberSnap.exists) return;

      final barberData = barberSnap.data() as Map<String, dynamic>;

      // 2. Safety check: Only process once
      if (barberData['referralProcessed'] == true) return;
      if (barberData['userType'] != 'barber') return;

      // 3. Identification: Who invited them?
      final inviterId = barberData['invitedBy'];
      if (inviterId == null || inviterId == 'ADMIN') {
        // No inviter to reward, but mark as processed to stop future checks
        await BaasClient.collection(
          'users',
        ).doc(barberId).update({'referralProcessed': true});
        return;
      }

      // 4. Atomic Reward Logic for Inviter
      await BaasClient.instance.sdk.runTransaction((tx) async {
        final inviterRef = BaasClient.instance.sdk
            .collection('users')
            .doc(inviterId);
        final inviterDoc = await tx.get(inviterRef);
        final inviterData = inviterDoc.data;

        // Granular Safety Check: Has THIS specific barber already triggered a reward?
        List<String> processedEvents = List<String>.from(
          inviterData['processedReferralEvents'] ?? [],
        );
        if (processedEvents.contains(barberId)) return;

        // If inviter already has 5 invites, they are maxed out (FREE tier)
        int currentInvites = processedEvents.length;
        if (currentInvites >= 5) return;

        int newInviteCount = currentInvites + 1;
        processedEvents.add(barberId);

        // Reward Tier Mapping (Launch Price Ladder: ₹199 default)
        int newPrice = 199;
        if (newInviteCount == 1) {
          newPrice = 179;
        } else if (newInviteCount == 2) {
          newPrice = 149;
        } else if (newInviteCount == 3) {
          newPrice = 119;
        } else if (newInviteCount == 4) {
          newPrice = 99;
        } else if (newInviteCount >= 5) {
          newPrice = 0; // FREE
        }

        final Map<String, dynamic> updateData = {
          'processedReferralEvents': processedEvents,
          'successfulBarberInvites': newInviteCount,
          'currentSubscriptionPrice': newPrice,
          'highestRewardTierUnlocked': newInviteCount,
        };

        // All rewards grant 3 months of the new price
        updateData['discountExpiry'] =
            DateTime.now().add(const Duration(days: 90)).toIso8601String();

        if (newPrice == 0) {
          updateData['freeSubscriptionGranted'] = true;
          // Note: In a real system, we might lock invite generation here too
        }

        tx.update(inviterRef, updateData);
      });

      // 5. Mark the invited barber as processed
      await BaasClient.collection(
        'users',
      ).doc(barberId).update({'referralProcessed': true});
      debugPrint(
        "Referral processed: Inviter $inviterId rewarded for barber $barberId.",
      );
    } catch (e) {
      debugPrint("Error processing barber referral: $e");
    }
  }
}
