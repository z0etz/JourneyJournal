import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/models/route_point.dart';

class AnimationScreen extends StatefulWidget {
  final RouteModel? initialRoute;

  const AnimationScreen({super.key, this.initialRoute});

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> {
  late RouteModel currentRoute;
  late List<RoutePoint> _routePoints;
  bool _isAnimating = false;
  int _currentMarkerIndex = 0;
  final MapController _mapController = MapController();
  double zoomLevel = 10.0;

  @override
  void initState() {
    super.initState();
    _loadRoute();
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
  }

  // Toggle animation
  void _toggleAnimation() {
    setState(() {
      _isAnimating = !_isAnimating;
      if (_isAnimating) {
        _animateMarker();
      }
    });
  }

  // Simulate marker movement along the route
  void _animateMarker() {
    if (_currentMarkerIndex < _routePoints.length - 1 && _isAnimating) {
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _currentMarkerIndex++;
        });
        _animateMarker();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Animation"),
      ),
      body: _routePoints.isEmpty
          ? const Center(child: Text("No route available"))
          : OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: MediaQuery.of(context).size.width + 200, // Extra width for overflow
        maxHeight: MediaQuery.of(context).size.height + 100, // Extra height for overflow
        child: Transform.translate(
          offset: const Offset(-200, -100), // Offset to allow overflow in all directions
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // No need to pass 'center' and 'zoom' directly here
              // These will be managed via _mapController
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  zoomLevel = position.zoom;
                });
              },
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
                      points: _routePoints.map((routePoint) => routePoint.point).toList(),
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
                      color: _routePoints.indexOf(routePoint) == _currentMarkerIndex
                          ? Colors.green
                          : Colors.red,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleAnimation,
        child: Icon(_isAnimating ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
