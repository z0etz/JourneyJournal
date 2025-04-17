import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/map_utils.dart';
import 'package:journeyjournal/utils/video_util.dart';
import 'package:geolocator/geolocator.dart';

class AnimationScreen extends StatefulWidget {
  final RouteModel? initialRoute;
  final Function(bool)? onSavingChanged;

  const AnimationScreen({
    super.key,
    this.initialRoute,
    this.onSavingChanged,
  });

  @override
  State<AnimationScreen> createState() => _AnimationScreenState();
}

class _AnimationScreenState extends State<AnimationScreen> with TickerProviderStateMixin {
  late RouteModel currentRoute;
  bool _isAnimating = false;
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false);
  bool _isControlsExpanded = false;
  bool _showRouteTitles = false;
  bool _showWholeRoute = true;
  String _selectedAspectRatio = "9:16";
  bool _selectingStart = false;
  bool _selectingEnd = false;

  final MapController _mapController = MapController();
  double zoomLevel = 10.0;
  double fitZoom = 10.0;
  LatLng mapPosition = LatLng(59.322, 17.888);

  GlobalKey repaintBoundaryKey = GlobalKey();
  int frameCount = 100;

  final ValueNotifier<LatLng> _circlePositionNotifier = ValueNotifier<LatLng>(LatLng(0.0, 0.0));
  final ValueNotifier<double> _markerSizeNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _directionNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _saveDirectionNotifier = ValueNotifier<double>(0.0);

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  final Duration _animationDuration = const Duration(seconds: 5);
  double _totalDistance = 0.0;
  static const double markerBaseSize = 25.0;

  double _getAspectRatioValue() {
    switch (_selectedAspectRatio) {
      case "16:9":
        return 16 / 9;
      case "3:2":
        return 3 / 2;
      case "2:3":
        return 2 / 3;
      case "1:1":
        return 1.0;
      case "9:16":
      default:
        return 9 / 16;
    }
  }

  void _handleMarkerTap(int index) {
    setState(() {
      if (_selectingStart) {
        if (currentRoute.endIndex == -1 || index < currentRoute.endIndex) {
          currentRoute.setStartPointId(currentRoute.routePoints[index].id);
          _totalDistance = calculateTotalDistance(
            currentRoute,
            startIndex: currentRoute.startIndex,
            endIndex: currentRoute.endIndex,
          );
          _setInitialCirclePosition();
          _selectingStart = false;
          if (!_showWholeRoute) {
            _fitMapToRoute();
          }
        }
      } else if (_selectingEnd) {
        if (currentRoute.startIndex == -1 || index > currentRoute.startIndex) {
          currentRoute.setEndPointId(currentRoute.routePoints[index].id);
          _totalDistance = calculateTotalDistance(
            currentRoute,
            startIndex: currentRoute.startIndex,
            endIndex: currentRoute.endIndex,
          );
          _selectingEnd = false;
          if (!_showWholeRoute) {
            _fitMapToRoute();
          }
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    currentRoute = widget.initialRoute ?? RouteModel(id: '', name: '');
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (widget.initialRoute != null) {
      currentRoute = widget.initialRoute!;
    } else {
      var savedRoutes = await RouteModel.loadRoutes();
      if (savedRoutes.isEmpty) {
        currentRoute = await RouteModel.createNewRoute();
      } else {
        currentRoute = savedRoutes.last;
      }
    }

    if (currentRoute.routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToRoute();
      });
      _totalDistance = calculateTotalDistance(
        currentRoute,
        startIndex: currentRoute.startIndex,
        endIndex: currentRoute.endIndex,
      );
    }

    setState(() {});
  }

  void _fitMapToRoute() {
    if (currentRoute.routePoints.isEmpty) return;
    fitMapToRoute(
      _mapController,
      currentRoute.routePoints.map((rp) => rp.point).toList(),
      isAnimationScreen: true,
      startIndex: _showWholeRoute ? null : currentRoute.startIndex,
      endIndex: _showWholeRoute ? null : currentRoute.endIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          fitZoom = _mapController.camera.zoom;
          zoomLevel = _mapController.camera.zoom;
          mapPosition = _mapController.camera.center;
        });
        if (currentRoute.routePoints.isNotEmpty) {
          _setInitialCirclePosition();
        }
      });
    });
  }

  void _setInitialCirclePosition() {
    if (currentRoute.routePoints.isEmpty) return;
    LatLng startPoint = currentRoute.routePoints[currentRoute.startIndex].point;
    _circlePositionNotifier.value = startPoint;
    if (currentRoute.startIndex < currentRoute.endIndex && currentRoute.startIndex + 1 < currentRoute.routePoints.length) {
      LatLng nextPoint = currentRoute.routePoints[currentRoute.startIndex + 1].point;
      double initialDirection = atan2(
        nextPoint.longitude - startPoint.longitude,
        nextPoint.latitude - startPoint.latitude,
      );
      _directionNotifier.value = initialDirection;
      _saveDirectionNotifier.value = initialDirection;
    } else {
      _directionNotifier.value = 0.0;
      _saveDirectionNotifier.value = 0.0;
    }
  }

  void _toggleAnimation() {
    if (_isSavingNotifier.value || _isAnimating) {
      _isSavingNotifier.value = false;
      _animationController.stop();
      _animationController.reset();
      if (currentRoute.routePoints.isNotEmpty) {
        _circlePositionNotifier.value = currentRoute.routePoints[currentRoute.startIndex].point;
      }
      _markerSizeNotifier.value = 0.0;
      double initialDirection = currentRoute.startIndex < currentRoute.endIndex && currentRoute.startIndex + 1 < currentRoute.routePoints.length
          ? atan2(
        currentRoute.routePoints[currentRoute.startIndex + 1].point.longitude -
            currentRoute.routePoints[currentRoute.startIndex].point.longitude,
        currentRoute.routePoints[currentRoute.startIndex + 1].point.latitude -
            currentRoute.routePoints[currentRoute.startIndex].point.latitude,
      )
          : 0.0;
      _directionNotifier.value = initialDirection;
      _saveDirectionNotifier.value = initialDirection;
      setState(() {
        _isAnimating = false;
        _selectingStart = false;
        _selectingEnd = false;
      });
    } else if (currentRoute.routePoints.isNotEmpty) {
      setState(() {
        _isAnimating = true;
        _selectingStart = false;
        _selectingEnd = false;
      });
      _animateMarker();
    }
  }

  void _startSelectingStartPoint() {
    setState(() {
      if (_selectingStart) {
        _selectingStart = false;
      } else {
        _selectingStart = true;
        _selectingEnd = false;
      }
    });
  }

  void _startSelectingEndPoint() {
    setState(() {
      if (_selectingEnd) {
        _selectingEnd = false;
      } else {
        _selectingEnd = true;
        _selectingStart = false;
      }
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng tappedPoint) {
    if (currentRoute.routePoints.isEmpty || _isSavingNotifier.value || _isAnimating || (!_selectingStart && !_selectingEnd)) return;

    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < currentRoute.routePoints.length; i++) {
      double distance = Geolocator.distanceBetween(
        tappedPoint.latitude,
        tappedPoint.longitude,
        currentRoute.routePoints[i].point.latitude,
        currentRoute.routePoints[i].point.longitude,
      );
      if (distance < minDistance && distance < 50) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (minDistance >= 50) return;

    setState(() {
      if (_selectingStart) {
        if (currentRoute.endIndex == -1 || closestIndex < currentRoute.endIndex) {
          currentRoute.setStartPointId(currentRoute.routePoints[closestIndex].id);
          _totalDistance = calculateTotalDistance(
            currentRoute,
            startIndex: currentRoute.startIndex,
            endIndex: currentRoute.endIndex,
          );
          _setInitialCirclePosition();
          _selectingStart = false;
          if (!_showWholeRoute) {
            _fitMapToRoute();
          }
        }
      } else if (_selectingEnd) {
        if (currentRoute.startIndex == -1 || closestIndex > currentRoute.startIndex) {
          currentRoute.setEndPointId(currentRoute.routePoints[closestIndex].id);
          _totalDistance = calculateTotalDistance(
            currentRoute,
            startIndex: currentRoute.startIndex,
            endIndex: currentRoute.endIndex,
          );
          _setInitialCirclePosition();
          _selectingEnd = false;
          if (!_showWholeRoute) {
            _fitMapToRoute();
          }
        }
      }
    });
  }

  void _animateMarker() {
    if (!_isAnimating || currentRoute.routePoints.length < 2 || currentRoute.startIndex < 0 || currentRoute.endIndex <= currentRoute.startIndex || currentRoute.endIndex >= currentRoute.routePoints.length) {
      setState(() {
        _isAnimating = false;
      });
      return;
    }

    final previewDuration = Duration(
      milliseconds: _animationDuration.inMilliseconds - 2000,
    );
    final scaleFactor = previewDuration.inMilliseconds / _animationDuration.inMilliseconds;

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0 / scaleFactor).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );

    _markerSizeNotifier.value = markerBaseSize;
    LatLng? lastPosition;
    _progressAnimation.addListener(() {
      double scaledProgress = _progressAnimation.value * scaleFactor;
      moveCircleAlongPath(
        scaledProgress,
        currentRoute,
        _circlePositionNotifier,
        _totalDistance,
        startIndex: currentRoute.startIndex,
        endIndex: currentRoute.endIndex,
      );
      LatLng currentPosition = _circlePositionNotifier.value;
      if (lastPosition != null) {
        double deltaLat = currentPosition.latitude - lastPosition!.latitude;
        double deltaLng = currentPosition.longitude - lastPosition!.longitude;
        _directionNotifier.value = atan2(deltaLng, deltaLat);
      }
      lastPosition = currentPosition;
    });

    _animationController.reset();
    _animationController.forward().then((_) {
      _markerSizeNotifier.value = 0.0;
      if (currentRoute.endIndex > currentRoute.startIndex && currentRoute.endIndex < currentRoute.routePoints.length) {
        LatLng secondLast = currentRoute.routePoints[currentRoute.endIndex - 1].point;
        LatLng last = currentRoute.routePoints[currentRoute.endIndex].point;
        _directionNotifier.value = atan2(
          last.longitude - secondLast.longitude,
          last.latitude - secondLast.latitude,
        );
      } else {
        _directionNotifier.value = 0.0;
      }
      setState(() {
        _isAnimating = false;
      });
    });
  }

  List<Marker> _buildMarkers({bool isSaving = false}) {
    final List<Marker> markers = [];
    final int startIndex = currentRoute.startIndex;
    final int endIndex = currentRoute.endIndex;

    for (int i = 0; i < currentRoute.routePoints.length; i++) {
      if (isSaving && !_showWholeRoute && (i < startIndex || i > endIndex)) {
        continue;
      }
      final routePoint = currentRoute.routePoints[i];
      markers.add(
        Marker(
          point: routePoint.point,
          width: 150.0,
          height: 50.0,
          child: GestureDetector(
            onTap: () {
              if (_isSavingNotifier.value || _isAnimating) return;
              _handleMarkerTap(i);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.circle,
                  color: i == startIndex
                      ? const Color(0xFF4c8d40)
                      : i == endIndex
                      ? const Color(0xFFde3a71)
                      : Colors.blue,
                  size: 15.0,
                ),
                if (_showRouteTitles && routePoint.title.isNotEmpty)
                  Positioned(
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black54, width: 1),
                      ),
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        routePoint.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  List<PolylineLayer> _buildPolylines({bool isSaving = false}) {
    if (currentRoute.routePoints.isEmpty) return [];

    final int startIndex = currentRoute.startIndex;
    final int endIndex = currentRoute.endIndex;

    final effectivePoints = (isSaving && !_showWholeRoute && startIndex >= 0 && endIndex < currentRoute.routePoints.length && startIndex <= endIndex)
        ? currentRoute.routePoints.sublist(startIndex, endIndex + 1).map((rp) => rp.point).toList()
        : currentRoute.routePoints.map((rp) => rp.point).toList();

    return [
      PolylineLayer(
        polylines: [
          Polyline(
            points: effectivePoints,
            color: Colors.blue,
            strokeWidth: 4.0,
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _isSavingNotifier.dispose();
    _circlePositionNotifier.dispose();
    _markerSizeNotifier.dispose();
    _directionNotifier.dispose();
    _saveDirectionNotifier.dispose();
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSavingNotifier.value,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Route Animation"),
          actions: [
            IconButton(
              icon: Icon(_isControlsExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
              onPressed: () {
                setState(() {
                  _isControlsExpanded = !_isControlsExpanded;
                });
              },
            ),
          ],
        ),
        body: currentRoute.routePoints.isEmpty
            ? const Center(child: Text("Choose a non-empty route to animate."))
            : Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    key: repaintBoundaryKey,
                    child: AspectRatio(
                      aspectRatio: _getAspectRatioValue(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FlutterMap(
                          key: ValueKey(_selectedAspectRatio),
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: mapPosition,
                            initialZoom: zoomLevel,
                            onPositionChanged: (position, hasGesture) {
                              if (!_isSavingNotifier.value) {
                                setState(() {
                                  zoomLevel = position.zoom;
                                  mapPosition = position.center;
                                });
                              }
                            },
                            onTap: _handleMapTap,
                            interactionOptions: _isSavingNotifier.value
                                ? const InteractionOptions(flags: InteractiveFlag.none)
                                : const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isSavingNotifier,
                              builder: (context, isSaving, child) {
                                return PolylineLayer(
                                  polylines: _buildPolylines(isSaving: isSaving)
                                      .map((layer) => layer.polylines)
                                      .expand((i) => i)
                                      .toList(),
                                );
                              },
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isSavingNotifier,
                              builder: (context, isSaving, child) {
                                return MarkerLayer(
                                  markers: _buildMarkers(isSaving: isSaving),
                                );
                              },
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isSavingNotifier,
                              builder: (context, isSaving, child) {
                                if (isSaving) return const SizedBox.shrink();
                                return ValueListenableBuilder<LatLng>(
                                  valueListenable: _circlePositionNotifier,
                                  builder: (context, position, child) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _markerSizeNotifier,
                                      builder: (context, size, child) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable: _directionNotifier,
                                          builder: (context, direction, child) {
                                            return MarkerLayer(
                                              markers: [
                                                if (size > 0.0)
                                                  Marker(
                                                    point: position,
                                                    width: size,
                                                    height: size,
                                                    child: Transform.rotate(
                                                      angle: direction,
                                                      child: Icon(
                                                        Icons.navigation,
                                                        color: Colors.orange,
                                                        size: size,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isSavingNotifier,
                              builder: (context, isSaving, child) {
                                if (!isSaving) return const SizedBox.shrink();
                                return ValueListenableBuilder<LatLng>(
                                  valueListenable: _circlePositionNotifier,
                                  builder: (context, position, child) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _markerSizeNotifier,
                                      builder: (context, size, child) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable: _saveDirectionNotifier,
                                          builder: (context, direction, child) {
                                            return MarkerLayer(
                                              markers: [
                                                if (size > 0.0)
                                                  Marker(
                                                    point: position,
                                                    width: size,
                                                    height: size,
                                                    child: Transform.rotate(
                                                      angle: direction,
                                                      child: Icon(
                                                        Icons.navigation,
                                                        color: Colors.orange,
                                                        size: size,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isControlsExpanded)
              Positioned(
                top: 0,
                left: 10.0,
                right: 10.0,
                child: Material(
                  color: (Theme.of(context).appBarTheme.backgroundColor ?? Colors.white).withValues(alpha: 0.8),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).appBarTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: AbsorbPointer(
                          absorbing: _isSavingNotifier.value,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton(
                                    onPressed: _isSavingNotifier.value || _isAnimating ? null : _startSelectingStartPoint,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectingStart ? Colors.green[100] : null,
                                    ),
                                    child: const Text("Set Start Point"),
                                  ),
                                  ElevatedButton(
                                    onPressed: _isSavingNotifier.value || _isAnimating ? null : _startSelectingEndPoint,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectingEnd ? Colors.red[100] : null,
                                    ),
                                    child: const Text("Set End Point"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text("Animation Duration"),
                              Slider(
                                value: _animationController.duration!.inSeconds.toDouble(),
                                min: 5,
                                max: 60,
                                divisions: 56,
                                label: "${_animationController.duration!.inSeconds}s",
                                onChanged: _isSavingNotifier.value
                                    ? null
                                    : (value) {
                                  setState(() {
                                    _animationController.duration = Duration(seconds: value.toInt());
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Text('Zoom Level: ${zoomLevel.toStringAsFixed(1)}'),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Show routepoint titles"),
                                  Switch(
                                    value: _showRouteTitles,
                                    onChanged: _isSavingNotifier.value
                                        ? null
                                        : (value) {
                                      setState(() {
                                        _showRouteTitles = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Zoom to whole route"),
                                  Switch(
                                    value: _showWholeRoute,
                                    onChanged: _isSavingNotifier.value
                                        ? null
                                        : (value) {
                                      setState(() {
                                        _showWholeRoute = value;
                                        _fitMapToRoute();
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text("Aspect Ratio"),
                              DropdownButton<String>(
                                value: _selectedAspectRatio,
                                items: ["9:16", "16:9", "3:2", "2:3", "1:1"].map((ratio) {
                                  return DropdownMenuItem<String>(
                                    value: ratio,
                                    child: Text(ratio),
                                  );
                                }).toList(),
                                onChanged: _isSavingNotifier.value
                                    ? null
                                    : (value) {
                                  setState(() {
                                    _selectingStart = false;
                                    _selectingEnd = false;
                                    _selectedAspectRatio = value!;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _fitMapToRoute();
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: SaveButton(
                                  mapKey: repaintBoundaryKey,
                                  frameCount: frameCount,
                                  animationController: _animationController,
                                  circlePositionNotifier: _circlePositionNotifier,
                                  aspectRatio: _selectedAspectRatio,
                                  mapController: _mapController,
                                  currentRoute: currentRoute,
                                  initialZoom: zoomLevel,
                                  fitZoom: fitZoom,
                                  markerSizeNotifier: _markerSizeNotifier,
                                  directionNotifier: _directionNotifier,
                                  saveDirectionNotifier: _saveDirectionNotifier,
                                  showWholeRoute: _showWholeRoute,
                                  onSaveStart: () {
                                    _isSavingNotifier.value = true;
                                    widget.onSavingChanged?.call(true);
                                  },
                                  onSaveComplete: () {
                                    _isSavingNotifier.value = false;
                                    widget.onSavingChanged?.call(false);
                                  },
                                  isSavingNotifier: _isSavingNotifier,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isSavingNotifier.value)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4.0,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleAnimation,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isSavingNotifier,
            builder: (context, isSaving, child) {
              return Icon(isSaving ? Icons.stop : _isAnimating ? Icons.stop : Icons.play_arrow);
            },
          ),
        ),
      ),
    );
  }
}