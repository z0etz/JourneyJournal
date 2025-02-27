import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/screens/main_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/models/route_model.dart'; // Import the RouteModel

class MapScreen extends StatefulWidget {
  final RouteModel? initialRoute;
  const MapScreen({super.key, this.initialRoute});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late RouteModel currentRoute;
  late TextEditingController _routeNameController;
  bool _isEditing = false;

  final MapController _mapController = MapController();
  double zoomLevel = 10.0;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (widget.initialRoute != null) {
      currentRoute = widget.initialRoute!;
      print("Map screen route: ${widget.initialRoute?.name ?? 'No route'}");
    } else {
      // Fetch the saved routes asynchronously
      var savedRoutes = await RouteModel.loadRoutes();
      if (savedRoutes.isEmpty) {
        currentRoute = await RouteModel.createNewRoute(); // Await to create and save a new route
        print("Map screen new route: No saved routes");
      } else {
        currentRoute = savedRoutes.last;
        print("Map screen last route: ${savedRoutes.last.name}");
      }
    }
    _routeNameController = TextEditingController(text: currentRoute.name);
    setState(() {}); // Refresh the UI after loading the route
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    super.dispose();
  }

  // Add marker at tapped location
  void _addMarker(LatLng point) {
    RoutePoint newRoutePoint = RoutePoint();
    newRoutePoint.point = point;


    if (currentRoute.routePoints.isEmpty) {
      setState(() {
        currentRoute.routePoints.add(newRoutePoint);
      });
      currentRoute.save();
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
        currentRoute.save();
        break;
      }
    }

    if (!inserted) {
      setState(() {
        currentRoute.routePoints.add(newRoutePoint);
        currentRoute.save();
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
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {
              _isEditing = true;
            });
          },
          child: _isEditing
              ? TextField(
            controller: _routeNameController,
            onSubmitted: (newName) {
              setState(() {
                currentRoute.name = newName;
                _isEditing = false;
                currentRoute.save(); // Save updated route
              });
            },
          )
              : Text(currentRoute.name),
        ),
      ),
      body: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: MediaQuery.of(context).size.width + 200,
        // Extra width for overflow
        maxHeight: MediaQuery.of(context).size.height + 100,
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
                      points: currentRoute.routePoints.map((routePoint) => routePoint.point).toList(),
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
          onPressed: () async {
            // Create the new route and save it
            RouteModel newRoute = await RouteModel.createNewRoute(); // Await creation and saving

            // Schedule the navigation after the current frame
            SchedulerBinding.instance.addPostFrameCallback((_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => MainScreen(initialRoute: newRoute),
                ),
                    (Route<dynamic> route) => false, // Removes all previous routes
              );
            });
          },
          child: const Icon(Icons.add),
        )
    );
  }
}
