import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_detector_service.dart';
import 'face_shape_classifier.dart';
import 'face_shape_result.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  FaceShapeResult? _detectionResult;
  String? _errorMessage;

  final FaceDetectorService _detectorService = FaceDetectorService.instance;
  final FaceShapeClassifier _classifier = FaceShapeClassifier();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isEmpty) {
      setState(() => _errorMessage = "No cameras found");
      return;
    }

    // Use front camera
    final frontCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = "Camera initialization failed: $e");
    }
  }

  Future<void> _captureAndDetect() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      
      final faces = await _detectorService.detectFaces(inputImage);
      
      if (faces.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Face not detected. Ensure your face is within the guide and try again.";
        });
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Multiple faces detected. Please ensure only you are in the frame.";
        });
        return;
      }

      final result = _classifier.classify(faces.first);
      
      setState(() {
        _detectionResult = result;
        _isProcessing = false;
      });

      // Cleanup temporary file
      File(image.path).delete().ignore();
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = "Detection failed: $e";
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Face Scan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _detectionResult != null 
          ? _buildResultUI() 
          : _buildCameraUI(),
    );
  }

  Widget _buildCameraUI() {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00D189)));
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              _buildOverlayGuide(),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF00D189)),
                        const SizedBox(height: 16),
                        Text(
                          'Analyzing landmarks...',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildCameraControls(),
      ],
    );
  }

  Widget _buildOverlayGuide() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.maxWidth * 0.75;
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      height: size,
                      width: size,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(size / 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00D189), width: 2),
                  borderRadius: BorderRadius.circular(size / 2),
                ),
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.2,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'Align your face inside the frame',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Look straight at the camera',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Text(
                    'Ensure good lighting',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isProcessing ? null : _captureAndDetect,
                child: Container(
                  height: 72,
                  width: 72,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Your photo stays on your device and is only used to estimate your face shape.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildResultUI() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF00D189), size: 80),
          const SizedBox(height: 32),
          Text(
            'We think your face shape is',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _detectionResult!.primaryShape.toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 64),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _detectionResult!.primaryShape),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D189),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Use This Shape',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Choose Manually', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isProcessing = false;
                });
                _initializeCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
