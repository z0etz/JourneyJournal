import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'route_point.g.dart';

@HiveType(typeId: 1)
class RoutePoint {
  // Store the coordinates as a List of doubles [latitude, longitude]
  @HiveField(0)
  List<double> _point; // Internal storage for the coordinates

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  List<String> images;

  @HiveField(4)
  DateTime? date;

  RoutePoint({
    required LatLng point,  // Accept LatLng in constructor
    this.title = '',
    this.description = '',
    this.images = const [],
    this.date,
  }) : _point = [point.latitude, point.longitude];  // Convert to List<double> for storage

  // Getter for LatLng to be used when needed
  LatLng get latLng => LatLng(_point[0], _point[1]);

  // Optional: Setter for LatLng (if you need to update the point after instantiation)
  set latLng(LatLng newPoint) {
    _point = [newPoint.latitude, newPoint.longitude];
  }
}
