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
  int startIndex;

  @HiveField(4)
  int endIndex;

  RouteModel({
    required this.id,
    required this.name,
    List<RoutePoint>? routePoints,
    int startIndex = 0,
    int endIndex = -1,
  })  : routePoints = routePoints ?? [],
        startIndex = startIndex >= 0 ? startIndex : 0,
        endIndex = routePoints != null && routePoints.isNotEmpty
            ? (endIndex >= 0 ? endIndex : routePoints.length - 1)
            : 0 {
    // Ensure valid indices
    if (this.routePoints.isNotEmpty) {
      this.startIndex = this.startIndex.clamp(0, this.routePoints.length - 1);
      this.endIndex = this.endIndex.clamp(this.startIndex, this.routePoints.length - 1);
    } else {
      this.startIndex = 0;
      this.endIndex = 0;
    }
  }

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
      startIndex = startIndex.clamp(0, routePoints.length - 1);
      endIndex = endIndex.clamp(startIndex, routePoints.length - 1);
    } else {
      startIndex = 0;
      endIndex = 0;
    }
    box.put(id, this);
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
        if (route.startIndex < 0 || route.startIndex >= route.routePoints.length) {
          route.startIndex = 0;
          needsSave = true;
        }
        if (route.endIndex < route.startIndex || route.endIndex >= route.routePoints.length) {
          route.endIndex = route.routePoints.length - 1;
          needsSave = true;
        }
      } else {
        if (route.startIndex != 0 || route.endIndex != 0) {
          route.startIndex = 0;
          route.endIndex = 0;
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
        if (route.startIndex < 0 || route.startIndex >= route.routePoints.length) {
          route.startIndex = 0;
          needsSave = true;
        }
        if (route.endIndex < route.startIndex || route.endIndex >= route.routePoints.length) {
          route.endIndex = route.routePoints.length - 1;
          needsSave = true;
        }
      } else {
        if (route.startIndex != 0 || route.endIndex != 0) {
          route.startIndex = 0;
          route.endIndex = 0;
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