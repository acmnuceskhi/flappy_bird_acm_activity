import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Dialog for editing/cropping character images to fit in a circle
class ImageEditorDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  const ImageEditorDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  @override
  State<ImageEditorDialog> createState() => _ImageEditorDialogState();
}

class _ImageEditorDialogState extends State<ImageEditorDialog> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjust Character Image',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The image will be fitted into a circle. Adjust the scale and position to frame your character properly.',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),

            // Preview Area
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 400,
                      maxHeight: 400,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      border: Border.all(color: Colors.red.shade800, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Checkerboard background to show transparency
                          CustomPaint(painter: CheckerboardPainter()),
                          // Image with proper transformation matching the processing
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final size = constraints.maxWidth; // 400px

                              // Apply scale from center, then translate
                              return Transform(
                                transform: Matrix4.identity()
                                  ..translate(size / 2, size / 2)
                                  ..scale(_scale)
                                  ..translate(
                                    -size / 2 + _offset.dx,
                                    -size / 2 + _offset.dy,
                                  ),
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.cover,
                                  width: size,
                                  height: size,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scale Control
            Row(
              children: [
                Icon(Icons.zoom_out, color: Colors.grey[400]),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 0.5,
                    max: 3.0,
                    divisions: 50,
                    activeColor: Colors.redAccent.shade200,
                    inactiveColor: Colors.grey[700],
                    onChanged: (value) {
                      setState(() {
                        _scale = value;
                      });
                    },
                  ),
                ),
                Icon(Icons.zoom_in, color: Colors.grey[400]),
                const SizedBox(width: 16),
                Text(
                  '${(_scale * 100).toInt()}%',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Position Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Position: ', style: TextStyle(color: Colors.grey[300])),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  color: Colors.grey[400],
                  onPressed: () {
                    setState(() {
                      _offset = Offset(_offset.dx, _offset.dy + 10);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  color: Colors.grey[400],
                  onPressed: () {
                    setState(() {
                      _offset = Offset(_offset.dx, _offset.dy - 10);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.grey[400],
                  onPressed: () {
                    setState(() {
                      _offset = Offset(_offset.dx + 10, _offset.dy);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  color: Colors.grey[400],
                  onPressed: () {
                    setState(() {
                      _offset = Offset(_offset.dx - 10, _offset.dy);
                    });
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _scale = 1.0;
                      _offset = Offset.zero;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _processAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Use This Image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processAndSave() async {
    setState(() => _isProcessing = true);

    try {
      debugPrint('=== Image Processing Debug ===');
      debugPrint('Scale: $_scale');
      debugPrint('Offset: $_offset');

      // Decode the image
      final image = img.decodeImage(widget.imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      debugPrint('Original image size: ${image.width}x${image.height}');

      // Target size for the output (make it large enough for quality)
      const targetSize = 512;

      // Create a square canvas
      final canvas = img.Image(width: targetSize, height: targetSize);

      // Fill with transparent background
      img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

      // Calculate how the image should be sized to cover the target area
      final imageAspect = image.width / image.height;
      double baseWidth, baseHeight;

      if (imageAspect > 1.0) {
        // Wider than tall - scale to height
        baseHeight = targetSize.toDouble();
        baseWidth = baseHeight * imageAspect;
      } else {
        // Taller than wide - scale to width
        baseWidth = targetSize.toDouble();
        baseHeight = baseWidth / imageAspect;
      }

      debugPrint('Base size (to cover): ${baseWidth}x$baseHeight');

      // Apply user's scale directly to the base size
      final scaledWidth = (baseWidth * _scale).toInt();
      final scaledHeight = (baseHeight * _scale).toInt();

      debugPrint('Scaled size: ${scaledWidth}x$scaledHeight');

      // Resize image to the scaled dimensions
      final resized = img.copyResize(
        image,
        width: scaledWidth,
        height: scaledHeight,
        interpolation: img.Interpolation.linear,
      );

      debugPrint('Resized image size: ${resized.width}x${resized.height}');

      // Calculate position: center the scaled image, then apply offset
      final x = ((targetSize - scaledWidth) / 2 + _offset.dx).toInt();
      final y = ((targetSize - scaledHeight) / 2 + _offset.dy).toInt();

      debugPrint('Position: ($x, $y)');

      // Composite the image at the calculated position
      // Parts outside the canvas are automatically clipped
      img.compositeImage(canvas, resized, dstX: x, dstY: y);

      debugPrint('=============================');

      // Encode back to PNG
      final processedBytes = img.encodePng(canvas);

      if (!mounted) return;

      // Return the processed image
      Navigator.pop(context, Uint8List.fromList(processedBytes));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing image: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }
}

/// Paints a checkerboard pattern to show transparency
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 20.0;
    final paint1 = Paint()..color = Colors.grey[800]!;
    final paint2 = Paint()..color = Colors.grey[700]!;

    for (int i = 0; i < (size.width / squareSize).ceil(); i++) {
      for (int j = 0; j < (size.height / squareSize).ceil(); j++) {
        final paint = (i + j) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(i * squareSize, j * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
