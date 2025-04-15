import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/screens/main_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:uuid/uuid.dart';

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
  bool _reverseMode = false;

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
      print("MapScreen: Loaded initialRoute=${currentRoute.name}");
    } else {
      // Fallback: load saved routes, should rarely happen as MainScreen provides initialRoute
      var savedRoutes = await RouteModel.loadRoutes();
      if (savedRoutes.isEmpty) {
        currentRoute = await RouteModel.createNewRoute();
        print("MapScreen: Created new route=${currentRoute.name}");
      } else {
        currentRoute = savedRoutes.last;
        print("MapScreen: Loaded last saved route=${currentRoute.name}");
      }
    }
    _routeNameController = TextEditingController(text: currentRoute.name);
    setState(() {}); // Refresh the UI after loading the route

    if (currentRoute.routePoints.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 50), _fitMapToRoute);
    }
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    super.dispose();
  }

  // Method to delete the route point
  void _deleteRoutePoint(RoutePoint routePoint) {
    setState(() {
      currentRoute.routePoints.remove(routePoint);
      currentRoute.save();
    });
  }

  // Method to save the route point's changes
  void _saveRoutePoint(
      RoutePoint routePoint,
      TextEditingController titleController,
      TextEditingController descriptionController,
      DateTime? selectedDate) {
    routePoint.title = titleController.text;
    routePoint.description = descriptionController.text;
    routePoint.date = selectedDate;
    // Images are updated in dialog
    currentRoute.save();
  }

  // Add marker at tapped location
  void _addMarker(LatLng point) {
    final uuid = Uuid();
    RoutePoint newRoutePoint = RoutePoint(
      point: point,
      id: uuid.v4(),
    );
    newRoutePoint.images = [];

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
        if (_reverseMode) {
          currentRoute.routePoints.insert(0, newRoutePoint);
        } else {
          currentRoute.routePoints.add(newRoutePoint);
        }
        currentRoute.save();
      });
    }
  }

  void _fitMapToRoute() {
    fitMapToRoute(_mapController, currentRoute.routePoints.map((rp) => rp.point).toList());
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
              if (routePoint.hasInfo) {
                TextEditingController titleController = TextEditingController(text: routePoint.title);
                TextEditingController descriptionController = TextEditingController(text: routePoint.description);
                DateTime? selectedDate = routePoint.date;

                showRoutePointDialog(
                  context,
                  routePoint,
                  titleController: titleController,
                  descriptionController: descriptionController,
                  selectedDate: selectedDate,
                  onDelete: () => _deleteRoutePoint(routePoint),
                  onSave: () => _saveRoutePoint(routePoint, titleController, descriptionController, selectedDate),
                  availableTags: currentRoute.tags, // Pass route tags
                ).then((_) {
                  setState(() {});
                });
              } else {
                setState(() {
                  currentRoute.routePoints.remove(routePoint);
                });
                currentRoute.save();
              }
            },
            onLongPress: () {
              TextEditingController titleController = TextEditingController(text: routePoint.title);
              TextEditingController descriptionController = TextEditingController(text: routePoint.description);
              DateTime? selectedDate = routePoint.date;

              showRoutePointDialog(
                context,
                routePoint,
                titleController: titleController,
                descriptionController: descriptionController,
                selectedDate: selectedDate,
                onDelete: () => _deleteRoutePoint(routePoint),
                onSave: () => _saveRoutePoint(routePoint, titleController, descriptionController, selectedDate),
                availableTags: currentRoute.tags, // Pass route tags
              ).then((_) {
                setState(() {});
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (routePoint.title.isNotEmpty)
                  Positioned(
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black54, width: 1),
                      ),
                      child: Text(
                        routePoint.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                Icon(
                  routePoint.hasInfo
                      ? Icons.stars
                      : currentRoute.routePoints.indexOf(routePoint) == 0
                      ? Icons.trip_origin
                      : currentRoute.routePoints.indexOf(routePoint) == currentRoute.routePoints.length - 1
                      ? Icons.flag_circle
                      : Icons.circle,
                  size: isDragging ? 65 : 40,
                  color: currentRoute.routePoints.indexOf(routePoint) == 0
                      ? const Color(0xFF4c8d40)
                      : currentRoute.routePoints.indexOf(routePoint) == currentRoute.routePoints.length - 1
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
                currentRoute.save();
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
        maxHeight: MediaQuery.of(context).size.height + 100,
        child: Transform.translate(
          offset: const Offset(-200, -100),
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
      floatingActionButton: Stack(
        children: [
          Positioned(
            left: 38,
            bottom: 6,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _reverseMode = !_reverseMode;
                });
              },
              backgroundColor: _reverseMode ? Colors.blueGrey : null,
              child: const Icon(Icons.route),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: FloatingActionButton(
              onPressed: () async {
                RouteModel newRoute = await RouteModel.createNewRoute();
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainScreen(initialRoute: newRoute),
                    ),
                        (Route<dynamic> route) => false,
                  );
                });
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}