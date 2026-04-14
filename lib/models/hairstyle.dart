class Hairstyle {
  final String id;
  final String name;
  final String category;
  final List<String> purposes;
  final Map<String, dynamic> attributes;
  final String description;
  final Map<String, dynamic> media;
  final Map<String, bool> flags;
  final Map<String, int> metrics;
  final DateTime createdAt;
  final DateTime updatedAt;

  Hairstyle({
    required this.id,
    required this.name,
    required this.category,
    required this.purposes,
    required this.attributes,
    required this.description,
    required this.media,
    required this.flags,
    required this.metrics,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters for convenience
  String get hairLength => attributes['hair_length'] ?? 'medium';
  String get maintenance => attributes['maintenance'] ?? 'medium';
  bool get beardCompatible => attributes['beard_compatible'] ?? false;
  String get coverImage => media['cover_image'] ?? '';
  List<String> get gallery => List<String>.from(media['gallery'] ?? []);
  bool get isTrending => flags['trending'] ?? false;

  factory Hairstyle.fromJson(Map<String, dynamic> json) {
    return Hairstyle(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'hair',
      purposes: List<String>.from(json['purposes'] ?? []),
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
      description: json['description'] ?? '',
      media: Map<String, dynamic>.from(json['media'] ?? {}),
      flags: Map<String, bool>.from(json['flags'] ?? {}),
      metrics: Map<String, int>.from(json['metrics'] ?? {}),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'purposes': purposes,
      'attributes': attributes,
      'description': description,
      'media': media,
      'flags': flags,
      'metrics': metrics,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
