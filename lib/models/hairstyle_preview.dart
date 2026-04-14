class HairstylePreview {
  final String id;
  final String name;
  final String frontImage;
  final String leftImage;
  final String rightImage;
  final List<String> compatibleFaceShapes;
  final List<String> compatibleHairTypes;
  final double relevanceScore;
  final String description;
  final List<String> tags;

  HairstylePreview({
    required this.id,
    required this.name,
    required this.frontImage,
    required this.leftImage,
    required this.rightImage,
    required this.compatibleFaceShapes,
    required this.compatibleHairTypes,
    this.relevanceScore = 0.0,
    required this.description,
    required this.tags,
  });

  factory HairstylePreview.fromJson(Map<String, dynamic> json) {
    return HairstylePreview(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      frontImage: json['front_image'] ?? '',
      leftImage: json['left_image'] ?? '',
      rightImage: json['right_image'] ?? '',
      compatibleFaceShapes: List<String>.from(json['compatible_face_shapes'] ?? []),
      compatibleHairTypes: List<String>.from(json['compatible_hair_types'] ?? []),
      relevanceScore: (json['relevance_score'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}
