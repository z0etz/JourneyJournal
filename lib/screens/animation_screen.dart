import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:geolocator/geolocator.dart';

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
  LatLng mapPosition = LatLng(59.322, 17.888);

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

  // Duration variable to control animation speed
  final Duration _animationDuration = const Duration(seconds: 10);

  // Add ValueNotifier to track the animated position
  final ValueNotifier<LatLng> _circlePositionNotifier = ValueNotifier<LatLng>(
      LatLng(0.0, 0.0));

  // Animation controller for smooth movement
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double _totalDistance = 0.0; // Total distance of the route

  @override
  void initState() {
    super.initState();
    print("Loading route");
    _loadRoute();

    // Initialize the animation controller with the vsync provided by this widget
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration, // Duration for the entire movement
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

    // Calculate the total distance of the route
    _calculateTotalDistance();
  }

  void _fitMapToRoute() {
    fitMapToRoute(_mapController,
        currentRoute.routePoints.map((rp) => rp.point).toList(), isAnimationScreen: true);
    print("Map fitted");

    // Ensure the circle is placed at the first point of the route when loaded
    if (currentRoute.routePoints.isNotEmpty) {
      // Set the initial circle position to the first point in the route
      _setInitialCirclePosition();
    }
  }

  // Calculate total distance of the route using Geolocator
  void _calculateTotalDistance() {
    double totalDistance = 0.0;
    for (int i = 0; i < currentRoute.routePoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        currentRoute.routePoints[i].point.latitude,
        currentRoute.routePoints[i].point.longitude,
        currentRoute.routePoints[i + 1].point.latitude,
        currentRoute.routePoints[i + 1].point.longitude,
      );
    }
    _totalDistance = totalDistance;
  }

  void _setInitialCirclePosition() {
    if (currentRoute.routePoints.isNotEmpty) {
      // Set the circle's initial position to the first point of the route
      LatLng firstPoint = currentRoute.routePoints.first.point;
      setState(() {
        // Directly set the position on the ValueNotifier
        _circlePositionNotifier.value = firstPoint;
      });
    }
  }

  // Toggle animation
  void _toggleAnimation() {
    if (_isAnimating) {
      _animationController.stop(); // Stop the animation
      _animationController.reset(); // Reset progress to start
      _circlePositionNotifier.value =
          currentRoute.routePoints.first.point; // Move marker to start
      setState(() {
        _isAnimating = false; // Ensure the state is properly updated
      });
    } else {
      setState(() {
        _isAnimating = true;
      });
      _animateMarker(); // Start the animation fresh
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

  void _saveAnimation() {
    // Placeholder for future video export logic
    print("Save animation clicked!");
  }

  // Animate the marker smoothly along the polyline
  void _animateMarker() {
    if (_isAnimating) {
      // Create a Tween for progress (0.0 to 1.0)
      _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.linear, // Linear curve for smooth constant speed
        ),
      );

      // Add listener to update the position of the circle
      _progressAnimation.addListener(() {
        _moveCircleAlongPath(_progressAnimation.value);
      });

      // Start the animation from the beginning
      _animationController.reset();
      _animationController.forward();
    }
  }

  // Move the circle along the polyline based on progress
  void _moveCircleAlongPath(double progress) {
    List<LatLng> path = currentRoute.routePoints.map((point) => point.point).toList();

    // Calculate the total distance covered so far
    double distanceCovered = progress * _totalDistance;

    // Now we need to find where this distance lies on the path
    double distanceSoFar = 0.0;
    int startIndex = 0;
    int endIndex = 1;

    for (int i = 0; i < path.length - 1; i++) {
      double segmentDistance = Geolocator.distanceBetween(
          path[i].latitude, path[i].longitude,
          path[i + 1].latitude, path[i + 1].longitude
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

    // Interpolate the position
    double ratio = (distanceCovered -
        (distanceSoFar - Geolocator.distanceBetween(
            startPoint.latitude, startPoint.longitude,
            path[startIndex + 1].latitude, path[startIndex + 1].longitude
        ))) /
        (Geolocator.distanceBetween(
          startPoint.latitude, startPoint.longitude,
          endPoint.latitude, endPoint.longitude,
        ));
    double lat = startPoint.latitude +
        (endPoint.latitude - startPoint.latitude) * ratio;
    double lng = startPoint.longitude +
        (endPoint.longitude - startPoint.longitude) * ratio;

    LatLng interpolatedPosition = LatLng(lat, lng);

    // Update the circle position with the new interpolated position
    _circlePositionNotifier.value = interpolatedPosition;
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
                _isControlsExpanded = !_isControlsExpanded; // Toggle the expansion
              });
            },
          ),
        ],
      ),
      body: currentRoute.routePoints.isEmpty
          ? const Center(child: Text("Choose a non-empty route to animate."))
      : Stack(
        children: [
          // Map with fixed aspect ratio
          Align(
            alignment: Alignment.bottomCenter, // Move map to the bottom
            child: Padding(
              padding: const EdgeInsets.all(16.0), // Padding around the map
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, // Background color
                  borderRadius: BorderRadius.circular(12), // Rounded corners
                  border: Border.all(color: Colors.black, width: 2), // Small black frame
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 4), // Subtle shadow
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: _getAspectRatioValue(), // Dynamic aspect ratio
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10), // Match border radius
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
                              width: 40.0,
                              height: 40.0,
                              child: Icon(
                                Icons.circle,
                                color: currentRoute.routePoints.indexOf(routePoint) == _currentMarkerIndex
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            );
                          }).toList(),
                        ),
                        ValueListenableBuilder<LatLng>(
                          valueListenable: _circlePositionNotifier,
                          builder: (context, position, child) {
                            return MarkerLayer(
                              markers: [
                                Marker(
                                  point: position,
                                  width: 40.0,
                                  height: 40.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
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
          // Positioned (only visible when _isControlsExpanded is true)
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
                    color: Theme.of(context).appBarTheme.backgroundColor, // Match AppBar color
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Start & End Marker Selection
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

                      // Animation Speed Slider
                      Text("Animation Speed"),
                      Slider(
                        value: _animationController.duration!.inSeconds.toDouble(),
                        min: 1,
                        max: 20,
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


                      // Toggle for showing route point titles
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

                      // Aspect Ratio Selection
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

                      // Save Animation Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _saveAnimation,
                          icon: Icon(Icons.save),
                          label: Text("Save Animation"),
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
