import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'route_point.g.dart'; // Add this to generate code for Hive

@HiveType(typeId: 1)  // Assign a unique typeId
class RoutePoint extends HiveObject {
  @HiveField(0)
  LatLng point;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  List<String> images;

  @HiveField(4)
  DateTime? date;

  RoutePoint({
    required this.point,
    this.title = '',
    this.description = '',
    this.images = const [],
    this.date,
  });
}
