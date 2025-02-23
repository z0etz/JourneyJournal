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

  void _addMarker(LatLng point) {
    setState(() {
      routePoints.add(point);
    });
  }

  void _removeMarker(int index) {
    setState(() {
      routePoints.removeAt(index);
    });
  }

  void _updateMarkerPosition(int index, LatLng newPosition) {
    setState(() {
      routePoints[index] = newPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: LatLng(51.509364, -0.128928),
          zoom: 13.0,
          rotation: 0.0, // Lock map rotation so north is always up
          onTap: (tapPosition, point) {
            _addMarker(point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: routePoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;

              return Marker(
                point: point,
                width: 40,
                height: 40,
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    // Delete marker on tap
                    _removeMarker(index);
                  },
                  child: Icon(
                    index == 0
                        ? Icons.flag // Start point icon
                        : (index == routePoints.length - 1
                        ? Icons.flag_outlined // End point icon
                        : Icons.circle), // Regular markers
                    color: index == 0
                        ? Colors.green // Start point color
                        : (index == routePoints.length - 1
                        ? Colors.red // End point color
                        : Colors.blue), // Regular marker color
                    size: 30,
                  ),
                ),
              );
            }).toList(),
          ),
          // Handling the dragging logic using Draggable
          ...routePoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;

            return Positioned(
              left: point.longitude, // Adjust the position calculation here
              top: point.latitude, // Adjust the position calculation here
              child: Draggable(
                feedback: Icon(
                  index == 0
                      ? Icons.flag // Start point icon
                      : (index == routePoints.length - 1
                      ? Icons.flag_outlined // End point icon
                      : Icons.circle),
                  color: index == 0
                      ? Colors.green
                      : (index == routePoints.length - 1
                      ? Colors.red
                      : Colors.blue),
                  size: 30,
                ),
                childWhenDragging: Container(), // Empty container when dragging
                onDragEnd: (details) {
                  // Handle updating the position after drag ends
                  final newLatLng = LatLng(
                    details.offset.dy, // y coordinate
                    details.offset.dx, // x coordinate
                  );
                  _updateMarkerPosition(index, newLatLng);
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
