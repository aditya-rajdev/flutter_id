import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../../data/storage/app_file_storage.dart';
import '../../../photo_gallery/photo_gallery_screen.dart';

enum QualityMode { auto, high, standard }

enum FaceEnhancementMode { off, natural }

/// Isolate worker for natural skin smoothing while preserving facial features and sharpness.
List<int> _applyNaturalFaceEnhancement(List<int> bytes) {
  try {
    final image = img.decodeImage(Uint8List.fromList(bytes));
    if (image == null) return bytes;

    // Create a subtle gaussian blur for skin smoothing layer
    final smooth = img.gaussianBlur(image, radius: 3);

    // Perform edge-preserving blend:
    // High-contrast edge pixels (eyes, eyebrows, lips, hair, contours) retain 100% original sharpness.
    // Mid-tone skin areas get subtle blend (75% original + 25% smooth), gently softening blemishes and sensor noise.
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pOrig = image.getPixel(x, y);
        final pSmooth = smooth.getPixel(x, y);

        final rDiff = (pOrig.r - pSmooth.r).abs();
        final gDiff = (pOrig.g - pSmooth.g).abs();
        final bDiff = (pOrig.b - pSmooth.b).abs();
        final maxDiff = rDiff > gDiff
            ? (rDiff > bDiff ? rDiff : bDiff)
            : (gDiff > bDiff ? gDiff : bDiff);

        if (maxDiff < 35) {
          final newR = (pOrig.r * 0.75 + pSmooth.r * 0.25).round().clamp(
            0,
            255,
          );
          final newG = (pOrig.g * 0.75 + pSmooth.g * 0.25).round().clamp(
            0,
            255,
          );
          final newB = (pOrig.b * 0.75 + pSmooth.b * 0.25).round().clamp(
            0,
            255,
          );
          image.setPixelRgb(x, y, newR, newG, newB);
        }
      }
    }

    return img.encodeJpg(image, quality: 92);
  } catch (e) {
    debugPrint('Face enhancement error: $e');
    return bytes;
  }
}

class CameraScreen extends StatefulWidget {
  final String schoolName;
  final String className;
  final String sectionName;
  final String startRoll;
  final String endRoll;

  const CameraScreen({
    super.key,
    required this.schoolName,
    required this.className,
    required this.sectionName,
    this.startRoll = '001',
    this.endRoll = '50',
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  FlashMode _flashMode = FlashMode.off;
  bool _showFlashMenu = false;
  bool _showSettingsMenu = false;
  double _zoomLevel = 1.0;

  QualityMode _qualityMode = QualityMode.auto;
  FaceEnhancementMode _faceEnhancementMode = FaceEnhancementMode.off;
  String _detectedResolutionLabel = 'Auto (Max)';

  late int _currentRoll;
  late int _endRollInt;

  bool _isCapturing = false;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _currentRoll = int.tryParse(widget.startRoll) ?? 1;
    _endRollInt = int.tryParse(widget.endRoll) ?? 50;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupController(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  ResolutionPreset _resolvePreset(QualityMode mode) {
    switch (mode) {
      case QualityMode.auto:
      case QualityMode.high:
        return ResolutionPreset.max;
      case QualityMode.standard:
        return ResolutionPreset.high;
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final preset = _resolvePreset(_qualityMode);

    _controller = CameraController(camera, preset, enableAudio: false);

    try {
      await _controller!.initialize();

      // Compute detected resolution details
      if (_controller!.value.isInitialized &&
          _controller!.value.previewSize != null) {
        final size = _controller!.value.previewSize!;
        final width = size.height.toInt();
        final height = size.width.toInt();
        final mp = ((width * height) / 1000000.0).toStringAsFixed(1);
        _detectedResolutionLabel = '${width}x$height ($mp MP)';
      } else {
        _detectedResolutionLabel = 'Detected Max Quality';
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera setup error: $e');
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _setQualityMode(QualityMode mode) async {
    if (_qualityMode == mode) return;
    setState(() {
      _qualityMode = mode;
      _showSettingsMenu = false;
    });

    if (_cameras.isNotEmpty) {
      await _setupController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _setFaceEnhancementMode(FaceEnhancementMode mode) async {
    setState(() {
      _faceEnhancementMode = mode;
      _showSettingsMenu = false;
    });
  }

  Future<void> _setFlash(FlashMode mode) async {
    setState(() {
      _flashMode = mode;
      _showFlashMenu = false;
    });

    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(mode);
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _isFlashing = true;
    });

    // Immediate click sound and haptic feedback
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();

    // Turn off white flash quickly (60ms) for a natural, brief shutter flash
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) {
        setState(() => _isFlashing = false);
      }
    });

    try {
      final XFile imageFile = await _controller!.takePicture();
      var bytes = await imageFile.readAsBytes();

      // Apply optional Natural Face Enhancement if enabled
      if (_faceEnhancementMode == FaceEnhancementMode.natural) {
        bytes = Uint8List.fromList(
          await compute(_applyNaturalFaceEnhancement, bytes),
        );
      }

      await AppFileStorage.saveStudentPhoto(
        schoolName: widget.schoolName,
        className: widget.className,
        sectionName: widget.sectionName,
        rollNumber: _currentRoll,
        imageBytes: bytes,
      );

      if (mounted) {
        setState(() {
          if (_currentRoll < _endRollInt) {
            _currentRoll++;
          }
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Captured Roll ${_currentRoll.toString().padLeft(3, '0')}${_faceEnhancementMode == FaceEnhancementMode.natural ? " ✨ (Enhanced)" : ""}',
            ),
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Capture exception: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isFlashing = false;
        });
      }
    }
  }

  void _skipRoll() {
    AppFileStorage.addSkippedRoll(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
      rollNumber: _currentRoll,
    );

    setState(() {
      if (_currentRoll < _endRollInt) {
        _currentRoll++;
      }
    });
  }

  void _showJumpDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text(
            'Jump to Roll Number',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Enter Roll No. (1 to $_endRollInt)',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
              ),
              onPressed: () {
                final roll = int.tryParse(controller.text.trim());
                if (roll != null && roll >= 1 && roll <= _endRollInt) {
                  setState(() => _currentRoll = roll);
                  Navigator.pop(dialogContext);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Enter roll number between 1 and $_endRollInt',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Jump',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CapturedPhotosGalleryScreen(
          schoolName: widget.schoolName,
          className: widget.className,
          sectionName: widget.sectionName,
          startRoll: widget.startRoll,
          endRoll: widget.endRoll,
        ),
      ),
    );
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
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Viewport Preview
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Shutter Flash Feedback Animation Overlay
            if (_isFlashing)
              Positioned.fill(
                child: Container(color: Colors.white.withValues(alpha: 0.8)),
              ),

            // Top Control Overlay Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _showFlashMenu = !_showFlashMenu;
                      _showSettingsMenu = false;
                    }),
                    icon: Icon(
                      _flashMode == FlashMode.always
                          ? Icons.flash_on
                          : _flashMode == FlashMode.auto
                          ? Icons.flash_auto
                          : Icons.flash_off,
                      color: _flashMode != FlashMode.off
                          ? const Color(0xFFFFB300)
                          : Colors.white,
                      size: 26,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _showSettingsMenu = !_showSettingsMenu;
                      _showFlashMenu = false;
                    }),
                    icon: Icon(
                      Icons.tune,
                      color:
                          (_qualityMode != QualityMode.auto ||
                              _faceEnhancementMode != FaceEnhancementMode.off)
                          ? const Color(0xFFFFB300)
                          : Colors.white,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  // HUD Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${widget.className} ${widget.sectionName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(
                          'Roll: ${_currentRoll.toString().padLeft(3, '0')}',
                          style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Flash Selection Drawer Menu
            if (_showFlashMenu)
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Card(
                  color: const Color(0xFF121214),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _flashOption('Off', FlashMode.off),
                        _flashOption('On', FlashMode.always),
                        _flashOption('Auto', FlashMode.auto),
                        _flashOption('Torch', FlashMode.torch),
                      ],
                    ),
                  ),
                ),
              ),

            // Quality & Face Enhancement Drawer Menu
            if (_showSettingsMenu)
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Card(
                  color: const Color(0xFF121214),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Camera Quality',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _detectedResolutionLabel,
                                style: const TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _qualityChip('Auto', QualityMode.auto),
                            const SizedBox(width: 8),
                            _qualityChip('High', QualityMode.high),
                            const SizedBox(width: 8),
                            _qualityChip('Standard', QualityMode.standard),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Face Enhancement',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Subtle skin smoothing for student ID photos',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _enhancementChip('Off', FaceEnhancementMode.off),
                            const SizedBox(width: 8),
                            _enhancementChip(
                              'Natural ✨',
                              FaceEnhancementMode.natural,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Camera Control Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom Control Selector Pill
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _zoomButton('1x', 1.0),
                            const SizedBox(width: 6),
                            _zoomButton('2x', 2.0),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Gallery Icon
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _openGallery,
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),

                        // Shutter Trigger Button
                        GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                        // Switch Lens Icon
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF19191B),
                            shape: const CircleBorder(),
                          ),
                          onPressed: _toggleCameraLens,
                          icon: const Icon(
                            Icons.cameraswitch,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quick Toolbar: Skip, Retake, Jump
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121214),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _skipRoll,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.skip_next,
                                    color: Color(0xFFFF6D00),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: Color(0xFFFF6D00),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _takePicture,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    color: Color(0xFFFFD600),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Retake',
                                    style: TextStyle(
                                      color: Color(0xFFFFD600),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _showJumpDialog,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.redo,
                                    color: Color(0xFF00E5FF),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Jump',
                                    style: TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityChip(String title, QualityMode mode) {
    final selected = _qualityMode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _setQualityMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFB300) : Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _enhancementChip(String title, FaceEnhancementMode mode) {
    final selected = _faceEnhancementMode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _setFaceEnhancementMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFB300) : Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _flashOption(String title, FlashMode mode) {
    final selected = _flashMode == mode;
    return TextButton(
      onPressed: () => _setFlash(mode),
      child: Text(
        title,
        style: TextStyle(
          color: selected ? const Color(0xFFFFB300) : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _zoomButton(String label, double level) {
    final selected = (_zoomLevel - level).abs() < 0.1;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (_controller == null || !_controller!.value.isInitialized) return;
        try {
          final minZoom = await _controller!.getMinZoomLevel();
          final maxZoom = await _controller!.getMaxZoomLevel();
          final targetZoom = level.clamp(minZoom, maxZoom);
          await _controller!.setZoomLevel(targetZoom);
          if (mounted) {
            setState(() => _zoomLevel = targetZoom);
          }
        } catch (e) {
          debugPrint('Zoom level error: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFB300) : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
