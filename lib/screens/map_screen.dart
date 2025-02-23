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
          center: LatLng(51.509364, -0.128928), // Default center
          zoom: 13.0,
          rotation: 0.0, // Lock north up (rotation locked)
          interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Disable map rotation
          onTap: (tapPosition, point) {
            // Add a marker when the map is tapped
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
            markers: routePoints.asMap().map((index, point) {
              return MapEntry(
                index,
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  builder: (ctx) => GestureDetector(
                    onTap: () {
                      // Remove marker when tapped
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
                ),
              );
            }).values.toList(),
          ),
        ],
      ),
    );
  }
}
