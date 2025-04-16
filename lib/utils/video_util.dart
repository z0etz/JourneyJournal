import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/models/image_data.dart';

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

double calculateDirection(LatLng? lastPosition, LatLng currentPosition, {double defaultDirection = 0.0}) {
  if (lastPosition == null) return defaultDirection;
  double deltaLat = currentPosition.latitude - lastPosition.latitude;
  double deltaLng = currentPosition.longitude - lastPosition.longitude;
  double distanceMoved = Geolocator.distanceBetween(
    lastPosition.latitude,
    lastPosition.longitude,
    currentPosition.latitude,
    currentPosition.longitude,
  );
  return distanceMoved > 1.0 ? atan2(deltaLng, deltaLat) : defaultDirection;
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
  final ValueNotifier<double> saveDirectionNotifier;
  final bool showWholeRoute;
  final VoidCallback? onSaveStart;
  final VoidCallback? onSaveComplete;
  final ValueNotifier<bool> isSavingNotifier;
  final Future<void> Function(double progress, LatLng currentPoint) updateFrame;
  final Duration totalDuration;
  final List<RoutePoint> imagePoints;
  final Function(bool) isImageDisplayed;
  final Function(List<ImageData>) setCurrentImages;
  final Function(int) setCurrentImageIndex;
  final Function(int) setNextImageIndex;
  final Function(double) setImageDisplayProgress;
  final ValueNotifier<double> currentImageOpacity;
  final ValueNotifier<double> currentImageScale;
  final ValueNotifier<double> nextImageOpacity;
  final ValueNotifier<double> nextImageScale;
  final VoidCallback? cancelSaving;

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
    required this.saveDirectionNotifier,
    required this.showWholeRoute,
    required this.onSaveStart,
    required this.onSaveComplete,
    required this.isSavingNotifier,
    required this.updateFrame,
    required this.totalDuration,
    required this.imagePoints,
    required this.isImageDisplayed,
    required this.setCurrentImages,
    required this.setCurrentImageIndex,
    required this.setNextImageIndex,
    required this.setImageDisplayProgress,
    required this.currentImageOpacity,
    required this.currentImageScale,
    required this.nextImageOpacity,
    required this.nextImageScale,
    this.cancelSaving,
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
    print('Captured frame $frameIndex: $framePath');
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

  Future<void> _cleanup() async {
    await FlutterQuickVideoEncoder.finish();
    final frameDir = await _getTempFrameDir();
    if (await frameDir.exists()) await frameDir.delete(recursive: true);
    widget.onSaveComplete?.call();
  }

  Future<void> _saveAnimation() async {
    if (widget.isSavingNotifier.value || widget.currentRoute.routePoints.isEmpty) return;

    widget.onSaveStart?.call();

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

    int totalFrames = (widget.totalDuration.inSeconds * 30).round();
    List<String> framePaths = [];
    final bool routeFits = widget.initialZoom <= widget.fitZoom;
    const int zoomFrames = 30;
    final int followFrames = (widget.animationController.duration!.inSeconds * 30).round();
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
    widget.isImageDisplayed(false);
    widget.setCurrentImages([]);
    widget.setCurrentImageIndex(0);
    widget.setNextImageIndex(-1);
    widget.setImageDisplayProgress(0.0);
    widget.currentImageOpacity.value = 0.0;
    widget.currentImageScale.value = 0.0;
    widget.nextImageOpacity.value = 0.0;
    widget.nextImageScale.value = 0.0;

    LatLng? lastPosition;
    double animationProgress = 0.0;
    int currentImagePointIndex = 0;
    bool isPaused = false;
    int pauseFrameCount = 0;
    int movementFrameCount = 0;
    List<ImageData> currentImages = [];
    int currentImageIndex = 0;
    int nextImageIndex = -1;
    double imageDisplayProgress = 0.0;
    bool isLastImageFading = false;

    for (int frame = 0; frame < totalFrames; frame++) {
      if (!widget.isSavingNotifier.value || !mounted) {
        await _cleanup();
        return;
      }

      if (frame < zoomFrames) {
        animationProgress = 0.0;
        widget.saveDirectionNotifier.value = initialDirection;
        widget.markerSizeNotifier.value = markerBaseSize * _easeOutBack(frame / (zoomFrames - 1));
      } else if (frame < totalFrames - zoomFrames) {
        if (!isPaused) {
          if (currentImagePointIndex < widget.imagePoints.length) {
            final point = widget.imagePoints[currentImagePointIndex];
            double segmentProgress = animationProgress * _totalDistance;
            double distanceSoFar = 0.0;
            for (int i = widget.currentRoute.startIndex; i < widget.currentRoute.endIndex; i++) {
              distanceSoFar += Geolocator.distanceBetween(
                widget.currentRoute.routePoints[i].point.latitude,
                widget.currentRoute.routePoints[i].point.longitude,
                widget.currentRoute.routePoints[i + 1].point.latitude,
                widget.currentRoute.routePoints[i + 1].point.longitude,
              );
              if (distanceSoFar >= segmentProgress &&
                  i == widget.currentRoute.startIndex + currentImagePointIndex) {
                isPaused = true;
                pauseFrameCount = 0;
                currentImages = point.images;
                currentImageIndex = 0;
                nextImageIndex = -1;
                isLastImageFading = false;
                imageDisplayProgress = 0.0;
                widget.isImageDisplayed(true);
                widget.setCurrentImages(currentImages);
                widget.setCurrentImageIndex(currentImageIndex);
                widget.setNextImageIndex(nextImageIndex);
                widget.setImageDisplayProgress(imageDisplayProgress);
                widget.circlePositionNotifier.value = point.point;
                break;
              }
            }
          }
          if (!isPaused && movementFrameCount < followFrames) {
            animationProgress = movementFrameCount / followFrames.toDouble();
            movementFrameCount++;
            widget.animationController.value = animationProgress;
            moveCircleAlongPath(
              animationProgress,
              widget.currentRoute,
              widget.circlePositionNotifier,
              _totalDistance,
              startIndex: widget.currentRoute.startIndex,
              endIndex: widget.currentRoute.endIndex,
            );
            await widget.updateFrame(animationProgress, widget.circlePositionNotifier.value);
          }
        }
        if (isPaused) {
          pauseFrameCount++;
          imageDisplayProgress = pauseFrameCount / 30.0;
          widget.setImageDisplayProgress(imageDisplayProgress);

          if (imageDisplayProgress <= 1.0) {
            widget.currentImageOpacity.value = imageDisplayProgress;
            widget.currentImageScale.value = imageDisplayProgress;
          } else if (imageDisplayProgress <= 3.0) {
            widget.currentImageOpacity.value = 1.0;
            widget.currentImageScale.value = 1.0;
          } else if (imageDisplayProgress <= 4.0) {
            widget.currentImageOpacity.value = 1.0 - (imageDisplayProgress - 3.0);
            widget.currentImageScale.value = 1.0 - (imageDisplayProgress - 3.0);
            isLastImageFading = currentImageIndex == currentImages.length - 1;
          }

          if (imageDisplayProgress >= 3.0 && nextImageIndex >= 0 && imageDisplayProgress <= 4.0) {
            widget.nextImageOpacity.value = imageDisplayProgress - 3.0;
            widget.nextImageScale.value = imageDisplayProgress - 3.0;
          } else if (nextImageIndex >= 0 && imageDisplayProgress > 4.0) {
            widget.nextImageOpacity.value = 1.0;
            widget.nextImageScale.value = 1.0;
          }

          if (pauseFrameCount >= 90 && pauseFrameCount % 90 == 0) {
            if (currentImageIndex < currentImages.length - 1) {
              currentImageIndex++;
              nextImageIndex = currentImageIndex + 1 < currentImages.length ? currentImageIndex + 1 : -1;
              isLastImageFading = currentImageIndex == currentImages.length - 1;
              imageDisplayProgress = 0.0;
              widget.setCurrentImageIndex(currentImageIndex);
              widget.setNextImageIndex(nextImageIndex);
              widget.setImageDisplayProgress(imageDisplayProgress);
              widget.currentImageOpacity.value = 0.0;
              widget.currentImageScale.value = 0.0;
              widget.nextImageOpacity.value = 0.0;
              widget.nextImageScale.value = 0.0;
            } else {
              isPaused = false;
              currentImagePointIndex++;
              widget.isImageDisplayed(false);
              widget.setCurrentImages([]);
              widget.setCurrentImageIndex(0);
              widget.setNextImageIndex(-1);
              widget.setImageDisplayProgress(0.0);
              widget.currentImageOpacity.value = 0.0;
              widget.currentImageScale.value = 0.0;
              widget.nextImageOpacity.value = 0.0;
              widget.nextImageScale.value = 0.0;
            }
          }
        }
        widget.markerSizeNotifier.value = markerBaseSize;
      } else {
        animationProgress = 1.0;
        widget.saveDirectionNotifier.value = finalDirection;
        widget.markerSizeNotifier.value = markerBaseSize * _easeOutBack((totalFrames - frame - 1) / (zoomFrames - 1));
      }

      LatLng currentPoint = widget.circlePositionNotifier.value;
      widget.saveDirectionNotifier.value =
          calculateDirection(lastPosition, currentPoint, defaultDirection: widget.saveDirectionNotifier.value);
      lastPosition = currentPoint;

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
          double tFrame = frame / (zoomFrames - 1).toDouble();
          double zoomT = _easeInQuad(tFrame.clamp(0.0, 1.0));
          double panT = _easeOutQuad(tFrame.clamp(0.0, 1.0));
          double zoom = fitZoom + (initialZoom - fitZoom) * zoomT;
          LatLng center = _interpolateCenter(fittedCenter!, startPoint, panT);
          widget.mapController.move(center, zoom);
        } else if (frame < totalFrames - zoomFrames) {
          widget.mapController.move(currentPoint, initialZoom);
        } else {
          double tFrame = (frame - (totalFrames - zoomFrames)) / (zoomFrames - 1).toDouble();
          double zoomT = _easeOutQuad(tFrame.clamp(0.0, 1.0));
          double panT = tFrame < 0.5 ? 2 * tFrame * tFrame : 1 - pow(-2 * tFrame + 2, 2) / 2;
          double zoom = initialZoom - (initialZoom - fitZoom) * zoomT;
          LatLng center = _interpolateCenter(endPoint, fittedCenter!, panT);
          widget.mapController.move(center, zoom);
        }
      }

      if (mounted) {
        setState(() {});
      }
      String framePath = await _captureFrame(frame);
      if (framePath.isNotEmpty) framePaths.add(framePath);
      print('Frame $frame: isPaused=$isPaused, movementFrame=$movementFrameCount, pauseFrame=$pauseFrameCount, imageProgress=$imageDisplayProgress');
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
        if (!widget.isSavingNotifier.value || !mounted) {
          await _cleanup();
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
      await _cleanup();
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