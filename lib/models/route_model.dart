import 'package:hive/hive.dart';
import 'package:journeyjournal/models/route_point.dart';

part 'route_model.g.dart';

@HiveType(typeId: 1)
class RouteModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<RoutePoint> routePoints;

  @HiveField(3)
  String startPointId;

  @HiveField(4)
  String endPointId;

  @HiveField(5)
  bool snapStartToFirst;

  @HiveField(6)
  bool snapEndToLast;

  @HiveField(7)
  List<String> tags;

  @HiveField(8)
  int? animationDurationSeconds;

  @HiveField(9)
  String? aspectRatio;

  @HiveField(10)
  bool? showRouteTitles;

  @HiveField(11)
  bool? showWholeRoute;

  @HiveField(12)
  bool? showImages;

  @HiveField(13)
  double? imageLength;

  @HiveField(14)
  Map<String, int>? tagStates;

  RouteModel({
    required this.id,
    required this.name,
    List<RoutePoint>? routePoints,
    String? startPointId,
    String? endPointId,
    this.snapStartToFirst = true,
    this.snapEndToLast = true,
    List<String>? tags,
    this.animationDurationSeconds = 5,
    this.aspectRatio = "9:16",
    this.showRouteTitles = false,
    this.showWholeRoute = true,
    this.showImages = false,
    this.imageLength = 3.0,
    this.tagStates,
  })  : routePoints = routePoints ?? [],
        startPointId = startPointId ?? (routePoints != null && routePoints.isNotEmpty ? routePoints.first.id : ''),
        endPointId = endPointId ?? (routePoints != null && routePoints.isNotEmpty ? routePoints.last.id : ''),
        tags = tags ?? ['highlight'];

  int get startIndex => routePoints.indexWhere((p) => p.id == startPointId);
  int get endIndex => routePoints.indexWhere((p) => p.id == endPointId);

  static Future<Box<RouteModel>> getRoutesBox() async {
    return await Hive.openBox<RouteModel>('routesBox');
  }

  static String getNewRouteName(List<RouteModel> savedRoutes) {
    List<int> usedNumbers = [];
    for (var route in savedRoutes) {
      final match = RegExp(r'Route (\d+)').firstMatch(route.name);
      if (match != null) {
        usedNumbers.add(int.parse(match.group(1)!));
      }
    }
    usedNumbers.sort();
    int nextAvailableNumber = 1;
    for (int num in usedNumbers) {
      if (num == nextAvailableNumber) {
        nextAvailableNumber++;
      }
    }
    return 'Route $nextAvailableNumber';
  }

  Future<void> save() async {
    final box = await RouteModel.getRoutesBox();
    if (routePoints.isNotEmpty) {
      if (snapStartToFirst || startPointId.isEmpty || !routePoints.any((p) => p.id == startPointId)) {
        startPointId = routePoints.first.id;
        snapStartToFirst = true;
      } else if (startPointId == routePoints.first.id) {
        snapStartToFirst = true;
      }
      if (snapEndToLast || endPointId.isEmpty || !routePoints.any((p) => p.id == endPointId)) {
        endPointId = routePoints.last.id;
        snapEndToLast = true;
      } else if (endPointId == routePoints.last.id) {
        snapEndToLast = true;
      }
    } else {
      startPointId = '';
      endPointId = '';
      snapStartToFirst = true;
      snapEndToLast = true;
    }
    final allTags = <String>{'highlight'};
    for (var point in routePoints) {
      for (var img in point.images) {
        allTags.addAll(img.tags);
      }
    }
    tags = allTags.toList()..sort();
    await box.put(id, this);
  }

  void setStartPointId(String newId) {
    startPointId = newId;
    snapStartToFirst = routePoints.isNotEmpty && newId == routePoints.first.id;
    save();
  }

  void setEndPointId(String newId) {
    endPointId = newId;
    snapEndToLast = routePoints.isNotEmpty && newId == routePoints.last.id;
    save();
  }

  static Future<RouteModel> createNewRoute() async {
    final box = await RouteModel.getRoutesBox();
    String routeName = getNewRouteName(box.values.toList());
    String routeId = DateTime.now().millisecondsSinceEpoch.toString();
    RouteModel newRoute = RouteModel(id: routeId, name: routeName);
    await box.put(newRoute.id, newRoute);
    return newRoute;
  }

  static Future<List<RouteModel>> loadRoutes() async {
    final box = await RouteModel.getRoutesBox();
    for (var route in box.values) {
      bool needsSave = false;
      if (route.routePoints.isNotEmpty) {
        if (route.snapStartToFirst || route.startPointId.isEmpty || !route.routePoints.any((p) => p.id == route.startPointId)) {
          route.startPointId = route.routePoints.first.id;
          route.snapStartToFirst = true;
          needsSave = true;
        } else if (route.startPointId == route.routePoints.first.id) {
          route.snapStartToFirst = true;
          needsSave = true;
        }
        if (route.snapEndToLast || route.endPointId.isEmpty || !route.routePoints.any((p) => p.id == route.endPointId)) {
          route.endPointId = route.routePoints.last.id;
          route.snapEndToLast = true;
          needsSave = true;
        } else if (route.endPointId == route.routePoints.last.id) {
          route.snapEndToLast = true;
          needsSave = true;
        }
      } else {
        if (route.startPointId.isNotEmpty || route.endPointId.isNotEmpty) {
          route.startPointId = '';
          route.endPointId = '';
          route.snapStartToFirst = true;
          route.snapEndToLast = true;
          needsSave = true;
        }
      }
      if (needsSave) {
        await route.save();
      }
    }
    return box.values.toList();
  }

  static Future<RouteModel?> loadRouteById(String id) async {
    final box = await RouteModel.getRoutesBox();
    var route = box.get(id);
    if (route != null) {
      bool needsSave = false;
      if (route.routePoints.isNotEmpty) {
        if (route.snapStartToFirst || route.startPointId.isEmpty || !route.routePoints.any((p) => p.id == route.startPointId)) {
          route.startPointId = route.routePoints.first.id;
          route.snapStartToFirst = true;
          needsSave = true;
        } else if (route.startPointId == route.routePoints.first.id) {
          route.snapStartToFirst = true;
          needsSave = true;
        }
        if (route.snapEndToLast || route.endPointId.isEmpty || !route.routePoints.any((p) => p.id == route.endPointId)) {
          route.endPointId = route.routePoints.last.id;
          route.snapEndToLast = true;
          needsSave = true;
        } else if (route.endPointId == route.routePoints.last.id) {
          route.snapEndToLast = true;
          needsSave = true;
        }
      } else {
        if (route.startPointId.isNotEmpty || route.endPointId.isNotEmpty) {
          route.startPointId = '';
          route.endPointId = '';
          route.snapStartToFirst = true;
          route.snapEndToLast = true;
          needsSave = true;
        }
      }
      if (needsSave) {
        await route.save();
      }
    }
    return route;
  }
}