import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/map_utils.dart';

double calculateTotalDistance(RouteModel route) {
  double totalDistance = 0.0;
  for (int i = 0; i < route.routePoints.length - 1; i++) {
    totalDistance += Geolocator.distanceBetween(
      route.routePoints[i].point.latitude,
      route.routePoints[i].point.longitude,
      route.routePoints[i + 1].point.latitude,
      route.routePoints[i + 1].point.longitude,
    );
  }
  return totalDistance;
}

void moveCircleAlongPath(
    double progress,
    RouteModel route,
    ValueNotifier<LatLng> circlePositionNotifier,
    double totalDistance,
    ) {
  List<LatLng> path = route.routePoints.map((point) => point.point).toList();
  if (path.isEmpty) return;

  double distanceCovered = progress * totalDistance;
  double distanceSoFar = 0.0;
  int startIndex = 0;
  int endIndex = 1;

  for (int i = 0; i < path.length - 1; i++) {
    double segmentDistance = Geolocator.distanceBetween(
      path[i].latitude,
      path[i].longitude,
      path[i + 1].latitude,
      path[i + 1].longitude,
    );
    distanceSoFar += segmentDistance;

    if (distanceSoFar >= distanceCovered) {
      startIndex = i;
      endIndex = i + 1;
      break;
    }
  }

  LatLng startPoint = path[startIndex];
  LatLng endPoint = path[endIndex];
  double segmentDistance = Geolocator.distanceBetween(
    startPoint.latitude,
    startPoint.longitude,
    endPoint.latitude,
    endPoint.longitude,
  );
  double ratio = segmentDistance > 0
      ? (distanceCovered - (distanceSoFar - segmentDistance)) / segmentDistance
      : 0.0;
  double lat = startPoint.latitude + (endPoint.latitude - startPoint.latitude) * ratio;
  double lng = startPoint.longitude + (endPoint.longitude - startPoint.longitude) * ratio;

  circlePositionNotifier.value = LatLng(lat, lng);
}

class SaveButton extends StatefulWidget {
  final GlobalKey mapKey;
  final int frameCount;
  final AnimationController animationController;
  final ValueNotifier<LatLng> circlePositionNotifier;
  final String aspectRatio;
  final MapController mapController;
  final RouteModel currentRoute;
  final double initialZoom;
  final double fitZoom;
  final ValueNotifier<double> markerSizeNotifier;

  SaveButton({
    required this.mapKey,
    required this.frameCount,
    required this.animationController,
    required this.circlePositionNotifier,
    required this.aspectRatio,
    required this.mapController,
    required this.currentRoute,
    required this.initialZoom,
    required this.fitZoom,
    required this.markerSizeNotifier,
  }) {
    print("SaveButton received mapKey: $mapKey");
  }

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _isSaving = false;
  late double _totalDistance;

  @override
  void initState() {
    super.initState();
    _totalDistance = calculateTotalDistance(widget.currentRoute);
  }

  Size _getPixelDimensions() {
    switch (widget.aspectRatio) {
      case "9:16": return Size(576, 1024);
      case "16:9": return Size(1024, 576);
      case "3:2": return Size(768, 512);
      case "2:3": return Size(512, 768);
      case "1:1": return Size(512, 512);
      default: return Size(576, 1024);
    }
  }

  Future<Directory> _getTempFrameDir() async {
    final tempDir = Directory('/data/user/0/com.journeyjournal.journeyjournal/cache');
    final frameDir = Directory('${tempDir.path}/animation_frames');
    if (!await frameDir.exists()) {
      await frameDir.create();
    }
    return frameDir;
  }

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
      final pixelSize = _getPixelDimensions();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      Paint paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, pixelSize.width, pixelSize.height),
        paint,
      );
      final resizedImage = await recorder.endRecording().toImage(
        pixelSize.width.toInt(),
        pixelSize.height.toInt(),
      );

      ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        print("Failed to capture frame: $frameIndex (ByteData is null)");
        return '';
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      final frameDir = await _getTempFrameDir();
      final framePath = '${frameDir.path}/frame_$frameIndex.png';
      await File(framePath).writeAsBytes(pngBytes);

      print("Frame $frameIndex saved at: $framePath (size: ${pixelSize.width}x${pixelSize.height})");
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

  LatLng _interpolateCenter(LatLng start, LatLng end, double t) {
    double lat = start.latitude + (end.latitude - start.latitude) * t;
    double lng = start.longitude + (end.longitude - start.longitude) * t;
    return LatLng(lat, lng);
  }

  double _easeInQuad(double t) => t * t;
  double _easeOutQuad(double t) => t * (2 - t);
  double _easeOutBack(double t) {
    const double c = 10;
    const double b = 1.0;
    double s = t - 1;
    return 1 + c * math.pow(s, 3) + b * math.pow(s, 2);
  }

  Future<void> _saveAnimation() async {
    setState(() => _isSaving = true);

    int totalFrames = (widget.animationController.duration!.inSeconds * 30).round();
    List<String> framePaths = [];
    final bool routeFits = widget.initialZoom <= widget.fitZoom;
    const int zoomFrames = 30; // 1 second at 30fps
    final int followFrames = totalFrames - 2 * zoomFrames;
    LatLng? fittedCenter;
    final LatLng startPoint = widget.currentRoute.routePoints.first.point;
    final LatLng endPoint = widget.currentRoute.routePoints.last.point;
    final double fitZoom = widget.fitZoom;
    final double initialZoom = widget.initialZoom;
    const double markerBaseSize = 25.0;

    print("Initial Zoom: $initialZoom, Fit Zoom: $fitZoom, Route Fits: $routeFits");
    print("Total Frames: $totalFrames, Zoom Frames: $zoomFrames, Follow Frames: $followFrames");

    for (int frame = 0; frame < totalFrames; frame++) {
      double progress;
      if (frame < zoomFrames) {
        progress = 0.0; // Marker stays at start
      } else if (frame < zoomFrames + followFrames) {
        double followT = (frame - zoomFrames) / followFrames.toDouble();
        progress = followT.clamp(0.0, 1.0);
      } else {
        progress = 1.0; // Marker stays at end
      }

      widget.animationController.value = progress;
      moveCircleAlongPath(progress, widget.currentRoute, widget.circlePositionNotifier, _totalDistance);
      LatLng currentPoint = widget.circlePositionNotifier.value;

      // Marker animation
      if (frame < zoomFrames) {
        // Bounce in during Zoom In
        double t = frame / (zoomFrames - 1).toDouble();
        t = t.clamp(0.0, 1.0);
        double bounceT = _easeOutBack(t);
        widget.markerSizeNotifier.value = markerBaseSize * bounceT; // 0 -> ~48 -> 40
      } else if (frame < zoomFrames + followFrames) {
        // Steady size during Follow
        widget.markerSizeNotifier.value = markerBaseSize;
      } else {
        // Bounce out during Zoom Out
        double t = (frame - (zoomFrames + followFrames)) / (zoomFrames - 1).toDouble();
        t = t.clamp(0.0, 1.0);
        double bounceT = _easeOutBack(1 - t); // Reverse: 40 -> ~48 -> 0
        widget.markerSizeNotifier.value = markerBaseSize * bounceT;
      }

      if (routeFits) {
        print("Frame $frame (Static): Zoom $initialZoom, Center ${widget.mapController.camera.center}");
      } else {
        if (frame == 0) {
          fitMapToRoute(widget.mapController, widget.currentRoute.routePoints.map((rp) => rp.point).toList(),
              isAnimationScreen: true);
          await Future.delayed(Duration(milliseconds: 100));
          fittedCenter = widget.mapController.camera.center;
        }

        if (frame < zoomFrames) {
          double t = frame / (zoomFrames - 1).toDouble();
          t = t.clamp(0.0, 1.0);
          double zoomT = _easeInQuad(t);
          double panT = _easeOutQuad(t);
          double zoom = fitZoom + (initialZoom - fitZoom) * zoomT;
          LatLng center = _interpolateCenter(fittedCenter!, startPoint, panT);
          widget.mapController.move(center, zoom);
          print("Frame $frame (Zoom In): Zoom $zoom, Center $center, t: $t, Zoom t: $zoomT, Pan t: $panT, Marker Size: ${widget.markerSizeNotifier.value}");
        } else if (frame < zoomFrames + followFrames) {
          widget.mapController.move(currentPoint, initialZoom);
          print("Frame $frame (Follow): Zoom $initialZoom, Center $currentPoint, Progress: $progress");
        } else {
          double t = (frame - (zoomFrames + followFrames)) / (zoomFrames - 1).toDouble();
          t = t.clamp(0.0, 1.0);
          double zoomT = _easeOutQuad(t);
          double panT = t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
          double zoom = initialZoom - (initialZoom - fitZoom) * zoomT;
          LatLng center = _interpolateCenter(endPoint, fittedCenter!, panT);
          widget.mapController.move(center, zoom);
          print("Frame $frame (Zoom Out): Zoom $zoom, Center $center, t: $t, Zoom t: $zoomT, Pan t: $panT, Marker Size: ${widget.markerSizeNotifier.value}");
        }
      }

      await Future.delayed(Duration(milliseconds: (1000 / 30).round()));
      String framePath = await _captureFrame(frame);
      if (framePath.isNotEmpty) {
        framePaths.add(framePath);
      }
    }

    if (framePaths.isNotEmpty) {
      final dcimDir = Directory('/storage/emulated/0/DCIM/JourneyJournal');
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }
      final videoPath = '${dcimDir.path}/output_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final pixelSize = _getPixelDimensions();

      await FlutterQuickVideoEncoder.setup(
        width: pixelSize.width.toInt(),
        height: pixelSize.height.toInt(),
        fps: 30,
        videoBitrate: 8000000,
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

      final frameDir = await _getTempFrameDir();
      await frameDir.delete(recursive: true);
      print("Temporary frames deleted");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video saved at: $videoPath')),
      );
    }

    setState(() => _isSaving = false);
    print("Captured and encoded ${framePaths.length} frames");
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveAnimation,
      child: _isSaving ? CircularProgressIndicator() : Text("Save Animation"),
    );
  }
}