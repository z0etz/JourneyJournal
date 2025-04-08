import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/utils/video_util.dart';

class AnimationScreen extends StatefulWidget {
  final RouteModel? initialRoute;

  const AnimationScreen({super.key, this.initialRoute});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> with TickerProviderStateMixin {
  late RouteModel currentRoute;
  bool _isAnimating = false;
  final int _currentMarkerIndex = 0;
  bool _isControlsExpanded = false;
  int _startMarkerIndex = 0;
  int _endMarkerIndex = 0;
  bool _showRouteTitles = false;
  String _selectedAspectRatio = "9:16";

  final MapController _mapController = MapController();
  double zoomLevel = 10.0;
  double fitZoom = 10.0;
  LatLng mapPosition = LatLng(59.322, 17.888);

  GlobalKey repaintBoundaryKey = GlobalKey();
  int frameCount = 100;

  final ValueNotifier<LatLng> _circlePositionNotifier = ValueNotifier<LatLng>(LatLng(0.0, 0.0));
  final ValueNotifier<double> _markerSizeNotifier = ValueNotifier<double>(0.0); // Starts hidden

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  final Duration _animationDuration = const Duration(seconds: 10);
  double _totalDistance = 0.0;
  static const double markerBaseSize = 25.0;

  double _getAspectRatioValue() {
    switch (_selectedAspectRatio) {
      case "16:9": return 16 / 9;
      case "3:2": return 3 / 2;
      case "2:3": return 2 / 3;
      case "1:1": return 1.0;
      case "9:16": default: return 9 / 16;
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
  }

  // Load the route or create a new one
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
    }
  }

  void _toggleAnimation() {
    if (_isAnimating) {
      _animationController.stop();
      _animationController.reset();
      _circlePositionNotifier.value = currentRoute.routePoints.first.point;
      _markerSizeNotifier.value = 0.0; // Hide marker
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

      _markerSizeNotifier.value = markerBaseSize; // Show marker during preview
      _progressAnimation.addListener(() {
        moveCircleAlongPath(_progressAnimation.value, currentRoute, _circlePositionNotifier, _totalDistance);
      });

      _animationController.reset();
      _animationController.forward().then((_) {
        // Reset marker size when preview ends
        _markerSizeNotifier.value = 0.0;
        setState(() {
          _isAnimating = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: currentRoute.routePoints.isEmpty
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
                            setState(() {
                              zoomLevel = position.zoom;
                              mapPosition = position.center;
                            });
                          },
                          interactionOptions: const InteractionOptions(
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
                                  points: currentRoute.routePoints.map((routePoint) => routePoint.point).toList(),
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
                                  color: currentRoute.routePoints.indexOf(routePoint) == _currentMarkerIndex
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
                                  return MarkerLayer(
                                    markers: [
                                      if (size > 0.0) // Only show if size > 0
                                        Marker(
                                          point: position,
                                          width: size,
                                          height: size,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
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
                color: (Theme.of(context).appBarTheme.backgroundColor ?? Colors.white).withValues(alpha: 0.8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: () => _selectStartPoint(),
                            child: Text("Set Start Point"),
                          ),
                          ElevatedButton(
                            onPressed: () => _selectEndPoint(),
                            child: Text("Set End Point"),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text("Animation Duration"),
                      Slider(
                        value: _animationController.duration!.inSeconds.toDouble(),
                        min: 5,
                        max: 24,
                        divisions: 19,
                        label: "${_animationController.duration!.inSeconds}s",
                        onChanged: (value) {
                          setState(() {
                            _animationController.duration = Duration(seconds: value.toInt());
                          });
                        },
                      ),
                      SizedBox(height: 10),
                      Text('Zoom Level: ${zoomLevel.toStringAsFixed(1)}'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Show Route Point Titles"),
                          Switch(
                            value: _showRouteTitles,
                            onChanged: (value) {
                              setState(() {
                                _showRouteTitles = value;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text("Aspect Ratio"),
                      DropdownButton<String>(
                        value: _selectedAspectRatio,
                        items: ["9:16", "16:9", "3:2", "2:3", "1:1"].map((ratio) {
                          return DropdownMenuItem<String>(
                            value: ratio,
                            child: Text(ratio),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAspectRatio = value!;
                          });
                        },
                      ),
                      SizedBox(height: 10),
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
                          markerSizeNotifier: _markerSizeNotifier, // Pass size notifier
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleAnimation,
        child: Icon(_isAnimating ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}