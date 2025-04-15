import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/map_utils.dart';

double calculateTotalDistance(RouteModel route, {int startIndex = 0, int endIndex = -1}) {
  if (route.routePoints.isEmpty) return 0.0;
  int effectiveEndIndex = endIndex == -1 ? route.routePoints.length - 1 : endIndex;
  effectiveEndIndex = effectiveEndIndex.clamp(startIndex, route.routePoints.length - 1);
  if (effectiveEndIndex <= startIndex) return 0.0;
  double totalDistance = 0.0;
  for (int i = startIndex; i < effectiveEndIndex; i++) {
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
    double totalDistance, {
      int startIndex = 0,
      int endIndex = -1,
    }) {
  if (route.routePoints.isEmpty) return;

  int effectiveEndIndex = endIndex == -1 ? route.routePoints.length - 1 : endIndex;
  effectiveEndIndex = effectiveEndIndex.clamp(startIndex, route.routePoints.length - 1);

  List<LatLng> path = route.routePoints
      .sublist(startIndex, effectiveEndIndex + 1)
      .map((point) => point.point)
      .toList();

  if (path.isEmpty) return;

  if (progress <= 0.0) {
    circlePositionNotifier.value = path.first;
    return;
  } else if (progress >= 1.0) {
    circlePositionNotifier.value = path.last;
    return;
  }

  double distanceCovered = progress * totalDistance;
  double distanceSoFar = 0.0;

  for (int i = 0; i < path.length - 1; i++) {
    double segmentDistance = Geolocator.distanceBetween(
      path[i].latitude,
      path[i].longitude,
      path[i + 1].latitude,
      path[i + 1].longitude,
    );
    if (distanceSoFar + segmentDistance >= distanceCovered) {
      double remainingDistance = distanceCovered - distanceSoFar;
      double ratio = segmentDistance > 0 ? remainingDistance / segmentDistance : 0.0;
      double lat = path[i].latitude + (path[i + 1].latitude - path[i].latitude) * ratio;
      double lng = path[i].longitude + (path[i + 1].longitude - path[i].longitude) * ratio;
      circlePositionNotifier.value = LatLng(lat, lng);
      return;
    }
    distanceSoFar += segmentDistance;
  }
  circlePositionNotifier.value = path.last;
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
  final ValueNotifier<double> directionNotifier;
  final ValueNotifier<double> saveDirectionNotifier;
  final bool showWholeRoute;
  final VoidCallback? onSaveStart;
  final VoidCallback? onSaveComplete;
  final ValueNotifier<bool> isSavingNotifier;

  const SaveButton({
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
    required this.directionNotifier,
    required this.saveDirectionNotifier,
    required this.showWholeRoute,
    required this.onSaveStart,
    required this.onSaveComplete,
    required this.isSavingNotifier,
    super.key,
  });

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  late double _totalDistance;

  @override
  void initState() {
    super.initState();
    _totalDistance = calculateTotalDistance(
      widget.currentRoute,
      startIndex: widget.currentRoute.startIndex,
      endIndex: widget.currentRoute.endIndex,
    );
  }

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

  Future<Directory> _getTempFrameDir() async {
    final tempDir = Directory('/data/user/0/com.journeyjournal.journeyjournal/cache');
    final frameDir = Directory('${tempDir.path}/animation_frames');
    if (!await frameDir.exists()) {
      await frameDir.create();
    }
    return frameDir;
  }

  Future<String> _captureFrame(int frameIndex) async {
    final BuildContext? context = widget.mapKey.currentContext;
    if (context == null) return '';

    RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) return '';
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
    if (byteData == null) return '';

    Uint8List pngBytes = byteData.buffer.asUint8List();
    final frameDir = await _getTempFrameDir();
    final framePath = '${frameDir.path}/frame_$frameIndex.png';
    await File(framePath).writeAsBytes(pngBytes);
    return framePath;
  }

  Future<void> _encodeFrame(String framePath) async {
    ui.Image image = await decodeImageFromList(await File(framePath).readAsBytes());
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;
    Uint8List rgbaBytes = byteData.buffer.asUint8List();
    await FlutterQuickVideoEncoder.appendVideoFrame(rgbaBytes);
  }

  LatLng _interpolateCenter(LatLng start, LatLng end, double t) {
    double lat = start.latitude + (end.latitude - start.latitude) * t;
    double lng = start.longitude + (end.longitude - start.longitude) * t;
    return LatLng(lat, lng);
  }

  double _easeInQuad(double t) => t * t;

  double _easeOutQuad(double t) => t * (2 - t);

  double _easeOutBack(double t) {
    const double c = 5;
    double s = t - 1;
    double bounce = c * s * s * (s + 1);
    return 0.1 + 0.9 * t + bounce;
  }

  Future<void> _saveAnimation() async {
    if (widget.isSavingNotifier.value || widget.currentRoute.routePoints.isEmpty) return;

    widget.onSaveStart?.call();

    // Fit map based on showWholeRoute
    if (widget.currentRoute.routePoints.isNotEmpty) {
      final points = widget.currentRoute.routePoints.map((rp) => rp.point).toList();
      fitMapToRoute(
        widget.mapController,
        points,
        isAnimationScreen: true,
        startIndex: widget.showWholeRoute ? null : widget.currentRoute.startIndex,
        endIndex: widget.showWholeRoute ? null : widget.currentRoute.endIndex,
      );
    }

    int totalFrames = (widget.animationController.duration!.inSeconds * 30).round();
    List<String> framePaths = [];
    final bool routeFits = widget.initialZoom <= widget.fitZoom;
    const int zoomFrames = 30;
    final int followFrames = totalFrames - 2 * zoomFrames;
    LatLng? fittedCenter;
    final LatLng startPoint = widget.currentRoute.routePoints[widget.currentRoute.startIndex].point;
    final LatLng endPoint = widget.currentRoute.routePoints[widget.currentRoute.endIndex].point;
    final double fitZoom = widget.fitZoom;
    final double initialZoom = widget.initialZoom;
    const double markerBaseSize = 25.0;

    double initialDirection = widget.currentRoute.startIndex < widget.currentRoute.endIndex &&
        widget.currentRoute.startIndex + 1 < widget.currentRoute.routePoints.length
        ? atan2(
      widget.currentRoute.routePoints[widget.currentRoute.startIndex + 1].point.longitude -
          startPoint.longitude,
      widget.currentRoute.routePoints[widget.currentRoute.startIndex + 1].point.latitude -
          startPoint.latitude,
    )
        : 0.0;
    double finalDirection = widget.currentRoute.endIndex > widget.currentRoute.startIndex
        ? atan2(
      endPoint.longitude -
          widget.currentRoute.routePoints[widget.currentRoute.endIndex - 1].point.longitude,
      endPoint.latitude -
          widget.currentRoute.routePoints[widget.currentRoute.endIndex - 1].point.latitude,
    )
        : 0.0;

    widget.markerSizeNotifier.value = 0.0;
    widget.saveDirectionNotifier.value = initialDirection;
    widget.circlePositionNotifier.value = startPoint;
    widget.animationController.reset();
    widget.markerSizeNotifier.value = markerBaseSize * _easeOutBack(0.0);

    LatLng? lastPosition;

    for (int frame = 0; frame < totalFrames; frame++) {
      if (!widget.isSavingNotifier.value) {
        final frameDir = await _getTempFrameDir();
        if (await frameDir.exists()) await frameDir.delete(recursive: true);
        widget.onSaveComplete?.call();
        return;
      }

      double progress;
      if (frame < zoomFrames) {
        progress = 0.0;
        widget.saveDirectionNotifier.value = initialDirection;
      } else if (frame < zoomFrames + followFrames) {
        double followT = (frame - zoomFrames) / followFrames.toDouble();
        progress = followT.clamp(0.0, 1.0);
      } else {
        progress = 1.0;
        widget.saveDirectionNotifier.value = finalDirection;
      }

      widget.animationController.value = progress;
      moveCircleAlongPath(
        progress,
        widget.currentRoute,
        widget.circlePositionNotifier,
        _totalDistance,
        startIndex: widget.currentRoute.startIndex,
        endIndex: widget.currentRoute.endIndex,
      );
      LatLng currentPoint = widget.circlePositionNotifier.value;

      if (frame >= zoomFrames && frame < zoomFrames + followFrames && lastPosition != null) {
        double deltaLat = currentPoint.latitude - lastPosition.latitude;
        double deltaLng = currentPoint.longitude - lastPosition.longitude;
        double distanceMoved = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          currentPoint.latitude,
          currentPoint.longitude,
        );
        if (distanceMoved > 1.0) {
          widget.saveDirectionNotifier.value = atan2(deltaLng, deltaLat);
        }
      }
      lastPosition = currentPoint;

      if (frame < zoomFrames) {
        double t = frame / (zoomFrames - 1).toDouble();
        widget.markerSizeNotifier.value = markerBaseSize * _easeOutBack(t.clamp(0.0, 1.0));
      } else if (frame < zoomFrames + followFrames) {
        widget.markerSizeNotifier.value = markerBaseSize;
      } else {
        double t = (frame - (zoomFrames + followFrames)) / (zoomFrames - 1).toDouble();
        widget.markerSizeNotifier.value = markerBaseSize * _easeOutBack(1 - t.clamp(0.0, 1.0));
      }

      if (!routeFits) {
        if (frame == 0) {
          fitMapToRoute(
            widget.mapController,
            widget.currentRoute.routePoints.map((rp) => rp.point).toList(),
            isAnimationScreen: true,
            startIndex: widget.showWholeRoute ? null : widget.currentRoute.startIndex,
            endIndex: widget.showWholeRoute ? null : widget.currentRoute.endIndex,
          );
          fittedCenter = widget.mapController.camera.center;
        }

        if (frame < zoomFrames) {
          double t = frame / (zoomFrames - 1).toDouble();
          double zoomT = _easeInQuad(t.clamp(0.0, 1.0));
          double panT = _easeOutQuad(t.clamp(0.0, 1.0));
          double zoom = fitZoom + (initialZoom - fitZoom) * zoomT;
          LatLng center = _interpolateCenter(fittedCenter!, startPoint, panT);
          widget.mapController.move(center, zoom);
        } else if (frame < zoomFrames + followFrames) {
          widget.mapController.move(currentPoint, initialZoom);
        } else {
          double t = (frame - (zoomFrames + followFrames)) / (zoomFrames - 1).toDouble();
          double zoomT = _easeOutQuad(t.clamp(0.0, 1.0));
          double panT = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
          double zoom = initialZoom - (initialZoom - fitZoom) * zoomT;
          LatLng center = _interpolateCenter(endPoint, fittedCenter!, panT);
          widget.mapController.move(center, zoom);
        }
      }

      await Future.delayed(const Duration(milliseconds: 33));
      String framePath = await _captureFrame(frame);
      if (framePath.isNotEmpty) framePaths.add(framePath);
    }

    if (framePaths.isNotEmpty) {
      final dcimDir = Directory('/storage/emulated/0/DCIM/JourneyJournal');
      if (!await dcimDir.exists()) await dcimDir.create(recursive: true);
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
        if (!widget.isSavingNotifier.value) {
          await FlutterQuickVideoEncoder.finish();
          widget.onSaveComplete?.call();
          final frameDir = await _getTempFrameDir();
          if (await frameDir.exists()) await frameDir.delete(recursive: true);
          return;
        }
        await _encodeFrame(framePath);
      }

      await FlutterQuickVideoEncoder.finish();

      final frameDir = await _getTempFrameDir();
      await frameDir.delete(recursive: true);

      widget.onSaveComplete?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved at: $videoPath')),
        );
      }
    } else {
      widget.onSaveComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isSavingNotifier,
      builder: (context, isSaving, child) {
        return ElevatedButton(
          onPressed: isSaving || widget.currentRoute.routePoints.isEmpty ? null : _saveAnimation,
          child: isSaving
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          )
              : const Text("Save Animation"),
        );
      },
    );
  }
}