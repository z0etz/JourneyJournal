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
  late List<RoutePoint> _routePoints;
  bool _isAnimating = false;
  int _currentMarkerIndex = 0;
  bool _isControlsExpanded = false;


  final MapController _mapController = MapController();
  double zoomLevel = 10.0;

  // Duration variable to control animation speed
  Duration _animationDuration = const Duration(seconds: 10);

  // Add ValueNotifier to track the animated position
  ValueNotifier<LatLng> _circlePositionNotifier = ValueNotifier<LatLng>(
      LatLng(0.0, 0.0));

  // Animation controller for smooth movement
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double _totalDistance = 0.0; // Total distance of the route

  @override
  void initState() {
    super.initState();
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
    _routePoints = currentRoute.routePoints;
    setState(() {});

    if (currentRoute.routePoints.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), _fitMapToRoute);
    }

    // Calculate the total distance of the route
    _calculateTotalDistance();
  }

  void _fitMapToRoute() {
    fitMapToRoute(_mapController,
        currentRoute.routePoints.map((rp) => rp.point).toList());
  }

  // Calculate total distance of the route using Geolocator
  void _calculateTotalDistance() {
    double totalDistance = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        _routePoints[i].point.latitude,
        _routePoints[i].point.longitude,
        _routePoints[i + 1].point.latitude,
        _routePoints[i + 1].point.longitude,
      );
    }
    _totalDistance = totalDistance;
  }

  // Toggle animation
  void _toggleAnimation() {
    if (_isAnimating) {
      _animationController.stop(); // Stop the animation
      _animationController.reset(); // Reset progress to start
      _circlePositionNotifier.value =
          _routePoints.first.point; // Move marker to start
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
    List<LatLng> path = _routePoints.map((point) => point.point).toList();

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
      body: _routePoints.isEmpty
          ? const Center(child: Text("Choose a non-empty route to animate."))
      : Stack(
        children: [
          // Map with OverflowBox
          OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: MediaQuery
                .of(context)
                .size
                .width + 200,
            // Extra width for overflow
            maxHeight: MediaQuery
                .of(context)
                .size
                .height + 100,
            // Extra height for overflow
            child: Transform.translate(
              offset: const Offset(-200, -100),
              // Offset to allow overflow in all directions
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(59.322, 17.888),
                  initialZoom: 10.0,
                  onPositionChanged: (position, hasGesture) {
                    setState(() {
                      zoomLevel = position.zoom;
                    });
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  // TileLayer for base map
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  ),
                  // PolylineLayer for route path
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints.map((routePoint) =>
                          routePoint.point).toList(),
                          color: Colors.blue,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                  // MarkerLayer for route points
                  MarkerLayer(
                    markers: _routePoints.map((routePoint) {
                      return Marker(
                        point: routePoint.point,
                        width: 40.0, // Width of the marker
                        height: 40.0, // Height of the marker
                        child: Icon(
                          Icons.location_on,
                          color: _routePoints.indexOf(routePoint) ==
                              _currentMarkerIndex
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    }).toList(),
                  ),
                  // Animated Circle Marker
                  ValueListenableBuilder<LatLng>(
                    valueListenable: _circlePositionNotifier,
                    builder: (context, position, child) {
                      return MarkerLayer(
                        markers: [
                          Marker(
                            point: position, // Circle's position
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
          // Positioned (only visible when _isControlsExpanded is true)
          if (_isControlsExpanded)
            Positioned(
              top: 0,
              left: 10.0,
              right: 10.0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.0), // Only horizontal padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0), // Rounded corners for the controls
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('Control 1'),
                        onTap: () {
                          // Handle control 1 action
                        },
                      ),
                      ListTile(
                        title: Text('Control 2'),
                        onTap: () {
                          // Handle control 2 action
                        },
                      ),
                      // Add more controls here as needed
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
