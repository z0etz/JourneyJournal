import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/utils/video_util.dart';

class AnimationScreen extends StatefulWidget {
  final RouteModel? initialRoute;
  final Function(bool)? onSavingChanged;

  const AnimationScreen({super.key, this.initialRoute, this.onSavingChanged});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> with TickerProviderStateMixin {
  late RouteModel currentRoute;
  bool _isAnimating = false;
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false); // Shared state
  final int _currentMarkerIndex = 0;
  bool _isControlsExpanded = false;
  int _startMarkerIndex = 0;
  int _endMarkerIndex = 0;
  bool _showRouteTitles = false;
  String _selectedAspectRatio = "9:16";
  late ValueNotifier<bool> _rebuildNotifier;

  final MapController _mapController = MapController();
  double zoomLevel = 10.0;
  double fitZoom = 10.0;
  LatLng mapPosition = LatLng(59.322, 17.888);

  GlobalKey repaintBoundaryKey = GlobalKey();
  int frameCount = 100;

  final ValueNotifier<LatLng> _circlePositionNotifier = ValueNotifier<LatLng>(LatLng(0.0, 0.0));
  final ValueNotifier<double> _markerSizeNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _directionNotifier = ValueNotifier<double>(0.0);

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  final Duration _animationDuration = const Duration(seconds: 10);
  double _totalDistance = 0.0;
  static const double markerBaseSize = 25.0;

  double _getAspectRatioValue() {
    switch (_selectedAspectRatio) {
      case "16:9":
        return 16 / 9;
      case "3:2":
        return 3 / 2;
      case "2:3":
        return 2 / 3;
      case "1:1":
        return 1.0;
      case "9:16":
      default:
        return 9 / 16;
    }
  }

  @override
  void initState() {
    super.initState();
    print("Loading route");
    print("AnimationScreen repaintBoundaryKey initialized: $repaintBoundaryKey");
    _loadRoute();

    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _rebuildNotifier = ValueNotifier<bool>(false);
  }

  Future<void> _loadRoute() async {
    if (widget.initialRoute != null) {
      currentRoute = widget.initialRoute!;
    } else {
      var savedRoutes = await RouteModel.loadRoutes();
      if (savedRoutes.isEmpty) {
        currentRoute = await RouteModel.createNewRoute();
      } else {
        currentRoute = savedRoutes.last;
      }
    }

    if (currentRoute.routePoints.isNotEmpty) {
      print("Fitting map");
      Future.delayed(const Duration(milliseconds: 50), _fitMapToRoute);
    }

    setState(() {});
    _totalDistance = calculateTotalDistance(currentRoute);
  }

  void _fitMapToRoute() {
    fitMapToRoute(_mapController, currentRoute.routePoints.map((rp) => rp.point).toList(), isAnimationScreen: true);
    setState(() {
      fitZoom = _mapController.camera.zoom;
    });
    print("Map fitted, Fit Zoom: $fitZoom");
    if (currentRoute.routePoints.isNotEmpty) {
      _setInitialCirclePosition();
    }
  }

  void _setInitialCirclePosition() {
    if (currentRoute.routePoints.isNotEmpty) {
      LatLng firstPoint = currentRoute.routePoints.first.point;
      _circlePositionNotifier.value = firstPoint;
      if (currentRoute.routePoints.length > 1) {
        LatLng secondPoint = currentRoute.routePoints[1].point;
        _directionNotifier.value = atan2(
          secondPoint.longitude - firstPoint.longitude,
          secondPoint.latitude - firstPoint.latitude,
        );
      }
    }
  }

  void _toggleAnimation() {
    if (_isSavingNotifier.value) {
      // Cancel save
      print("Cancelling save via play/stop button");
      _isSavingNotifier.value = false;
      _animationController.stop();
      _animationController.reset();
      _circlePositionNotifier.value = currentRoute.routePoints.first.point;
      _markerSizeNotifier.value = 0.0;
      double initialDirection = currentRoute.routePoints.length > 1
          ? atan2(
        currentRoute.routePoints[1].point.longitude - currentRoute.routePoints[0].point.longitude,
        currentRoute.routePoints[1].point.latitude - currentRoute.routePoints[0].point.latitude,
      )
          : 0.0;
      _directionNotifier.value = initialDirection; // Match save’s initial direction
      setState(() {
        _isAnimating = false;
      });
    } else if (_isAnimating) {
      _animationController.stop();
      _animationController.reset();
      _circlePositionNotifier.value = currentRoute.routePoints.first.point;
      _markerSizeNotifier.value = 0.0;
      double initialDirection = currentRoute.routePoints.length > 1
          ? atan2(
        currentRoute.routePoints[1].point.longitude - currentRoute.routePoints[0].point.longitude,
        currentRoute.routePoints[1].point.latitude - currentRoute.routePoints[0].point.latitude,
      )
          : 0.0;
      _directionNotifier.value = initialDirection; // Consistent reset
      setState(() {
        _isAnimating = false;
      });
    } else {
      setState(() {
        _isAnimating = true;
      });
      _animateMarker();
    }
  }

  void _onSaveStart() {
    print("Save started in AnimationScreen");
    _rebuildNotifier.value = !_rebuildNotifier.value; // Trigger rebuild
  }

  void _selectStartPoint() {
    if (currentRoute.routePoints.isNotEmpty) {
      setState(() {
        _startMarkerIndex = (_startMarkerIndex + 1) % currentRoute.routePoints.length;
      });
    }
  }

  void _selectEndPoint() {
    if (currentRoute.routePoints.isNotEmpty) {
      setState(() {
        _endMarkerIndex = (_endMarkerIndex + 1) % currentRoute.routePoints.length;
      });
    }
  }

  void _animateMarker() {
    if (_isAnimating) {
      _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.linear,
        ),
      );

      _markerSizeNotifier.value = markerBaseSize;
      LatLng? lastPosition;
      _progressAnimation.addListener(() {
        moveCircleAlongPath(_progressAnimation.value, currentRoute, _circlePositionNotifier, _totalDistance);
        LatLng currentPosition = _circlePositionNotifier.value;
        if (lastPosition != null) {
          double deltaLat = currentPosition.latitude - lastPosition!.latitude;
          double deltaLng = currentPosition.longitude - lastPosition!.longitude;
          _directionNotifier.value = atan2(deltaLng, deltaLat);
        }
        lastPosition = currentPosition;
      });

      _animationController.reset();
      _animationController.forward().then((_) {
        _markerSizeNotifier.value = 0.0;
        if (currentRoute.routePoints.length > 1) {
          LatLng secondLast = currentRoute.routePoints[currentRoute.routePoints.length - 2].point;
          LatLng last = currentRoute.routePoints.last.point;
          _directionNotifier.value = atan2(
            last.longitude - secondLast.longitude,
            last.latitude - secondLast.latitude,
          );
        } else {
          _directionNotifier.value = 0.0;
        }
        setState(() {
          _isAnimating = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _isSavingNotifier.dispose();
    _circlePositionNotifier.dispose();
    _markerSizeNotifier.dispose();
    _directionNotifier.dispose();
    _animationController.dispose();
    _rebuildNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSavingNotifier.value,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Route Animation"),
          actions: [
            IconButton(
              icon: Icon(_isControlsExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
              onPressed: () {
                setState(() {
                  _isControlsExpanded = !_isControlsExpanded;
                });
              },
            ),
          ],
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: _rebuildNotifier,
          builder: (context, _, child) {
            return currentRoute.routePoints.isEmpty
                ? const Center(child: Text("Choose a non-empty route to animate."))
                : Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: repaintBoundaryKey,
                        child: AspectRatio(
                          aspectRatio: _getAspectRatioValue(),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: mapPosition,
                                initialZoom: zoomLevel,
                                onPositionChanged: (position, hasGesture) {
                                  if (!_isSavingNotifier.value) {
                                    setState(() {
                                      zoomLevel = position.zoom;
                                      mapPosition = position.center;
                                    });
                                  }
                                },
                                interactionOptions: _isSavingNotifier.value
                                    ? const InteractionOptions(flags: InteractiveFlag.none)
                                    : const InteractionOptions(
                                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                ),
                                if (currentRoute.routePoints.isNotEmpty)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: currentRoute.routePoints
                                            .map((routePoint) => routePoint.point)
                                            .toList(),
                                        color: Colors.blue,
                                        strokeWidth: 4.0,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: currentRoute.routePoints.map((routePoint) {
                                    return Marker(
                                      point: routePoint.point,
                                      width: 25.0,
                                      height: 25.0,
                                      child: Icon(
                                        Icons.circle,
                                        color: currentRoute.routePoints.indexOf(routePoint) ==
                                            _currentMarkerIndex
                                            ? Colors.green.withValues(alpha: 0.5)
                                            : Colors.blue,
                                        size: 15.0,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                ValueListenableBuilder<LatLng>(
                                  valueListenable: _circlePositionNotifier,
                                  builder: (context, position, child) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _markerSizeNotifier,
                                      builder: (context, size, child) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable: _directionNotifier,
                                          builder: (context, direction, child) {
                                            print("Marker direction in UI: $direction"); // Debug print
                                            return MarkerLayer(
                                              markers: [
                                                if (size > 0.0)
                                                  Marker(
                                                    point: position,
                                                    width: size,
                                                    height: size,
                                                    child: Transform.rotate(
                                                      angle: direction,
                                                      child: Icon(
                                                        Icons.navigation,
                                                        color: Colors.orange,
                                                        size: size,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        );
                                      },
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
                ),
                if (_isControlsExpanded)
                  Positioned(
                    top: 0,
                    left: 10.0,
                    right: 10.0,
                    child: Material(
                      color: (Theme.of(context).appBarTheme.backgroundColor ?? Colors.white)
                          .withValues(alpha: 0.8),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).appBarTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: AbsorbPointer(
                              absorbing: _isSavingNotifier.value,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _isSavingNotifier.value ? null : () => _selectStartPoint(),
                                        child: const Text("Set Start Point"),
                                      ),
                                      ElevatedButton(
                                        onPressed: _isSavingNotifier.value ? null : () => _selectEndPoint(),
                                        child: const Text("Set End Point"),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text("Animation Duration"),
                                  Slider(
                                    value: _animationController.duration!.inSeconds.toDouble(),
                                    min: 5,
                                    max: 24,
                                    divisions: 19,
                                    label: "${_animationController.duration!.inSeconds}s",
                                    onChanged: _isSavingNotifier.value
                                        ? null
                                        : (value) {
                                      setState(() {
                                        _animationController.duration = Duration(seconds: value.toInt());
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Zoom Level: ${zoomLevel.toStringAsFixed(1)}'),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Show Route Point Titles"),
                                      Switch(
                                        value: _showRouteTitles,
                                        onChanged: _isSavingNotifier.value
                                            ? null
                                            : (value) {
                                          setState(() {
                                            _showRouteTitles = value;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text("Aspect Ratio"),
                                  DropdownButton<String>(
                                    value: _selectedAspectRatio,
                                    items: ["9:16", "16:9", "3:2", "2:3", "1:1"].map((ratio) {
                                      return DropdownMenuItem<String>(
                                        value: ratio,
                                        child: Text(ratio),
                                      );
                                    }).toList(),
                                    onChanged: _isSavingNotifier.value
                                        ? null
                                        : (value) {
                                      setState(() {
                                        _selectedAspectRatio = value!;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: SaveButton(
                                      mapKey: repaintBoundaryKey,
                                      frameCount: frameCount,
                                      animationController: _animationController,
                                      circlePositionNotifier: _circlePositionNotifier,
                                      aspectRatio: _selectedAspectRatio,
                                      mapController: _mapController,
                                      currentRoute: currentRoute,
                                      initialZoom: zoomLevel,
                                      fitZoom: fitZoom,
                                      markerSizeNotifier: _markerSizeNotifier,
                                      directionNotifier: _directionNotifier,
                                      onSaveStart: () {
                                        print("Save started in AnimationScreen");
                                        _isSavingNotifier.value = true;
                                        widget.onSavingChanged?.call(true);
                                        _rebuildNotifier.value = !_rebuildNotifier.value; // Trigger rebuild
                                      },
                                      onSaveComplete: () {
                                        print("Save completed in AnimationScreen");
                                        _isSavingNotifier.value = false;
                                        widget.onSavingChanged?.call(false);
                                      },
                                      isSavingNotifier: _isSavingNotifier,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isSavingNotifier.value)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10.0),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4.0,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleAnimation,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isSavingNotifier,
            builder: (context, isSaving, child) {
              return Icon(isSaving
                  ? Icons.stop // Show stop icon during save
                  : _isAnimating
                  ? Icons.stop
                  : Icons.play_arrow);
            },
          ),
        ),
      ),
    );
  }
}