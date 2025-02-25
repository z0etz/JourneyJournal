import 'package:hive/hive.dart';
import 'package:journeyjournal/models/route_point.dart';

part 'route.g.dart';  // This will be generated

@HiveType(typeId: 0)
class RouteModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final List<RoutePoint> routePoints;

  RouteModel({required this.id, required this.name, required this.routePoints});

  // Static list to store routes (You can remove this if using Hive for persistent storage)
  static List<RouteModel> savedRoutes = [];

  // Method to generate a unique route name
  static String getNewRouteName() {
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

  // Save method to update an existing route
  void save() {
    int index = savedRoutes.indexWhere((route) => route.id == id);
    if (index >= 0) {
      savedRoutes[index] = this;
    }
  }

  // Method to create and save a new route
  static RouteModel createNewRoute() {
    String routeName = getNewRouteName();
    String routeId = DateTime.now().millisecondsSinceEpoch.toString(); // Unique ID based on timestamp
    RouteModel newRoute = RouteModel(id: routeId, name: routeName, routePoints: []);
    savedRoutes.add(newRoute);
    return newRoute;
  }
}
