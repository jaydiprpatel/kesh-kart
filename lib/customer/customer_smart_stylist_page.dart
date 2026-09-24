import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kesh_kart/bedrock_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerSmartStylistPage extends StatefulWidget {
  const CustomerSmartStylistPage({super.key});

  @override
  State<CustomerSmartStylistPage> createState() =>
      _CustomerSmartStylistPageState();
}

class _CustomerSmartStylistPageState extends State<CustomerSmartStylistPage> {
  static const Color _primary = Color(0xFF091426);
  static const Color _accent = Color(0xFF0A66C2);

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  CameraController? _cameraController;
  bool _showStylist = false;
  bool _loadingCamera = true;
  bool _cameraUnavailable = false;
  bool _processingFrame = false;
  bool _loadingRecommendations = false;
  String _selectedFaceShape = '';
  String _detectionStatus = 'Starting front camera...';
  List<_StyleSuggestion> _recommendations = const [];

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _stopCameraStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _startCamera() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _cameraUnavailable = true;
        _loadingCamera = false;
        _detectionStatus = 'Face detection is available on Android and iOS.';
      });
      return;
    }

    setState(() {
      _loadingCamera = true;
      _cameraUnavailable = false;
      _detectionStatus = 'Starting front camera...';
    });

    try {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        setState(() {
          _cameraUnavailable = true;
          _loadingCamera = false;
          _detectionStatus =
              cameraStatus.isPermanentlyDenied
                  ? 'Camera permission is blocked. Enable it from app settings.'
                  : 'Camera permission is required for face shape detection.';
        });
        return;
      }

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _loadingCamera = false;
        _detectionStatus = 'Keep your face inside the frame.';
      });

      await controller.startImageStream(_processCameraImage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraUnavailable = true;
        _loadingCamera = false;
        _detectionStatus =
            'Camera could not start. Please allow camera permission.';
      });
    }
  }

  Future<void> _stopCameraStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processingFrame || _showStylist) return;
    _processingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted || faces.isEmpty) {
        if (mounted && _selectedFaceShape.isEmpty) {
          setState(() => _detectionStatus = 'No face detected yet.');
        }
        return;
      }

      faces.sort(
        (a, b) => b.boundingBox.size.longestSide.compareTo(
          a.boundingBox.size.longestSide,
        ),
      );
      final detectedShape = _classifyFaceShape(faces.first);
      if (detectedShape.isNotEmpty && detectedShape != _selectedFaceShape) {
        setState(() {
          _selectedFaceShape = detectedShape;
          _detectionStatus = 'Detected $_selectedFaceShape face shape.';
        });
      }
    } catch (_) {
      if (mounted && _selectedFaceShape.isEmpty) {
        setState(() => _detectionStatus = 'Scanning face shape...');
      }
    } finally {
      _processingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid && image.planes.length != 1) return null;

    final bytes = _concatenatePlanes(image.planes);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  String _classifyFaceShape(Face face) {
    final box = face.boundingBox;
    final width = box.width;
    final height = box.height;
    if (width <= 0 || height <= 0) return '';

    final faceRatio = width / height;
    final contour = face.contours[FaceContourType.face]?.points;
    if (contour == null || contour.length < 8) {
      if (faceRatio < 0.62) return 'Long';
      if (faceRatio > 0.82) return 'Round';
      return 'Oval';
    }

    final points =
        contour
            .map((point) => Offset(point.x.toDouble(), point.y.toDouble()))
            .toList();
    final foreheadWidth = _widthAt(points, box, 0.28);
    final cheekWidth = _widthAt(points, box, 0.46);
    final jawWidth = _widthAt(points, box, 0.72);

    if (faceRatio < 0.60) return 'Long';
    if (cheekWidth > 0 &&
        foreheadWidth > 0 &&
        jawWidth > 0 &&
        cheekWidth > foreheadWidth * 1.10 &&
        cheekWidth > jawWidth * 1.10) {
      return 'Diamond';
    }
    if (foreheadWidth > 0 && jawWidth > 0 && foreheadWidth > jawWidth * 1.15) {
      return 'Heart';
    }
    if (jawWidth > 0 && cheekWidth > 0 && jawWidth >= cheekWidth * 0.88) {
      return 'Square';
    }
    if (faceRatio > 0.78) return 'Round';
    return 'Oval';
  }

  double _widthAt(List<Offset> points, Rect box, double relativeY) {
    final targetY = box.top + box.height * relativeY;
    final tolerance = math.max(12.0, box.height * 0.08);
    final matching = points.where(
      (point) => (point.dy - targetY).abs() <= tolerance,
    );
    if (matching.length < 2) return 0;

    final xs = matching.map((point) => point.dx);
    return xs.reduce(math.max) - xs.reduce(math.min);
  }

  Future<void> _showSmartStylist() async {
    if (_selectedFaceShape.isEmpty) return;
    await _stopCameraStream();
    setState(() {
      _showStylist = true;
      _loadingRecommendations = true;
      _recommendations = const [];
    });

    final rows = await BedrockClient().getStyleRecommendations(
      _selectedFaceShape,
    );
    if (!mounted) return;

    setState(() {
      _recommendations =
          rows
              .map(_StyleSuggestion.fromBackend)
              .whereType<_StyleSuggestion>()
              .toList();
      _loadingRecommendations = false;
    });
  }

  Future<void> _rescanFaceShape() async {
    setState(() {
      _showStylist = false;
      _selectedFaceShape = '';
      _recommendations = const [];
      _detectionStatus = 'Starting front camera...';
    });
    await _startCamera();
  }

  Future<void> _completeFlow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_stylist_completed', true);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _primary,
        elevation: 0,
        title: Text(
          _showStylist ? 'Smart Stylist' : 'Face Shape Detector',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _showStylist ? _buildStylistView() : _buildDetectorView(),
      ),
    );
  }

  Widget _buildDetectorView() {
    final controller = _cameraController;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _buildCameraPreview(controller),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scanning face shape',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFaceShape.isEmpty
                    ? _detectionStatus
                    : 'Detected face shape: $_selectedFaceShape',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_selectedFaceShape.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1E3E4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.face_retouching_natural, color: _accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFaceShape,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _rescanFaceShape,
                  child: const Text('Rescan'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _selectedFaceShape.isEmpty ? null : _showSmartStylist,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFC5C6CD),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.auto_awesome),
          label: const Text(
            'SHOW SMART STYLIST',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview(CameraController? controller) {
    if (_loadingCamera) {
      return const ColoredBox(
        color: Color(0xFF111927),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_cameraUnavailable ||
        controller == null ||
        !controller.value.isInitialized) {
      return ColoredBox(
        color: const Color(0xFF111927),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _detectionStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed:
                      _detectionStatus.contains('blocked')
                          ? openAppSettings
                          : _startCamera,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: Text(
                    _detectionStatus.contains('blocked')
                        ? 'OPEN SETTINGS'
                        : 'ALLOW CAMERA',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        Center(
          child: Container(
            width: 220,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: _accent, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStylistView() {
    final styles =
        _recommendations.isEmpty
            ? _fallbackStylesForFaceShape(_selectedFaceShape)
            : _recommendations;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Face shape: $_selectedFaceShape',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Smart Stylist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These styles are selected for your detected face shape. Pick one when you book your next appointment.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_loadingRecommendations)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: _primary)),
          )
        else
          ...styles.map(_buildStyleTile),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _rescanFaceShape,
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.restart_alt),
          label: const Text(
            'SCAN AGAIN',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _completeFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text(
            'COMPLETE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleTile(_StyleSuggestion style) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E3E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _styleImage(style.imageUrl),
        ),
        title: Text(
          style.title,
          style: const TextStyle(color: _primary, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          style.subtitle,
          style: const TextStyle(color: Color(0xFF8590A6)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFC5C6CD)),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${style.title} selected')));
        },
      ),
    );
  }

  Widget _styleImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Image.asset(
              'assets/images/barber.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
      );
    }

    return Image.asset(imageUrl, width: 58, height: 58, fit: BoxFit.cover);
  }

  List<_StyleSuggestion> _fallbackStylesForFaceShape(String faceShape) {
    switch (faceShape) {
      case 'Round':
        return const [
          _StyleSuggestion(
            'High Fade',
            'Adds height and sharper sides',
            'assets/images/barber.png',
          ),
          _StyleSuggestion(
            'Pompadour',
            'Balances round facial lines',
            'assets/images/image1.png',
          ),
          _StyleSuggestion(
            'Textured Quiff',
            'Creates a longer face profile',
            'assets/images/customer.png',
          ),
        ];
      case 'Square':
        return const [
          _StyleSuggestion(
            'Classic Gentleman',
            'Softens a strong jawline',
            'assets/images/barber.png',
          ),
          _StyleSuggestion(
            'Side Part',
            'Clean structured finish',
            'assets/images/image1.png',
          ),
          _StyleSuggestion(
            'Textured Crop',
            'Modern shape with soft edges',
            'assets/images/customer.png',
          ),
        ];
      case 'Heart':
        return const [
          _StyleSuggestion(
            'Medium Fringe',
            'Balances forehead width',
            'assets/images/customer.png',
          ),
          _StyleSuggestion(
            'Layered Side Sweep',
            'Adds width near the jaw',
            'assets/images/image1.png',
          ),
          _StyleSuggestion(
            'Low Fade',
            'Keeps the look clean and balanced',
            'assets/images/barber.png',
          ),
        ];
      case 'Diamond':
        return const [
          _StyleSuggestion(
            'Textured Crop',
            'Adds fullness at the top',
            'assets/images/customer.png',
          ),
          _StyleSuggestion(
            'Side Swept Layers',
            'Softens cheekbone angles',
            'assets/images/image1.png',
          ),
          _StyleSuggestion(
            'Classic Taper',
            'Balanced everyday style',
            'assets/images/barber.png',
          ),
        ];
      case 'Long':
        return const [
          _StyleSuggestion(
            'French Crop',
            'Keeps length visually controlled',
            'assets/images/customer.png',
          ),
          _StyleSuggestion(
            'Low Fade',
            'Avoids extra height on top',
            'assets/images/image1.png',
          ),
          _StyleSuggestion(
            'Side Part',
            'Adds balanced width',
            'assets/images/barber.png',
          ),
        ];
      case 'Oval':
      default:
        return const [
          _StyleSuggestion(
            'Classic Gentleman',
            'Clean office look',
            'assets/images/barber.png',
          ),
          _StyleSuggestion(
            'Low Fade',
            'Sharp everyday style',
            'assets/images/image1.png',
          ),
          _StyleSuggestion(
            'Textured Crop',
            'Casual modern cut',
            'assets/images/customer.png',
          ),
        ];
    }
  }
}

class _StyleSuggestion {
  final String title;
  final String subtitle;
  final String imageUrl;

  const _StyleSuggestion(this.title, this.subtitle, this.imageUrl);

  static _StyleSuggestion? fromBackend(dynamic row) {
    if (row is! Map) return null;
    final name = row['name']?.toString().trim();
    final imageUrl = row['imageUrl']?.toString().trim();
    if (name == null || name.isEmpty || imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    final compatibility = row['compatibility'];
    final percent = compatibility is num ? (compatibility * 100).round() : null;
    final subtitle = percent == null ? 'Recommended style' : '$percent% match';
    return _StyleSuggestion(name, subtitle, imageUrl);
  }
}
