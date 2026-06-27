import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;

class PremiumImageCropper extends StatefulWidget {
  final XFile imageFile;

  const PremiumImageCropper({super.key, required this.imageFile});

  @override
  State<PremiumImageCropper> createState() => _PremiumImageCropperState();
}

class _PremiumImageCropperState extends State<PremiumImageCropper> {
  final TransformationController _transformationController = TransformationController();
  Uint8List? _imageBytes;
  img.Image? _decodedImage;
  bool _loading = true;
  bool _cropping = false;
  int _rotationAngle = 0; // 0, 90, 180, 270

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _decodedImage = decoded;
            _loading = false;
          });
        }
      } else {
        throw Exception("Failed to decode image");
      }
    } catch (e) {
      debugPrint('[CROP ERROR] Error loading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _rotateImage() {
    if (_decodedImage == null) return;
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
      // Reset transform controller
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _crop() async {
    if (_decodedImage == null || _imageBytes == null || _cropping) return;

    final mediaQuery = MediaQuery.of(context);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _cropping = true);

    // Run cropping in a slight delay to allow loading spinner to render
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final matrix = _transformationController.value;
      final scale = matrix.getMaxScaleOnAxis();
      final tx = matrix.entry(0, 3);
      final ty = matrix.entry(1, 3);

      // Get screen size / layout
      final viewportWidth = mediaQuery.size.width;
      final viewportHeight = mediaQuery.size.height - 180; // height minus top/bottom bars

      final cropSize = min(viewportWidth, viewportHeight) * 0.8;
      final screenX1 = (viewportWidth - cropSize) / 2;
      final screenY1 = (viewportHeight - cropSize) / 2;

      // Apply rotation to original image if needed
      img.Image processedImage = _decodedImage!;
      if (_rotationAngle != 0) {
        processedImage = img.copyRotate(_decodedImage!, angle: _rotationAngle);
      }

      // We laid out the image to fit the container bounds on startup,
      // let's calculate the fit scale and initial offsets.
      final double fitScale = min(viewportWidth / processedImage.width, viewportHeight / processedImage.height);
      final double initialTx = (viewportWidth - processedImage.width * fitScale) / 2;
      final double initialTy = (viewportHeight - processedImage.height * fitScale) / 2;

      // Map screen crop coordinates back to original image pixels
      final double cropX1Pixel = (((screenX1 - tx) / scale) - initialTx) / fitScale;
      final double cropY1Pixel = (((screenY1 - ty) / scale) - initialTy) / fitScale;
      final double cropWidthPixel = (cropSize / scale) / fitScale;
      final double cropHeightPixel = (cropSize / scale) / fitScale;

      // Perform crop
      final cropped = img.copyCrop(
        processedImage,
        x: max(0, cropX1Pixel.round()),
        y: max(0, cropY1Pixel.round()),
        width: min(processedImage.width, cropWidthPixel.round()),
        height: min(processedImage.height, cropHeightPixel.round()),
      );

      final croppedBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 85));

      if (mounted) {
        navigator.pop(croppedBytes);
      }
    } catch (e) {
      debugPrint('[CROP ERROR] Failed to crop image: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
        );
        setState(() => _cropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final viewportWidth = mediaQuery.size.width;
    final viewportHeight = mediaQuery.size.height - 180;
    final cropSize = min(viewportWidth, viewportHeight) * 0.8;

    // Get rotated dimensions of the image
    int imgW = _decodedImage!.width;
    int imgH = _decodedImage!.height;
    if (_rotationAngle == 90 || _rotationAngle == 270) {
      imgW = _decodedImage!.height;
      imgH = _decodedImage!.width;
    }

    // Determine fit bounds
    final double fitScale = min(viewportWidth / imgW, viewportHeight / imgH);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Image viewer area
            Positioned.fill(
              bottom: 80,
              top: 60,
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: Center(
                        child: Container(
                          width: imgW * fitScale,
                          height: imgH * fitScale,
                          alignment: Alignment.center,
                          child: RotatedBox(
                            quarterTurns: _rotationAngle ~/ 90,
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.contain,
                              width: _decodedImage!.width * fitScale,
                              height: _decodedImage!.height * fitScale,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // WhatsApp Style Crop Mask overlay
            Positioned.fill(
              bottom: 80,
              top: 60,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CropMaskPainter(cropSize: cropSize, isCircle: true),
                ),
              ),
            ),

            // Top Header Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Crop Profile Photo',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.rotate_left, color: Colors.white),
                      onPressed: _rotateImage,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_cropping)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      ElevatedButton(
                        onPressed: _crop,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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
}

class CropMaskPainter extends CustomPainter {
  final double cropSize;
  final bool isCircle;

  CropMaskPainter({required this.cropSize, this.isCircle = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5);

    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cropSize,
      height: cropSize,
    );

    final innerPath = Path();
    if (isCircle) {
      innerPath.addOval(cropRect);
    } else {
      innerPath.addRect(cropRect);
    }

    final maskPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(maskPath, paint);

    // Draw WhatsApp style crop boundaries
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isCircle) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRect(cropRect, borderPaint);
    }

    // Grid lines inside the crop region
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final double step = cropSize / 3;
    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + step, cropRect.top),
      Offset(cropRect.left + step, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + step * 2, cropRect.top),
      Offset(cropRect.left + step * 2, cropRect.bottom),
      gridPaint,
    );
    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + step),
      Offset(cropRect.right, cropRect.top + step),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + step * 2),
      Offset(cropRect.right, cropRect.top + step * 2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
