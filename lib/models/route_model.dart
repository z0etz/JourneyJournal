import 'package:hive/hive.dart';
import 'package:journeyjournal/models/route_point.dart';

part 'route_model.g.dart'; // This will be generated

@HiveType(typeId: 1)
class RouteModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<RoutePoint> routePoints = [];

  RouteModel({
    required this.id,
    required this.name,
    List<RoutePoint>? routePoints,
  }) : routePoints = routePoints ?? [];

  // Static method to get the box of routes
  static Future<Box<RouteModel>> getRoutesBox() async {
    return await Hive.openBox<RouteModel>('routesBox');
  }

  // Method to generate a unique route name
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

  // Save method to update or add a new route in the Hive box
  Future<void> save() async {
    final box = await RouteModel.getRoutesBox();
    box.put(id, this);
  }

  // Method to create and save a new route in the Hive box
  static Future<RouteModel> createNewRoute() async {
    final box = await RouteModel.getRoutesBox();
    String routeName = getNewRouteName(box.values.toList());
    String routeId = DateTime.now().millisecondsSinceEpoch.toString(); // Unique ID based on timestamp
    RouteModel newRoute = RouteModel(id: routeId, name: routeName, routePoints: []);
    await box.put(newRoute.id, newRoute); // Save to the box
    return newRoute;
  }

  // Load all routes from Hive
  static Future<List<RouteModel>> loadRoutes() async {
    final box = await RouteModel.getRoutesBox();
    return box.values.toList(); // Get all routes from the box
  }

  // Load a specific route from Hive by ID
  static Future<RouteModel?> loadRouteById(String id) async {
    final box = await RouteModel.getRoutesBox();
    return box.get(id);
  }
}
