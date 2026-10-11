import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants.dart';

class ProfileImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfileImageCropScreen({
    super.key,
    required this.imageBytes,
  });

  @override
  State<ProfileImageCropScreen> createState() => _ProfileImageCropScreenState();
}

class _ProfileImageCropScreenState extends State<ProfileImageCropScreen> {
  final _cropKey = GlobalKey();
  final _transformationController = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _saveCrop() async {
    setState(() => _saving = true);
    try {
      await precacheImage(MemoryImage(widget.imageBytes), context);
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _cropKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('The crop preview is not ready yet.');
      }

      final image = await renderObject.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) {
        throw StateError('The cropped image could not be prepared.');
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final side =
        (MediaQuery.sizeOf(context).width - 48).clamp(220.0, 320.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop profile photo'),
        backgroundColor: AppConstants.backgroundLight,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveCrop,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Use photo'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        key: _cropKey,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 1,
                            maxScale: 4,
                            boundaryMargin: EdgeInsets.zero,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: AppConstants.primaryLight,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppConstants.primary,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _CircularCropGuidePainter(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pinch to zoom and drag to frame your photo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppConstants.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularCropGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 2,
    );
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final outsideCircle = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(circle);
    canvas.drawPath(outsideCircle, shade);

    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(circle, outline);
  }

  @override
  bool shouldRepaint(covariant _CircularCropGuidePainter oldDelegate) => false;
}
