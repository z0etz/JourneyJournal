import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/screens/main_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/models/route.dart';


class MapScreen extends StatefulWidget {
  final RouteModel? initialRoute;
  const MapScreen({super.key, this.initialRoute});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late RouteModel currentRoute;

  final MapController _mapController = MapController();
  double zoomLevel = 10.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoute != null) {
      currentRoute = widget.initialRoute!;
    } else {
      if (RouteModel.savedRoutes.isEmpty) {
        currentRoute = RouteModel.createNewRoute();
      } else {
        currentRoute = RouteModel.savedRoutes.last;
      }
    }
  }

  // Add marker at tapped location
  void _addMarker(LatLng point) {
    RoutePoint newRoutePoint = RoutePoint(point: point);

    if (currentRoute.routePoints.isEmpty) {
      setState(() {
        currentRoute.routePoints.add(newRoutePoint);
      });
      return;
    }

    bool inserted = false;
    for (int i = 0; i < currentRoute.routePoints.length - 1; i++) {
      LatLng p1 = currentRoute.routePoints[i].point;
      LatLng p2 = currentRoute.routePoints[i + 1].point;

      double threshold = getThreshold(zoomLevel);
      double distToSegment = distanceToSegment(point, p1, p2);

      if (distToSegment < threshold) {
        setState(() {
          currentRoute.routePoints.insert(i + 1, newRoutePoint);
        });
        inserted = true;
        break;
      }
    }

    if (!inserted) {
      setState(() {
        currentRoute.routePoints.add(newRoutePoint);
      });
    }
  }

  // Create list of DragMarkers
  List<DragMarker> _buildDragMarkers() {
    return currentRoute.routePoints.map((routePoint) {
      return DragMarker(
        key: GlobalKey<DragMarkerWidgetState>(),
        point: routePoint.point,
        size: const Size(160, 80),
        builder: (_, __, isDragging) {
          return GestureDetector(
            onTap: () {
              setState(() {
                currentRoute.routePoints.remove(routePoint);
              });
            },
            onLongPress: () {
              TextEditingController titleController = TextEditingController(text: routePoint.title);
              DateTime? selectedDate = routePoint.date;

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text("Marker Options"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: titleController,
                              maxLength: 12,
                              decoration: const InputDecoration(
                                labelText: "Title",
                              ),
                              onChanged: (value) {
                                setState(() {
                                  routePoint.title = value;
                                });
                              },
                            ),
                            TextButton(
                              onPressed: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    selectedDate = pickedDate;
                                    routePoint.date = pickedDate;
                                  });
                                }
                              },
                              child: Text(
                                selectedDate != null
                                    ? 'Date: ${selectedDate!.toLocal().toString().split(' ')[0]}'
                                    : 'Select Date',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text("Save"),
                          ),
                        ],
                      );
                    },
                  );
                },
              ).then((_) {
                setState(() {}); // Refresh UI after dialog is closed
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Title (closer to circle)
                if (routePoint.title.isNotEmpty)
                  Positioned(
                    bottom: 1,
                    // Reduce this value to move the title further down the circle
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        // Semi-transparent background
                        borderRadius: BorderRadius.circular(
                            8), // Rounded edges for a softer look
                      ),
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
                // Circle icon
                Icon(
                  currentRoute.routePoints.indexOf(routePoint) == 0
                      ? Icons.trip_origin
                      : currentRoute.routePoints.indexOf(routePoint) ==
                      currentRoute.routePoints.length - 1
                      ? Icons.flag_circle
                      : Icons.circle,
                  size: isDragging ? 65 : 40,
                  color: currentRoute.routePoints.indexOf(routePoint) == 0
                      ? const Color(0xFF4c8d40)
                      : currentRoute.routePoints.indexOf(routePoint) ==
                      currentRoute.routePoints.length - 1
                      ? const Color(0xFFde3a71)
                      : Colors.blue,
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
      body: OverflowBox(
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
              onTap: (tapPosition, point) {
                _addMarker(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (currentRoute.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: currentRoute.routePoints.map((routePoint) => routePoint.point)
                          .toList(),
                      color: Colors.blue.withAlpha(180),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              DragMarkers(
                markers: _buildDragMarkers(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create a new route and add it to the route list
          RouteModel newRoute = RouteModel.createNewRoute();

          // Navigate to the newly created route
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(initialRoute: newRoute),
            ),
                (Route<dynamic> route) => false, // Removes all previous routes
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

