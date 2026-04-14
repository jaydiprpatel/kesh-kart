import 'package:kesh_kart/backend/baas_snapshot.dart';

class BaasQuerySnapshot {
  final List<BaasSnapshot> docs;

  BaasQuerySnapshot(this.docs);

  int get size => docs.length;
  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
}
