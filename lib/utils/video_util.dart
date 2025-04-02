import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';  // To use RenderRepaintBoundary
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class SaveButton extends StatefulWidget {
  final GlobalKey mapKey;
  final int frameCount; // Total number of frames in the animation
  final AnimationController animationController;
  final ValueNotifier<LatLng> circlePositionNotifier;
  final String aspectRatio;

  SaveButton({
    required this.mapKey,
    required this.frameCount,
    required this.animationController,
    required this.circlePositionNotifier,
    required this.aspectRatio,
  }){
    print("SaveButton received repaintBoundaryKey: $mapKey");
  }

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _isSaving = false;

  Size _getPixelDimensions() {
    switch (widget.aspectRatio) {
      case "9:16":
        return Size(576, 1024);
      case "16:9":
        return Size(1024, 576);
      case "3:2":
        return Size(768, 512);
      case "2:3":
        return Size(512, 768);
      case "1:1":
        return Size(512, 512);
      default:
        return Size(576, 1024);
    }
  }

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

      final BuildContext? context = widget.mapKey.currentContext;
      if (context == null) {
        print("No context available for frame: $frameIndex (mapKey not mounted)");
        return '';
      }

      RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null) {
        print("No render object found for frame: $frameIndex");
        return '';
      }

      if (renderObject is! RenderRepaintBoundary) {
        print("Render object is not a RepaintBoundary: ${renderObject.runtimeType}");
        return '';
      }
      RenderRepaintBoundary boundary = renderObject;

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

  Future<void> _encodeFrame(String framePath) async {
    try {
      ui.Image image = await decodeImageFromList(await File(framePath).readAsBytes());
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        print("Failed to convert frame to RGBA: $framePath");
        return;
      }
      Uint8List rgbaBytes = byteData.buffer.asUint8List();
      await FlutterQuickVideoEncoder.appendVideoFrame(rgbaBytes);
      print("Frame $framePath appended to video");
    } catch (e) {
      print("Error encoding frame $framePath: $e");
    }
  }

  Future<void> _saveAnimation() async {
    setState(() => _isSaving = true);

    int totalFrames = (widget.animationController.duration!.inSeconds * 30).round();
    List<String> framePaths = [];

    // Step 1: Capture all frames as PNGs
    for (int frame = 0; frame < totalFrames; frame++) {
      double progress = frame / totalFrames;
      widget.animationController.value = progress;
      await Future.delayed(Duration(milliseconds: (1000 / 30).round()));
      String framePath = await _captureFrame(frame);
      if (framePath.isNotEmpty) {
        framePaths.add(framePath);
      }
    }

    // Step 2: Encode frames into video
    if (framePaths.isNotEmpty) {
      final directory = await getExternalStorageDirectory();
      final videoPath = '${directory?.path}/output_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Get frame size from the first frame
      ui.Image firstFrame = await decodeImageFromList(await File(framePaths.first).readAsBytes());
      await FlutterQuickVideoEncoder.setup(
        width: firstFrame.width,
        height: firstFrame.height,
        fps: 30,
        videoBitrate: 2500000,
        audioChannels: 0,
        audioBitrate: 0,
        sampleRate: 0,
        profileLevel: ProfileLevel.high40,
        filepath: videoPath,
      );

      for (String framePath in framePaths) {
        await _encodeFrame(framePath);
      }

      await FlutterQuickVideoEncoder.finish();
      print("Video saved at: $videoPath");

      // Step 3: Clean up temporary frames
      final frameDir = await _getTempFrameDir();
      await frameDir.delete(recursive: true);
      print("Temporary frames deleted");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video saved at: $videoPath')),
      );
    } else {
      print("No frames captured, video not saved");
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

