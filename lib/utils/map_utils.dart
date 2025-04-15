import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/models/route_model.dart';
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

Future<void> showImageTagDialog(
    BuildContext context,
    ImageData image,
    RouteModel routeModel, {
      List<String> availableTags = const ['highlight'],
    }) {
  TextEditingController tagController = TextEditingController();
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Tags'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: image.tags.map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () {
                        setDialogState(() {
                          image.tags.remove(tag);
                        });
                        routeModel.save(); // Update RouteModel.tags
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags
                        .where((tag) => !image.tags.contains(tag))
                        .map((tag) => ChoiceChip(
                      label: Text(tag),
                      selected: false,
                      onSelected: (_) {
                        setDialogState(() {
                          image.tags.add(tag);
                        });
                        routeModel.save(); // Update RouteModel.tags
                      },
                    ))
                        .toList(),
                  ),
                  TextField(
                    controller: tagController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Custom Tag',
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () {
                      final newTag = tagController.text.trim();
                      if (newTag.isNotEmpty) {
                        setDialogState(() {
                          image.tags.add(newTag);
                        });
                        routeModel.save(); // Update RouteModel.tags
                        tagController.clear();
                      }
                    },
                    child: const Text('Add'),
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

Future<void> showRoutePointDialog(
    BuildContext context,
    RoutePoint routePoint,
    RouteModel routeModel, {
      required TextEditingController titleController,
      required TextEditingController descriptionController,
      DateTime? selectedDate,
      required Function() onDelete,
      required Function() onSave,
      List<String> availableTags = const ['highlight'],
    }) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      ImageData? draggingImage;
      Offset? dragPosition;
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
                              tags: [], // Explicitly initialize tags
                            ));
                          });
                        }
                        routeModel.save(); // Save to ensure new images persist
                      }
                    },
                    child: const Text(
                      'Add Images',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: routePoint.images.asMap().entries.map((entry) {
                          final index = entry.key;
                          final img = entry.value;
                          final key = ValueKey(img.path);
                          bool isDraggingThis = draggingImage == img;
                          return GestureDetector(
                            key: key,
                            onLongPressStart: (details) {
                              setDialogState(() {
                                draggingImage = img;
                                dragPosition = details.globalPosition;
                              });
                            },
                            onLongPressMoveUpdate: (details) {
                              setDialogState(() {
                                dragPosition = details.globalPosition;
                              });
                            },
                            onLongPressEnd: (details) {
                              if (dragPosition != null) {
                                final RenderBox box = context.findRenderObject() as RenderBox;
                                final localPosition = box.globalToLocal(details.globalPosition);
                                final imageWidth = 80 + 8; // Image size + spacing
                                final imagesPerRow = (constraints.maxWidth / imageWidth).floor();
                                final row = (localPosition.dy / (80 + 8)).floor();
                                final col = (localPosition.dx / imageWidth).floor();
                                final newIndex = row * imagesPerRow + col;
                                if (newIndex >= 0 && newIndex < routePoint.images.length && newIndex != index) {
                                  setDialogState(() {
                                    final movedImg = routePoint.images.removeAt(index);
                                    routePoint.images.insert(newIndex, movedImg);
                                    for (int i = 0; i < routePoint.images.length; i++) {
                                      routePoint.images[i].order = i;
                                    }
                                  });
                                }
                              }
                              setDialogState(() {
                                draggingImage = null;
                                dragPosition = null;
                              });
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  child: Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          showImageTagDialog(
                                            context,
                                            img,
                                            routeModel,
                                            availableTags: routeModel.tags,
                                          ).then((_) {
                                            setDialogState(() {}); // Refresh dialog
                                          });
                                        },
                                        child: Opacity(
                                          opacity: isDraggingThis ? 0.3 : 1.0,
                                          child: Image.file(
                                            File(img.path),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final file = File(img.path);
                                            if (await file.exists()) {
                                              await file.delete();
                                            }
                                            setDialogState(() {
                                              routePoint.images.remove(img);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (img.tags.isNotEmpty)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            color: Colors.black54,
                                            child: const Icon(
                                              Icons.tag,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isDraggingThis && dragPosition != null)
                                  Positioned(
                                    left: dragPosition!.dx - 40,
                                    top: dragPosition!.dy - 40,
                                    child: Material(
                                      elevation: 4,
                                      child: Image.file(
                                        File(img.path),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSave();
                      Navigator.pop(context);
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