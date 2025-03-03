import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'route_point.g.dart';

@HiveType(typeId: 3)
class RoutePoint {
  // Internal field to store the point as a List of doubles [latitude, longitude]
  @HiveField(0)
  List<double> _point = [0.0, 0.0]; // This stores latitude and longitude as doubles

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  List<String> images;

  @HiveField(4)
  DateTime? date;

  // Use a getter and setter for LatLng point
  LatLng get point => LatLng(_point[0], _point[1]);
  set point(LatLng newPoint) => _point = [newPoint.latitude, newPoint.longitude];

  // Computed property (not stored in Hive)
  bool get hasInfo => title.isNotEmpty || description.isNotEmpty || date != null || images.isNotEmpty;

  // Constructor - now `point` is optional
  RoutePoint({
    LatLng? point,
    this.title = '',
    this.description = '',
    this.images = const [],
    this.date,
  }) {
    // If `point` is given, set `_point`, otherwise use the default value
    if (point != null) {
      _point = [point.latitude, point.longitude];
    }
  }
}
