import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';  // To use RenderRepaintBoundary
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class SaveButton extends StatefulWidget {
  final GlobalKey key;
  final int frameCount; // Total number of frames in the animation
  final AnimationController animationController;
  final ValueNotifier<LatLng> circlePositionNotifier;

  SaveButton({
    required this.key,
    required this.frameCount,
    required this.animationController,
    required this.circlePositionNotifier,
  });

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _isSaving = false;

  // Directory to store temporary frames
  Future<Directory> _getTempFrameDir() async {
    final tempDir = await getTemporaryDirectory();
    final frameDir = Directory('${tempDir.path}/animation_frames');
    if (!await frameDir.exists()) {
      await frameDir.create();
    }
    return frameDir;
  }

  // Capture and save a frame as PNG
  Future<String> _captureFrame(int frameIndex) async {
    try {
      print("Capturing frame: $frameIndex");
      RenderRepaintBoundary boundary = widget.key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png); // Save as PNG

      if (byteData == null) {
        print("Failed to capture frame: $frameIndex (ByteData is null)");
        return '';
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      final frameDir = await _getTempFrameDir();
      final framePath = '${frameDir.path}/frame_$frameIndex.png';
      await File(framePath).writeAsBytes(pngBytes);

      print("Frame $frameIndex saved at: $framePath");
      return framePath;
    } catch (e) {
      print("Error capturing frame: $e");
      return '';
    }
  }

  Future<void> _saveAnimation() async {
    setState(() => _isSaving = true);

    int totalFrames = (widget.animationController.duration!.inSeconds * 30).round();
    List<String> framePaths = [];

    // Capture all frames
    for (int frame = 0; frame < totalFrames; frame++) {
      double progress = frame / totalFrames;
      widget.animationController.value = progress;
      await Future.delayed(Duration(milliseconds: (1000 / 30).round()));
      String framePath = await _captureFrame(frame);
      if (framePath.isNotEmpty) {
        framePaths.add(framePath);
      }
    }

    setState(() => _isSaving = false);
    print("Captured ${framePaths.length} frames");
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveAnimation,
      child: _isSaving ? CircularProgressIndicator() : Text("Save Animation"),
    );
  }
}

