import 'package:kesh_kart/models/hairstyle_preview.dart';

class HairstylePreviewRepository {
  static List<HairstylePreview> getPremiumStyles() {
    return [
      HairstylePreview(
        id: '1',
        name: 'Textured Fade',
        frontImage: 'assets/hairstyles/textured_fade/front.png',
        leftImage: 'assets/hairstyles/textured_fade/left.png',
        rightImage: 'assets/hairstyles/textured_fade/right.png',
        compatibleFaceShapes: ['Oval', 'Round', 'Square'],
        compatibleHairTypes: ['Straight', 'Wavy'],
        relevanceScore: 0.96,
        description: 'A modern, clean look with short textured hair on top and a smooth fade on the sides.',
        tags: ['Trendy', 'Low Maintenance'],
      ),
      HairstylePreview(
        id: '2',
        name: 'Undercut',
        frontImage: 'assets/hairstyles/undercut/front.png',
        leftImage: 'assets/hairstyles/undercut/left.png',
        rightImage: 'assets/hairstyles/undercut/right.png',
        compatibleFaceShapes: ['Oval', 'Diamond', 'Heart'],
        compatibleHairTypes: ['Straight', 'Curly'],
        relevanceScore: 0.88,
        description: 'Bold disconnection between the top and sides, offering a sharp, edgy appearance.',
        tags: ['Sharp', 'Classic'],
      ),
      HairstylePreview(
        id: '3',
        name: 'Pompadour',
        frontImage: 'assets/hairstyles/pompadour/front.png',
        leftImage: 'assets/hairstyles/pompadour/left.png',
        rightImage: 'assets/hairstyles/pompadour/right.png',
        compatibleFaceShapes: ['Oval', 'Square'],
        compatibleHairTypes: ['Straight', 'Thick'],
        relevanceScore: 0.82,
        description: 'Voluminous hair swept upwards and backwards, creating a sophisticated and timeless silhouette.',
        tags: ['Premium', 'Volume'],
      ),
      HairstylePreview(
        id: '4',
        name: 'Quiff',
        frontImage: 'assets/hairstyles/quiff/front.png',
        leftImage: 'assets/hairstyles/quiff/left.png',
        rightImage: 'assets/hairstyles/quiff/right.png',
        compatibleFaceShapes: ['Round', 'Square', 'Heart'],
        compatibleHairTypes: ['Straight', 'Thin'],
        relevanceScore: 0.79,
        description: 'A versatile style that combines the 1950s pompadour, 1950s flattop, and sometimes a mohawk.',
        tags: ['Versatile', 'Modern'],
      ),
      HairstylePreview(
        id: '5',
        name: 'Crew Cut',
        frontImage: 'assets/hairstyles/crew_cut/front.png',
        leftImage: 'assets/hairstyles/crew_cut/left.png',
        rightImage: 'assets/hairstyles/crew_cut/right.png',
        compatibleFaceShapes: ['Oval', 'Round', 'Square', 'Diamond'],
        compatibleHairTypes: ['All types'],
        relevanceScore: 0.85,
        description: 'Short and functional, the crew cut is tapered on the sides and back while keeping more length on top.',
        tags: ['Functional', 'Easy'],
      ),
      HairstylePreview(
        id: '6',
        name: 'Side Part',
        frontImage: 'assets/hairstyles/side_part/front.png',
        leftImage: 'assets/hairstyles/side_part/left.png',
        rightImage: 'assets/hairstyles/side_part/right.png',
        compatibleFaceShapes: ['Oval', 'Round', 'Square', 'Heart'],
        compatibleHairTypes: ['Straight', 'Wavy'],
        relevanceScore: 0.91,
        description: 'Professional and polished, the side part is a staple of traditional mens grooming.',
        tags: ['Formal', 'Polished'],
      ),
    ];
  }

  static List<HairstylePreview> filterByFaceShape(String shape) {
    final all = getPremiumStyles();
    return all.where((s) => s.compatibleFaceShapes.contains(shape)).toList()
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
  }
}
