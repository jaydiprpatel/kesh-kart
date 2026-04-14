import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_shape_result.dart';

class FaceShapeClassifier {
  /// Classifies face shape based on 133 facial contour points.
  /// 
  /// Indices based on ML Kit (0-132):
  /// - 0-35: Face oval
  /// - 124-125: Nose bridge (top)
  /// - 126-128: Nose bottom
  /// 
  /// Face height: Distance from top of forehead (approx contour point 10) to chin (point 18).
  /// Face width: Distance between left and right cheek edges (points 27 and 9).
  /// Forehead width: Width at upper face area.
  /// Jaw width: Width at jaw area.
  FaceShapeResult classify(Face face) {
    if (face.contours.isEmpty) {
      return FaceShapeResult(primaryShape: 'Unknown', secondaryShape: 'Unknown', confidenceScore: 0.0);
    }

    final contour = face.contours[FaceContourType.face]?.points;
    if (contour == null || contour.length < 35) {
      return FaceShapeResult(primaryShape: 'Unknown', secondaryShape: 'Unknown', confidenceScore: 0.0);
    }

    // Reference points from FACE contour (0-35)
    // 0 is top-center, 18 is chin-center
    // 9 is right-center (ear level), 27 is left-center (ear level)
    // 4 is upper right, 32 is upper left
    // 14 is lower right, 22 is lower left
    
    final top = contour[0];
    final chin = contour[18];
    final leftSide = contour[27];
    final rightSide = contour[9];
    
    final foreheadLeft = contour[32];
    final foreheadRight = contour[4];
    
    final jawLeft = contour[22];
    final jawRight = contour[14];

    final faceHeight = _distance(top, chin);
    final faceWidth = _distance(leftSide, rightSide);
    final foreheadWidth = _distance(foreheadLeft, foreheadRight);
    final jawWidth = _distance(jawLeft, jawRight);

    // Ratios
    final heightToWidthRatio = faceHeight / faceWidth;
    final jawToForeheadRatio = jawWidth / foreheadWidth;
    final jawSharpness = jawWidth / faceWidth; // Lower is sharper
    
    // Simulate detecting beard/hair volume based on geometric anomalies 
    // (In a real app, this might come from other ML models, here we use heuristics)
    bool hasBeard = jawWidth > faceWidth * 1.05; // Unusually wide jaw could imply beard
    bool highHairVolume = foreheadWidth > faceWidth * 1.05; // Unusually wide forehead

    Map<String, double> scores = {
      'Oval': 0.0,
      'Round': 0.0,
      'Square': 0.0,
      'Heart': 0.0,
    };

    // --- Scoring Logic ---
    
    // 1. Face Length to Width Ratio
    if (heightToWidthRatio > 1.25) {
      scores['Oval'] = scores['Oval']! + 3.0; // Strong indicator for Oval
    } else if (heightToWidthRatio > 1.15) {
      scores['Oval'] = scores['Oval']! + 1.5;
      scores['Square'] = scores['Square']! + 1.0;
    } else if (heightToWidthRatio >= 0.85 && heightToWidthRatio <= 1.15) {
      scores['Round'] = scores['Round']! + 2.0;
      scores['Square'] = scores['Square']! + 2.0;
    }

    // 2. Jaw Sharpness & Width (Adjusted for Beard)
    double jawWeight = hasBeard ? 0.5 : 1.0;
    if (jawSharpness < 0.75 * jawWeight) {
      // Very sharp jaw. Could be Heart or Oval.
      scores['Heart'] = scores['Heart']! + 1.0; 
      scores['Oval'] = scores['Oval']! + 1.5;
    } else if (jawSharpness > 0.9 * jawWeight) {
      if (hasBeard && heightToWidthRatio > 1.15) {
         // Long face with artificial jaw width -> strongly Oval
         scores['Oval'] = scores['Oval']! + 2.0;
         scores['Square'] = scores['Square']! + 0.5; // Minor square trait
      } else {
         scores['Square'] = scores['Square']! + 2.0; // Strong, wide jaw
      }
    } else {
      scores['Round'] = scores['Round']! + 1.0;
      scores['Oval'] = scores['Oval']! + 0.5;
    }

    // 3. Forehead vs Jaw Width (Adjusted for Hair Volume)
    double foreheadWeight = highHairVolume ? 0.5 : 1.0;
    
    // Strict Heart Check: Forehead significantly wider than jaw AND pointy chin
    // To prevent false positives from hair volume on round faces, we ensure it's not a perfectly round/square face (H/W > 1.05)
    // UNLESS the jaw is exceptionally sharp (< 0.65), which indicates a true Heart shape even on a wider face.
    bool stronglyHeart = jawToForeheadRatio * (foreheadWeight / jawWeight) < 0.75 && 
                         jawSharpness < 0.75 && 
                         (heightToWidthRatio > 1.05 || jawSharpness < 0.65);

    if (stronglyHeart) {
       scores['Heart'] = scores['Heart']! + 3.0; // Heavy weight only if BOTH conditions clearly met
    } else if (jawToForeheadRatio * (foreheadWeight / jawWeight) < 0.75 && jawSharpness >= 0.75) {
       // Wide forehead but not a sharp jaw (often due to hair volume on a round/square face)
       scores['Round'] = scores['Round']! + 1.0; // Increased weight for round to counter Heart bias
    } else if (jawWidth > foreheadWidth * 0.95 * (jawWeight / foreheadWeight)) {
       scores['Square'] = scores['Square']! + 1.5;
    }

    // --- Determine Results ---
    
    // Default to Oval if scores are too low or tied
    if (scores.values.every((score) => score < 2.0)) {
      scores['Oval'] = scores['Oval']! + 2.0;
    }

    var sortedScores = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String primaryShape = sortedScores[0].key;
    String secondaryShape = sortedScores[1].key;
    
    double totalScore = scores.values.fold(0.0, (sum, score) => sum + score);
    double confidence = totalScore > 0 ? sortedScores[0].value / totalScore : 0.0;
    
    // Debug prints to understand failing tests
    // print('Scores: $scores');
    // print('Ratios: H/W=$heightToWidthRatio, Jaw/FB=$jawToForeheadRatio, Sharpness=$jawSharpness');

    return FaceShapeResult(
      primaryShape: primaryShape, 
      secondaryShape: secondaryShape, 
      confidenceScore: confidence
    );
  }

  double _distance(Point<int> p1, Point<int> p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }
}
