class FaceShapeResult {
  final String primaryShape;
  final String secondaryShape;
  final double confidenceScore;

  FaceShapeResult({
    required this.primaryShape,
    required this.secondaryShape,
    required this.confidenceScore,
  });

  @override
  String toString() => 'FaceShapeResult(primary: $primaryShape, secondary: $secondaryShape, confidence: ${confidenceScore.toStringAsFixed(2)})';
}
