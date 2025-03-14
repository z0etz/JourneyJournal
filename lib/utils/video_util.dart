import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:flutter/rendering.dart';  // To use RenderRepaintBoundary
import 'package:journeyjournal/utils/permissions_util.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

    // Step 1: Request storage permissions
    bool isPermitted = await PermissionsUtil.requestPermissions();
    if (!isPermitted) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Step 2: Initialize the video encoder with ProfileLevel
    final directory = await getApplicationDocumentsDirectory();
    final filepath = '${directory.path}/output_video.mp4';

    await FlutterQuickVideoEncoder.setup(
      width: 1920,
      height: 1080,
      fps: 30,
      videoBitrate: 2500000,
      audioChannels: 1,
      audioBitrate: 64000,
      sampleRate: 44100,
      profileLevel: ProfileLevel.high40, // Using high40 profile level
      filepath: filepath, // Output file location
    );

    try {
      // Step 3: Capture and append frames to video
      for (int i = 0; i < widget.frameCount; i++) {
        // Capture a frame as RGBA bytes
        Uint8List rgbaFrame = await _captureFrame(i);
        await FlutterQuickVideoEncoder.appendVideoFrame(rgbaFrame);

        // Optionally append audio frame if needed
        // Uint8List audioFrame = await _generateAudioFrame(i);
        // await FlutterQuickVideoEncoder.appendAudioFrame(audioFrame);
      }

      // Step 4: Finalize the video encoding
      await FlutterQuickVideoEncoder.finish();

      setState(() {
        _isSaving = false;
      });

      // Show video saved confirmation
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video saved at: $filepath')));
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Capture frame from the widget as RGBA data
  Future<Uint8List> _captureFrame(int frameIndex) async {
    try {
      RenderRepaintBoundary boundary =
      widget.key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print("Error capturing frame: $e");
      return Uint8List(0); // Return an empty byte array on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveAnimation,
      child: _isSaving ? CircularProgressIndicator() : Text("Save Animation"),
    );
  }
}
