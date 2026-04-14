class BaasSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;

  BaasSnapshot(this.id, this._data) : exists = _data != null;

  Map<String, dynamic>? data() => _data;

  dynamic get(String field) {
    if (_data == null) return null;
    return _data[field];
  }

  // Bracket operator support
  dynamic operator [](String field) => get(field);
}
