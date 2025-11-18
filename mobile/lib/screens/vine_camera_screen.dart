// ABOUTME: Main camera screen with orientation fix and full recording features
// ABOUTME: Uses exact camera preview structure from experimental app to ensure proper orientation

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

class VineCameraScreen extends StatefulWidget {
  const VineCameraScreen({super.key});

  @override
  State<VineCameraScreen> createState() => _VineCameraScreenState();
}

class _VineCameraScreenState extends State<VineCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found';
        });
        return;
      }

      // Use the first camera (usually back camera)
      final camera = cameras.first;

      // Initialize camera controller
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();

      // Lock camera orientation to portrait
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  // Mobile recording: press-hold pattern
  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Recording error: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (!_isRecording) return;

    try {
      await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Recording error: $e';
      });
    }
  }

  // Web recording: toggle pattern
  Future<void> _toggleRecordingWeb() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  bool get _canRecord => _controller != null && _controller!.value.isInitialized && !_isRecording;

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Mobile: press-hold to record (tap down = start, tap up = stop)
        onTapDown: !kIsWeb && _canRecord ? (_) => _startRecording() : null,
        onTapUp: !kIsWeb && _isRecording ? (_) => _stopRecording() : null,
        onTapCancel: !kIsWeb && _isRecording ? () => _stopRecording() : null,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Camera preview - full screen without black bars
          // EXACT structure from experimental app
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 60,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Recording button at the bottom (visible on web, hidden on mobile)
          if (kIsWeb)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleRecordingWeb,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: _isRecording
                        ? const Center(
                            child: Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 40,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'RECORDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ), // End of Stack
      ), // End of GestureDetector
    );
  }
}
