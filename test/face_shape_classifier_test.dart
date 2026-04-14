import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kesh_kart/features/face_scan/face_shape_classifier.dart';

void main() {
  late FaceShapeClassifier classifier;

  setUp(() {
    classifier = FaceShapeClassifier();
  });

  // Helper to create mock Face with specific contour points
  Face createMockFace(List<Point<int>> points) {
    // This is a mock since GoogleMLKit Face is hard to instantiate directly
    // In a real test, we might use a mockito or similar if the class allows.
    // However, classifier.classify(face) expects a real Face object.
    // Looking at the classifier code, it accesses face.contours[FaceContourType.face]?.points
    
    // Since we can't easily instantiate a real Face object without internal constructor access,
    // we might need to refactor the classifier slightly to accept just the points for better testability.
    return _MockFace(points);
  }

  group('FaceShapeClassifier Weighted Scoring', () {
    test('True Round Face', () {
      // Height: 100, Width: 100, Forehead: 90, Jaw: 85 (Ratio 1.0)
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 100);
      points[27] = const Point(0, 50);
      points[9] = const Point(100, 50);
      points[32] = const Point(5, 20);
      points[4] = const Point(95, 20);
      points[22] = const Point(15, 80);
      points[14] = const Point(85, 80);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Round');
    });

    test('True Square Face', () {
      // Height: 100, Width: 100, Forehead: 90, Jaw: 92
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 100);
      points[27] = const Point(0, 50);
      points[9] = const Point(100, 50);
      points[32] = const Point(5, 20);
      points[4] = const Point(95, 20);
      points[22] = const Point(4, 80);
      points[14] = const Point(96, 80);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Square');
    });

    test('True Heart Face', () {
      // Wide forehead, very narrow jaw
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 100);
      points[27] = const Point(0, 50);
      points[9] = const Point(100, 50);
      points[32] = const Point(0, 20);
      points[4] = const Point(100, 20);
      points[22] = const Point(25, 80);  // Narrow jaw (width 50)
      points[14] = const Point(75, 80);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Heart');
      expect(result.secondaryShape, isNotNull);
    });

    test('Clear Oval Face', () {
      // Height: 135, Width: 100
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 135);
      points[27] = const Point(0, 65);
      points[9] = const Point(100, 65);
      points[32] = const Point(10, 30);
      points[4] = const Point(90, 30);
      points[22] = const Point(20, 100);
      points[14] = const Point(80, 100);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Oval');
    });

    test('Narrow Oval Face (Previously misclassified as Heart)', () {
      // Long face (140), narrow jaw (60), narrow forehead (80)
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 140);
      points[27] = const Point(10, 70); // Width 80
      points[9] = const Point(90, 70);
      points[32] = const Point(15, 30);
      points[4] = const Point(85, 30);
      points[22] = const Point(20, 110);
      points[14] = const Point(80, 110);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Oval'); 
    });

    test('Oval Face with Beard (Wide jaw area illusion)', () {
      // Oval but jaw reading is artificially wide (110 vs face width 100)
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 130);
      points[27] = const Point(0, 65);
      points[9] = const Point(100, 65);
      points[32] = const Point(10, 30);
      points[4] = const Point(90, 30);
      // Simulate beard making jaw points wider than cheekbones
      points[22] = const Point(-5, 100);
      points[14] = const Point(105, 100);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Oval'); // Should still recognize oval due to length and beard weighting
    });

    test('Round Face with High Hair Volume (Wide upper forehead illusion)', () {
      // Round but forehead reading is artificially wide
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 100);
      points[27] = const Point(0, 50);
      points[9] = const Point(100, 50);
      // Simulate hair volume making forehead points wider
      points[32] = const Point(-10, 20);
      points[4] = const Point(110, 20);
      points[22] = const Point(15, 80);
      points[14] = const Point(85, 80);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Round'); 
    });

    test('Borderline Oval-Round Case', () {
      // Height ratio exactly 1.16 (just over the 1.15 round boundary)
      final points = List.generate(36, (i) => const Point(0, 0));
      points[0] = const Point(50, 0); 
      points[18] = const Point(50, 116);
      points[27] = const Point(0, 58);
      points[9] = const Point(100, 58);
      points[32] = const Point(10, 20);
      points[4] = const Point(90, 20);
      points[22] = const Point(15, 90);
      points[14] = const Point(85, 90);
      
      final result = classifier.classify(createMockFace(points));
      expect(result.primaryShape, 'Oval'); // Should favor Oval just past the boundary
      expect(result.secondaryShape, anyOf('Round', 'Square')); 
    });

  });
}

// Simple mock for testing without full ML Kit overhead
class _MockFace implements Face {
  final List<Point<int>> _points;
  _MockFace(this._points);

  @override
  Map<FaceContourType, FaceContour?> get contours => {
    FaceContourType.face: FaceContour(type: FaceContourType.face, points: _points),
  };

  @override
  Rect get boundingBox => throw UnimplementedError();
  @override
  double? get headEulerAngleX => null;
  @override
  double? get headEulerAngleY => null;
  @override
  double? get headEulerAngleZ => null;
  @override
  double? get leftEyeOpenProbability => null;
  @override
  double? get rightEyeOpenProbability => null;
  @override
  double? get smilingProbability => null;
  @override
  int? get trackingId => null;
  @override
  Map<FaceLandmarkType, FaceLandmark?> get landmarks => {};
}
