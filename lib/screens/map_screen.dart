import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> routePoints = []; // This will store your route points (markers)
  double zoomLevel = 10.0;

  // Method to calculate distance between two points
  double distance(LatLng point1, LatLng point2) {
    return sqrt(
      pow(point2.latitude - point1.latitude, 2) +
          pow(point2.longitude - point1.longitude, 2),
    );
  }

  // Add marker at tapped location
  void _addMarker(LatLng point) {
    if (routePoints.isEmpty) {
      setState(() {
        routePoints.add(point);
      });
      return;
    }

    // Check if the tapped point is close to any of the segments in the polyline
    bool inserted = false;
    for (int i = 0; i < routePoints.length - 1; i++) {
      // Check distance to each line segment
      LatLng p1 = routePoints[i];
      LatLng p2 = routePoints[i + 1];

      // You can adjust this threshold value as needed
      double threshold = 0.0002 * pow(2, (15 - zoomLevel));  // Set threshold for adding points between points relative to zoom level

      // Calculate the distance to the line segment using your custom logic
      double distToSegment = _distanceToSegment(point, p1, p2);
      if (distToSegment < threshold) {
        // Insert marker in the middle of the segment
        setState(() {
          routePoints.insert(i + 1, point); // Add marker between the two points
        });
        inserted = true;
        break;
      }
    }

    // If the point was not close to any segment, add it at the end
    if (!inserted) {
      setState(() {
        routePoints.add(point);
      });
    }
  }

  // Calculate the minimum distance from a point to a line segment
  double _distanceToSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    double dx = lineEnd.longitude - lineStart.longitude;
    double dy = lineEnd.latitude - lineStart.latitude;
    if (dx == 0 && dy == 0) {
      return distance(point, lineStart); // Handle the case when the line is a single point
    }

    double t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0); // Clamp t to stay between 0 and 1 to ensure it's on the segment
    LatLng closestPoint = LatLng(lineStart.latitude + t * dy, lineStart.longitude + t * dx);
    return distance(point, closestPoint);
  }

  // Create a list of DragMarkers with custom appearance
  List<DragMarker> _buildDragMarkers() {
    return routePoints.map((point) {
      return DragMarker(
        key: GlobalKey<DragMarkerWidgetState>(),
        point: point,  // Start with the current route point
        size: const Size(40, 40), // Custom size for the markers
        offset: Offset.fromDirection(10.0),
        builder: (_, __, isDragging) {
          return GestureDetector(
            onTap: () {
              // Remove the marker on tap
              setState(() {
                routePoints.remove(point);  // Remove the tapped marker from the list
              });
            },
            child: Opacity(
              opacity: isDragging ? 0.5 : 0.7, // Change opacity while dragging
              child: Align(
                alignment: Alignment.center, // Align to center at the point
                child: Transform.translate(
                  offset: const Offset(0, 20), // Apply the vertical offset here
                  child: Icon(
                    // Custom marker icons based on index
                    routePoints.indexOf(point) == 0
                        ? Icons.trip_origin // Start point
                        : routePoints.indexOf(point) == routePoints.length - 1
                        ? Icons.flag_circle // End point
                        : Icons.circle, // Regular markers
                    size: isDragging ? 65 : 40, // Change size during dragging
                    color: routePoints.indexOf(point) == 0
                        ? const Color(0xFF4c8d40) // Start point color
                        : routePoints.indexOf(point) == routePoints.length - 1
                        ? const Color(0xFFde3a71) // End point color
                        : Colors.blue, // Regular marker color
                  ),
                ),
              ),
            ),
          );
        },
        onDragEnd: (details, newPoint) {
          setState(() {
            // Update the route with the new position
            routePoints[routePoints.indexOf(point)] = newPoint;
          });
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(59.3325, 18.065), // Default center
          initialZoom: 10.0, // Default zoom
          onPositionChanged: (position, hasGesture) {
            setState(() {
              zoomLevel = position.zoom; // Update zoomLevel on zoom changes
            });
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
          onTap: (tapPosition, point) {
            // Add a marker when the map is tapped
            _addMarker(point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", // OSM Tile URL
          ),
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  color: Colors.blue.withValues(alpha: 0.7), // Using opacity directly
                  strokeWidth: 4.0,
                ),
              ],
            ),
          // DragMarkers (added directly based on route points)
          DragMarkers(
            markers: _buildDragMarkers(), // Dynamically build drag markers from route points
            alignment: Alignment.topCenter, // Set alignment for markers
          ),
        ],
      ),
    );
  }
}

