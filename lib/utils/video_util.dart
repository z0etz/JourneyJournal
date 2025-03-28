import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:flutter/rendering.dart';  // To use RenderRepaintBoundary
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'permissions_util.dart';  // Import PermissionsUtil

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

  // Step 1: Capture the frame dynamically as the animation progresses
  Future<void> _saveAnimation() async {
    setState(() {
      _isSaving = true;
    });

    // Step 2: Request storage permissions
    bool isPermitted = await PermissionsUtil.requestPermissions();
    if (!isPermitted) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Step 3: Initialize the video encoder with ProfileLevel
    final directory = await getExternalStorageDirectory();
    final filepath = '${directory?.path}/output_video.mp4';

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

    // Step 4: Listen to the animation's progress and capture frames
    int currentFrame = 0;
    widget.animationController.addListener(() async {
      if (widget.animationController.isAnimating) {
        await _captureFrame(currentFrame); // Await the capture process
        currentFrame++;;
      }
    });

    // Start the animation when the save button is pressed
    widget.animationController.forward();

    // Step 5: Finalize the video encoding when the animation is complete
    widget.animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Finish appending frames when the animation completes
        FlutterQuickVideoEncoder.finish();

        setState(() {
          _isSaving = false;
        });

        // Show video saved confirmation
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video saved at: $filepath')));
      }
    });
  }

  // Capture frame from the widget as RGBA data
  Future<void> _captureFrame(int frameIndex) async {
    try {
      print("Capturing frame: $frameIndex");

      // Capture the current circle position from the notifier
      LatLng currentPosition = widget.circlePositionNotifier.value;

      // Render the widget with the updated position
      RenderRepaintBoundary boundary = widget.key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) {
        print("Failed to capture frame: $frameIndex (ByteData is null)");
        return;
      }

      Uint8List rgbaFrame = byteData!.buffer.asUint8List();

      // Append the captured frame to the video encoder
      await FlutterQuickVideoEncoder.appendVideoFrame(rgbaFrame);

      print("Frame $frameIndex appended successfully");

    } catch (e) {
      print("Error capturing frame: $e");
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

