import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> routePoints = [];

  // Add marker at tapped location
  void _addMarker(LatLng point) {
    setState(() {
      routePoints.add(point);
    });
  }

  // Remove marker at tapped position
  void _removeMarker(int index) {
    setState(() {
      routePoints.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(59.3325, 18.065), // Default center
          initialZoom: 10.0,                     // Default zoom
          interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          onTap: (tapPosition, point) {
            // Add a marker when the map is tapped
            _addMarker(point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", // OSM Tile URL without subdomains
          ),
          if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue.withValues(alpha: 0.7), // Using .withValues() for opacity
                strokeWidth: 4.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: routePoints.asMap().map((index, point) {
              return MapEntry(
                index,
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  // Set the position of the marker
                  alignment: Alignment.center,
                  // Create custom marker widget here
                  child: GestureDetector(
                    onTap: () {
                      // Remove marker when tapped
                      _removeMarker(index);
                    },
                    child: Opacity(
                      opacity: 0.7, // Adjust this value for desired opacity (0.0 to 1.0)
                      child: Icon(
                        index == 0
                            ? Icons.trip_origin // Start point icon
                            : (index == routePoints.length - 1
                            ? Icons.flag_circle // End point icon
                            : Icons.circle), // Regular markers
                        color: index == 0
                            ? const Color(0xFF4c8d40) // Start point color
                            : (index == routePoints.length - 1
                            ? const Color(0xFFde3a71) // End point color
                            : Colors.blue), // Regular marker color
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            }).values.toList(),
          ),
        ],
      ),
    );
  }
}
