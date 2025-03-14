import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:flutter/rendering.dart'; // Ensure this is imported!

class SaveButton extends StatefulWidget {
  final GlobalKey key;
  final int frameCount;  // Total number of frames in the animation

  SaveButton({required this.key, required this.frameCount});

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _isSaving = false;

  Future<void> _saveAnimation() async {
    setState(() {
      _isSaving = true;
    });

    // Step 1: Initialize the video encoder with ProfileLevel
    await FlutterQuickVideoEncoder.setup(
      width: 1920,
      height: 1080,
      fps: 30,
      videoBitrate: 2500000,
      audioChannels: 1,
      audioBitrate: 64000,
      sampleRate: 44100,
      profileLevel: ProfileLevel.high40, // Correct usage of ProfileLevel enum
      filepath: '/documents/video.mp4', // Specify output path here
    );

    try {
      // Step 2: Capture and append frames to video
      for (int i = 0; i < widget.frameCount; i++) {
        // Capture a frame as RGBA bytes
        Uint8List rgbaFrame = await _captureFrame(i);
        await FlutterQuickVideoEncoder.appendVideoFrame(rgbaFrame);

        // Optionally append audio frame (if required)
        // Uint8List audioFrame = await _generateAudioFrame(i);
        // await FlutterQuickVideoEncoder.appendAudioFrame(audioFrame);
      }

      // Step 3: Finalize the video encoding
      await FlutterQuickVideoEncoder.finish();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video saved!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Capture frame from the widget as RGBA data
  Future<Uint8List> _captureFrame(int frameIndex) async {
    // Here, you could animate or change the widget for each frame
    RenderRepaintBoundary boundary =
    widget.key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveAnimation,
      child: _isSaving ? CircularProgressIndicator() : Text("Save Animation"),
    );
  }
}
