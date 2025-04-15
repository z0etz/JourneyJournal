import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'image_data.dart';

part 'route_point.g.dart';

@HiveType(typeId: 3)
class RoutePoint {
  @HiveField(0)
  List<double> _point = [0.0, 0.0];

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  List<ImageData> images;

  @HiveField(4)
  DateTime? date;

  @HiveField(5)
  String id;

  RoutePoint({
    LatLng? point,
    this.title = '',
    this.description = '',
    List<ImageData>? images,
    this.date,
    required this.id,
  }) : images = images ?? [] {
    if (point != null) {
      _point = [point.latitude, point.longitude];
    }
  }

  // Use a getter and setter for LatLng point
  LatLng get point => LatLng(_point[0], _point[1]);
  set point(LatLng newPoint) => _point = [newPoint.latitude, newPoint.longitude];

  // Computed property (not stored in Hive)
  bool get hasInfo => title.isNotEmpty || description.isNotEmpty || date != null || images.isNotEmpty;
}