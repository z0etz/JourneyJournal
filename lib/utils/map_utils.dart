import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:journeyjournal/utils/image_helper.dart';
import '../models/image_data.dart';

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

void fitMapToRoute(
    MapController mapController,
    List<LatLng> points, {
      bool isAnimationScreen = false,
      int? startIndex,
      int? endIndex,
    }) {
  if (points.isEmpty) return;

  List<LatLng> effectivePoints = points;
  if (startIndex != null &&
      endIndex != null &&
      startIndex >= 0 &&
      endIndex < points.length &&
      startIndex <= endIndex) {
    effectivePoints = points.sublist(startIndex, endIndex + 1);
  }

  if (effectivePoints.isEmpty) return;

  LatLngBounds bounds = LatLngBounds.fromPoints(effectivePoints);

  // Compute center of bounds
  LatLng center = LatLng(
    (bounds.north + bounds.south) / 2,
    (bounds.east + bounds.west) / 2,
  );

  // Define padding (prevents points from being too close to screen edges)
  double padding = isAnimationScreen ? 50.0 : 100.0;
  double longitudeOffset = 0;

  // Apply an offset to shift the center leftward (westward) for MapScreen
  if (!isAnimationScreen) {
    longitudeOffset = (bounds.east - bounds.west) * 0.375;
    padding = 150.0;
  }
  LatLng adjustedCenter = LatLng(center.latitude, center.longitude - longitudeOffset);

  mapController.fitCamera(
    CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.all(padding),
    ),
  );

  // Move to the adjusted center after fitting bounds (only for MapScreen)
  if (!isAnimationScreen) {
    mapController.move(adjustedCenter, mapController.camera.zoom);
  }
}

Future<void> showRoutePointDialog(
    BuildContext context,
    RoutePoint routePoint, {
      required TextEditingController titleController,
      required TextEditingController descriptionController,
      DateTime? selectedDate,
      required Function() onDelete,
      required Function() onSave,
      List<String> availableTags = const ['highlight'], // From RouteModel.tags
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
                            routePoint.images.add(ImageData(
                              path: savedPath,
                              order: routePoint.images.length,
                            ));
                          });
                        }
                      }
                    },
                    child: const Text(
                      'Add Images',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ReorderableListView(
                      shrinkWrap: true,
                      children: routePoint.images.map((img) {
                        final key = ValueKey(img.path);
                        return ListTile(
                          key: key,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                          leading: Image.file(
                            File(img.path),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                          title: Wrap(
                            spacing: 8,
                            children: img.tags.map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                setDialogState(() {
                                  img.tags.remove(tag);
                                });
                              },
                            )).toList()..add(
                              Chip(
                                label: const Text('Add Tag'),
                                onPressed: () async {
                                  String? newTag = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Add Tag'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              children: availableTags.map((tag) => ChoiceChip(
                                                label: Text(tag),
                                                selected: false,
                                                onSelected: (_) {
                                                  Navigator.pop(context, tag);
                                                },
                                              )).toList(),
                                            ),
                                            TextField(
                                              autofocus: true,
                                              decoration: const InputDecoration(
                                                labelText: 'Custom Tag',
                                              ),
                                              onSubmitted: (value) {
                                                Navigator.pop(context, value.trim());
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (newTag != null && newTag.isNotEmpty) {
                                    setDialogState(() {
                                      img.tags.add(newTag);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final file = File(img.path);
                              if (await file.exists()) {
                                await file.delete();
                              }
                              setDialogState(() {
                                routePoint.images.remove(img);
                              });
                            },
                          ),
                        );
                      }).toList(),
                      onReorder: (oldIndex, newIndex) {
                        setDialogState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final img = routePoint.images.removeAt(oldIndex);
                          routePoint.images.insert(newIndex, img);
                          for (int i = 0; i < routePoint.images.length; i++) {
                            routePoint.images[i].order = i;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      onDelete();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSave();
                      Navigator.of(context).pop();
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