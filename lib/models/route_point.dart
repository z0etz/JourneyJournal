import 'package:latlong2/latlong.dart';

class RoutePoint {
  LatLng point;          // Geographical location of the marker
  String title;          // Title of the marker
  String description;    // Description of the marker
  List<String> images;   // List of image URLs (or paths)
  String date;           // Date associated with the marker

  // Constructor to initialize the RoutePoint
  RoutePoint({
    required this.point,
    this.title = '',
    this.description = '',
    this.images = const [],
    this.date = '',
  });
}

// import 'package:latlong2/latlong.dart';
//
// class RoutePoint {
//   LatLng point;          // Geographical location of the marker
//   String title;          // Title of the marker
//   String description;    // Description of the marker
//   List<String> images;   // List of image URLs (or paths)
//   DateTime? date;        // Date associated with the marker (nullable)
//
//   // Constructor to initialize the RoutePoint
//   RoutePoint({
//     required this.point,
//     this.title = '',
//     this.description = '',
//     this.images = const [],
//     this.date,
//   });
// }
