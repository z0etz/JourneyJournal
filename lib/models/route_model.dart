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

  RouteModel({
    required this.id,
    required this.name,
    List<RoutePoint>? routePoints,
    String? startPointId,
    String? endPointId,
  })  : routePoints = routePoints ?? [],
        startPointId = startPointId ?? (routePoints != null && routePoints.isNotEmpty ? routePoints.first.id : ''),
        endPointId = endPointId ?? (routePoints != null && routePoints.isNotEmpty ? routePoints.last.id : '');

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
      if (!routePoints.any((p) => p.id == startPointId)) {
        startPointId = routePoints.first.id;
      }
      if (!routePoints.any((p) => p.id == endPointId)) {
        endPointId = routePoints.last.id;
      }
    } else {
      startPointId = '';
      endPointId = '';
    }
    await box.put(id, this);
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
        if (!route.routePoints.any((p) => p.id == route.startPointId)) {
          route.startPointId = route.routePoints.first.id;
          needsSave = true;
        }
        if (!route.routePoints.any((p) => p.id == route.endPointId)) {
          route.endPointId = route.routePoints.last.id;
          needsSave = true;
        }
      } else {
        if (route.startPointId.isNotEmpty || route.endPointId.isNotEmpty) {
          route.startPointId = '';
          route.endPointId = '';
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
        if (!route.routePoints.any((p) => p.id == route.startPointId)) {
          route.startPointId = route.routePoints.first.id;
          needsSave = true;
        }
        if (!route.routePoints.any((p) => p.id == route.endPointId)) {
          route.endPointId = route.routePoints.last.id;
          needsSave = true;
        }
      } else {
        if (route.startPointId.isNotEmpty || route.endPointId.isNotEmpty) {
          route.startPointId = '';
          route.endPointId = '';
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