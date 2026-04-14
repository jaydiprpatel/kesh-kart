class RadarBarber {
  final String barberId;
  final String name;
  final double rating;
  final int todayBookings;
  final DateTime nextAvailableSlot;
  final String profileImage;
  final double distance;

  RadarBarber({
    required this.barberId,
    required this.name,
    required this.rating,
    required this.todayBookings,
    required this.nextAvailableSlot,
    required this.profileImage,
    required this.distance,
  });

  factory RadarBarber.fromJson(Map<String, dynamic> json) {
    return RadarBarber(
      barberId: (json['barberId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      rating: double.tryParse((json['rating'] ?? 0.0).toString()) ?? 0.0,
      todayBookings: int.tryParse((json['todayBookings'] ?? 0).toString()) ?? 0,
      nextAvailableSlot: json['nextAvailableSlot'] != null
          ? DateTime.tryParse(json['nextAvailableSlot'].toString()) ?? DateTime.now()
          : DateTime.now(),
      profileImage: (json['profileImage'] ?? '').toString(),
      distance: double.tryParse((json['distance'] ?? 0.0).toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barberId': barberId,
      'name': name,
      'rating': rating,
      'todayBookings': todayBookings,
      'nextAvailableSlot': nextAvailableSlot.toIso8601String(),
      'profileImage': profileImage,
      'distance': distance,
    };
  }
}
