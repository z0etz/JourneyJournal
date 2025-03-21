import 'dart:ffi';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:journeyjournal/utils/image_helper.dart';

double distance(LatLng point1, LatLng point2) {
  return sqrt(
    pow(point2.latitude - point1.latitude, 2) +
        pow(point2.longitude - point1.longitude, 2),
  );
}

double distanceToSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
  double dx = lineEnd.longitude - lineStart.longitude;
  double dy = lineEnd.latitude - lineStart.latitude;
  if (dx == 0 && dy == 0) {
    return distance(point, lineStart);
  }

  double t = ((point.longitude - lineStart.longitude) * dx +
      (point.latitude - lineStart.latitude) * dy) /
      (dx * dx + dy * dy);
  t = t.clamp(0.0, 1.0);
  LatLng closestPoint =
  LatLng(lineStart.latitude + t * dy, lineStart.longitude + t * dx);
  return distance(point, closestPoint);
}

double getThreshold(double zoomLevel) {
  return 0.0002 * pow(2, (15 - zoomLevel));
}

void fitMapToRoute(MapController mapController, List<LatLng> routePoints, {bool isAnimationScreen = false}) {
  if (routePoints.isEmpty) return; // Skip if no points

  LatLngBounds bounds = LatLngBounds.fromPoints(routePoints);

  // Compute center of bounds
  LatLng center = LatLng(
    (bounds.north + bounds.south) / 2,
    (bounds.east + bounds.west) / 2,
  );

  // Define padding (prevents points from being too close to screen edges)
  double padding = 30.0; // Pixels
  double longitudeOffset = 0;

  // Apply an offset to shift the center leftward (westward) and adjust padding
  if(!isAnimationScreen) {
    longitudeOffset = (bounds.east - bounds.west) * 0.375; // Adjust as needed
    padding = 150.0;
  }
  LatLng adjustedCenter = LatLng(center.latitude, center.longitude - longitudeOffset);

  mapController.fitCamera(
    CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.all(padding),
    ),
  );

  // Move to the adjusted center after fitting bounds
  mapController.move(adjustedCenter, mapController.camera.zoom);
}

Future<void> showRoutePointDialog(
    BuildContext context,
    RoutePoint routePoint, {
      required TextEditingController titleController,
      required TextEditingController descriptionController,
      DateTime? selectedDate,
      required Function() onDelete, // Callback to delete route point
      required Function() onSave,   // Callback to save route point
    }) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Marker Options"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    maxLength: 12,
                    decoration: const InputDecoration(
                      labelText: "Title",
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        routePoint.title = value;
                      });
                    },
                  ),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description",
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        routePoint.description = value;
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
                        setDialogState(() {
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
                  TextButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> pickedImages = await picker.pickMultiImage();

                      if (pickedImages.isNotEmpty) {
                        for (var image in pickedImages) {
                          String savedPath = await saveImageLocally(image);
                          setDialogState(() {
                            routePoint.images.add(savedPath); // Directly update `routePoint.images`
                          });
                        }
                      }
                    },
                    child: const Text(
                      'Add Images',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  // Display selected images with delete option
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: routePoint.images.map((path) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.file(
                                File(path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final file = File(path);
                                  if (await file.exists()) {
                                    await file.delete();
                                  }
                                  setDialogState(() {
                                    routePoint.images.remove(path); // Correctly update list
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Ensures proper alignment
                children: [
                  // Delete button (left-aligned)
                  TextButton(
                    onPressed: () {
                      onDelete(); // Call the delete callback
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  // Save button (right-aligned)
                  TextButton(
                    onPressed: () {
                      onSave(); // Call the save callback
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}
