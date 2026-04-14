class Style {
  final String styleId;
  final String name;
  final String description;
  final String imageUrl;
  final String difficulty;
  final double popularityScore;

  Style({
    required this.styleId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.difficulty,
    required this.popularityScore,
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      styleId: json['styleId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      difficulty: json['difficulty'] ?? 'easy',
      popularityScore: (json['popularityScore'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'styleId': styleId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'difficulty': difficulty,
      'popularityScore': popularityScore,
    };
  }
}
