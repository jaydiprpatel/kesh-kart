class GroomingService {
  final String id;
  final String name;
  final double price;
  final String duration;
  final double rating;
  final String image;
  final String category;
  final String? description;
  final List<String> relatedCategories;
  final bool isRecommended;
  final bool isCombo;

  GroomingService({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.rating,
    required this.image,
    required this.category,
    this.description,
    this.relatedCategories = const [],
    this.isRecommended = false,
    this.isCombo = false,
  });

  factory GroomingService.fromJson(Map<String, dynamic> json) {
    return GroomingService(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      duration: json['duration'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      image: json['image'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      relatedCategories: List<String>.from(json['relatedCategories'] ?? []),
      isRecommended: json['isRecommended'] ?? false,
      isCombo: json['isCombo'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration': duration,
      'rating': rating,
      'image': image,
      'category': category,
      'description': description,
      'relatedCategories': relatedCategories,
      'isRecommended': isRecommended,
      'isCombo': isCombo,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroomingService &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
