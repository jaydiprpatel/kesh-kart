import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:kesh_kart/backend/baas_client.dart';
import 'package:kesh_kart/backend/baas_query_snapshot.dart';
import 'package:kesh_kart/backend/baas_snapshot.dart';
import 'package:my_baas_sdk/my_baas_sdk.dart' as sdk;

class _QueryOp {
  final String type; // 'where', 'limit', 'near', 'orderBy'
  final String? field;
  final Map<String, dynamic> params;

  _QueryOp(this.type, {this.field, this.params = const {}});
}

class BaasQuery {
  final String? path;
  final List<_QueryOp> _ops;

  BaasQuery({this.path, List<_QueryOp>? ops}) : _ops = ops ?? [];

  BaasQuery where(
    String field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    bool? isNull,
  }) {
    final newOps = List<_QueryOp>.from(_ops);
    final params = <String, dynamic>{};
    if (isEqualTo != null) params['isEqualTo'] = isEqualTo;
    if (isNotEqualTo != null) params['isNotEqualTo'] = isNotEqualTo;
    if (isLessThan != null) params['isLessThan'] = isLessThan;
    if (isLessThanOrEqualTo != null)
      params['isLessThanOrEqualTo'] = isLessThanOrEqualTo;
    if (isGreaterThan != null) params['isGreaterThan'] = isGreaterThan;
    if (isGreaterThanOrEqualTo != null)
      params['isGreaterThanOrEqualTo'] = isGreaterThanOrEqualTo;
    if (isNull != null) params['isNull'] = isNull;

    newOps.add(_QueryOp('where', field: field, params: params));
    return BaasQuery(path: path, ops: newOps);
  }

  BaasQuery limit(int limit) {
    final newOps = List<_QueryOp>.from(_ops);
    newOps.add(_QueryOp('limit', params: {'limit': limit}));
    return BaasQuery(path: path, ops: newOps);
  }

  BaasQuery near(
    String field, {
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final newOps = List<_QueryOp>.from(_ops);
    newOps.add(
      _QueryOp(
        'near',
        field: field,
        params: {'lat': lat, 'lng': lng, 'radiusKm': radiusKm},
      ),
    );
    return BaasQuery(path: path, ops: newOps);
  }

  BaasQuery orderBy(String field, {bool descending = false}) {
    final newOps = List<_QueryOp>.from(_ops);
    newOps.add(
      _QueryOp('orderBy', field: field, params: {'descending': descending}),
    );
    return BaasQuery(path: path, ops: newOps);
  }

  sdk.Query _buildSdkQuery() {
    var q = BaasClient.instance.sdk.collection(path!).query();
    for (var op in _ops) {
      if (op.type == 'where') {
        q.where(
          op.field!,
          isEqualTo: op.params['isEqualTo'],
          isLessThan: op.params['isLessThan'],
          isLessThanOrEqualTo: op.params['isLessThanOrEqualTo'],
          isGreaterThan: op.params['isGreaterThan'],
          isGreaterThanOrEqualTo: op.params['isGreaterThanOrEqualTo'],
          isNull: op.params['isNull'],
        );
      } else if (op.type == 'limit') {
        q.limit(op.params['limit']);
      } else if (op.type == 'near') {
        q.near(
          op.field!,
          lat: (op.params['lat'] as num).toDouble(),
          lng: (op.params['lng'] as num).toDouble(),
          radiusKm: (op.params['radiusKm'] as num).toDouble(),
        );
      } else if (op.type == 'orderBy') {
        q.orderBy(op.field!, descending: op.params['descending'] ?? false);
      }
    }
    return q;
  }

  Future<BaasQuerySnapshot> get() async {
    try {
      final q = _buildSdkQuery();
      final results = await q.get(); // Returns List<CollectionDocument>

      final docs = results.map((d) => BaasSnapshot(d.id, d.data)).toList();
      return BaasQuerySnapshot(docs);
    } catch (e) {
      debugPrint("BaasQuery Error: $e");
      rethrow;
    }
  }

  Stream<BaasQuerySnapshot> snapshots() {
    final q = _buildSdkQuery();
    return q.onSnapshot().map((sdkSnapshot) {
      // sdkSnapshot has .docs (List<CollectionDocument>)
      final docs =
          sdkSnapshot.docs.map((d) => BaasSnapshot(d.id, d.data)).toList();
      return BaasQuerySnapshot(docs);
    });
  }
}
