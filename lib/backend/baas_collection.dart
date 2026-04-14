import 'package:kesh_kart/backend/baas_document.dart';
import 'package:kesh_kart/backend/baas_query.dart';
import 'package:uuid/uuid.dart'; // For auto-IDs
import 'package:kesh_kart/backend/baas_client.dart'; // Import BaasClient

class BaasCollection {
  final String path;

  BaasCollection(this.path);

  /// Returns a document reference.
  BaasDocument doc(String id) {
    return BaasDocument(path, id);
  }

  // Delegate query methods
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
    return BaasQuery(path: path).where(
      field,
      isEqualTo: _sanitizeValue(isEqualTo),
      isNotEqualTo: _sanitizeValue(isNotEqualTo),
      isLessThan: _sanitizeValue(isLessThan),
      isLessThanOrEqualTo: _sanitizeValue(isLessThanOrEqualTo),
      isGreaterThan: _sanitizeValue(isGreaterThan),
      isGreaterThanOrEqualTo: _sanitizeValue(isGreaterThanOrEqualTo),
      arrayContains: _sanitizeValue(arrayContains),
      arrayContainsAny: arrayContainsAny?.map(_sanitizeValue).toList(),
      whereIn: whereIn?.map(_sanitizeValue).toList(),
      whereNotIn: whereNotIn?.map(_sanitizeValue).toList(),
      isNull: isNull,
    );
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }

  BaasQuery limit(int limit) {
    return BaasQuery(path: path).limit(limit);
  }

  Future<dynamic> get() {
    return BaasQuery(path: path).get();
  }

  Stream<dynamic> snapshots() {
    return BaasQuery(path: path).snapshots();
  }

  Future<dynamic> add(Map<String, dynamic> data) async {
    final sanitizedData = _sanitize(data);

    // Generate Auto ID
    final id = const Uuid().v4();

    await BaasClient.instance.sdk.collection(path).doc(id).set(sanitizedData);

    // Return a BaasDocument
    return BaasDocument(path, id);
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    final Map<String, dynamic> result = {};
    data.forEach((key, value) {
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitize(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
