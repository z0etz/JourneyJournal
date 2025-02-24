import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';
import '../utils/map_utils.dart';
import '../models/route_point.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<RoutePoint> routePoints = [];
  double zoomLevel = 10.0;

  // Add marker at tapped location
  void _addMarker(LatLng point) {
    RoutePoint newRoutePoint = RoutePoint(point: point);

    if (routePoints.isEmpty) {
      setState(() {
        routePoints.add(newRoutePoint);
      });
      return;
    }

    bool inserted = false;
    for (int i = 0; i < routePoints.length - 1; i++) {
      LatLng p1 = routePoints[i].point;
      LatLng p2 = routePoints[i + 1].point;

      double threshold = getThreshold(zoomLevel);
      double distToSegment = distanceToSegment(point, p1, p2);

      if (distToSegment < threshold) {
        setState(() {
          routePoints.insert(i + 1, newRoutePoint);
        });
        inserted = true;
        break;
      }
    }

    if (!inserted) {
      setState(() {
        routePoints.add(newRoutePoint);
      });
    }
  }

  // Create list of DragMarkers
  List<DragMarker> _buildDragMarkers() {
    return routePoints.map((routePoint) {
      return DragMarker(
        key: GlobalKey<DragMarkerWidgetState>(),
        point: routePoint.point,
        size: const Size(80, 80),
        builder: (_, __, isDragging) {
          return GestureDetector(
            onTap: () {
              setState(() {
                routePoints.remove(routePoint);
              });
            },
            onLongPress: () {
              TextEditingController titleController = TextEditingController(text: routePoint.title);
              TextEditingController dateController = TextEditingController(text: routePoint.date);

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text("Marker Options"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,  // Ensures the Column only takes as much space as needed
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: const InputDecoration(
                                labelText: "Title",
                              ),
                              onChanged: (value) {
                                setState(() {
                                  routePoint.title = value;
                                });
                              },
                            ),
                            TextField(
                              controller: dateController,
                              decoration: const InputDecoration(
                                labelText: "Date",
                              ),
                              onChanged: (value) {
                                setState(() {
                                  routePoint.date = value;
                                });
                              },
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text("Close"),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circle icon
                Icon(
                  routePoints.indexOf(routePoint) == 0
                      ? Icons.trip_origin
                      : routePoints.indexOf(routePoint) == routePoints.length - 1
                      ? Icons.flag_circle
                      : Icons.circle,
                  size: isDragging ? 65 : 40,
                  color: routePoints.indexOf(routePoint) == 0
                      ? const Color(0xFF4c8d40)
                      : routePoints.indexOf(routePoint) == routePoints.length - 1
                      ? const Color(0xFFde3a71)
                      : Colors.blue,
                ),
                // Title (closer to circle)
                if (routePoint.title.isNotEmpty)
                  Positioned(
                    bottom: 1, // Reduce this value to move the title further down the circle
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 30),
                      child: Text(
                        routePoint.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        onDragEnd: (details, newPoint) {
          setState(() {
            routePoint.point = newPoint;
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
                  points: routePoints.map((routePoint) => routePoint.point).toList(),
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
