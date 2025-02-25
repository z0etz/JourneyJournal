import 'package:journeyjournal/models/route_point.dart';

class RouteModel {
  String id;
  String name;
  List<RoutePoint> routePoints;

  RouteModel({required this.id, required this.name, required this.routePoints});

  // Static list to store routes
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

  // Save method to update existing route
  void save() {
    int index = savedRoutes.indexWhere((route) => route.id == this.id);
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
