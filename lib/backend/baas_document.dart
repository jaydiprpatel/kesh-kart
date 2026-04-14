import 'package:flutter/cupertino.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/backend/baas_snapshot.dart';

class BaasDocument {
  final String collectionPath;
  final String id;

  BaasDocument(this.collectionPath, this.id);

  Stream<dynamic> snapshots() => subscribe();

  Future<dynamic> get() async {
    try {
      final doc =
          await BaasClient.instance.sdk
              .collection(collectionPath)
              .doc(id)
              .get();
      return BaasSnapshot(id, doc.data);
    } catch (e, stack) {
      debugPrint("DEBUG BaasDocument: Get failed for $collectionPath/$id: $e");
      debugPrint(stack.toString());
      return BaasSnapshot(id, null);
    }
  }

  Future<void> update(Map<String, dynamic> data) async {
    await BaasClient.instance.sdk
        .collection(collectionPath)
        .doc(id)
        .update(data);
  }

  Future<void> set(Map<String, dynamic> data) async {
    await BaasClient.instance.sdk.collection(collectionPath).doc(id).set(data);
  }

  Stream<dynamic> subscribe() {
    // SDK DocumentRef lacks onSnapshot, simulate with Query
    return BaasClient.instance.sdk
        .collection(collectionPath)
        .where('id', isEqualTo: id)
        .limit(1)
        .onSnapshot()
        .map((querySnapshot) {
          if (querySnapshot.docs.isEmpty) {
            return BaasSnapshot(id, null);
          }
          return BaasSnapshot(id, querySnapshot.docs.first.data);
        });
  }
}
