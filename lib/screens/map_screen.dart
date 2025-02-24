import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';
import '../utils/map_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> routePoints = [];
  double zoomLevel = 10.0;

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
      LatLng p1 = routePoints[i];
      LatLng p2 = routePoints[i + 1];

      double threshold = getThreshold(zoomLevel);

      double distToSegment = distanceToSegment(point, p1, p2);
      if (distToSegment < threshold) {
        setState(() {
          routePoints.insert(i + 1, point);
        });
        inserted = true;
        break;
      }
    }

    if (!inserted) {
      setState(() {
        routePoints.add(point);
      });
    }
  }

  // Create a list of DragMarkers with custom appearance
  List<DragMarker> _buildDragMarkers() {
    return routePoints.map((point) {
      return DragMarker(
        key: GlobalKey<DragMarkerWidgetState>(),
        point: point,
        size: const Size(40, 40),
        builder: (_, __, isDragging) {
          return GestureDetector(
            onTap: () {
              // Remove the marker on tap
              setState(() {
                routePoints.remove(point);
              });
            },
            child: Opacity(
              opacity: isDragging ? 0.5 : 0.7,
              child: Icon(
                routePoints.indexOf(point) == 0
                    ? Icons.trip_origin
                    : routePoints.indexOf(point) == routePoints.length - 1
                    ? Icons.flag_circle
                    : Icons.circle,
                size: isDragging ? 65 : 40,
                color: routePoints.indexOf(point) == 0
                    ? const Color(0xFF4c8d40)
                    : routePoints.indexOf(point) == routePoints.length - 1
                    ? const Color(0xFFde3a71)
                    : Colors.blue,
              ),
            ),
          );
        },
        onDragEnd: (details, newPoint) {
          setState(() {
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
          initialCenter: LatLng(59.3325, 18.065),
          initialZoom: 10.0,
          onPositionChanged: (position, hasGesture) {
            setState(() {
              zoomLevel = position.zoom;
            });
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
          onTap: (tapPosition, point) {
            _addMarker(point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  color: Colors.blue.withValues(alpha: 0.7),
                  strokeWidth: 4.0,
                ),
              ],
            ),
          DragMarkers(
            markers: _buildDragMarkers(),
          ),
        ],
      ),
    );
  }
}


