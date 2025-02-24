import 'dart:math';
import 'package:latlong2/latlong.dart';

// Calculates the distance from a point to a line segment
double distanceToSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
  double x1 = lineStart.latitude, y1 = lineStart.longitude;
  double x2 = lineEnd.latitude, y2 = lineEnd.longitude;
  double x0 = point.latitude, y0 = point.longitude;

  double dx = x2 - x1;
  double dy = y2 - y1;
  double lengthSquared = dx * dx + dy * dy;

  if (lengthSquared == 0) {
    return distance(x0, y0, x1, y1);
  }

  double t = ((x0 - x1) * dx + (y0 - y1) * dy) / lengthSquared;

  if (t < 0) {
    return distance(x0, y0, x1, y1);
  } else if (t > 1) {
    return distance(x0, y0, x2, y2);
  } else {
    double px = x1 + t * dx;
    double py = y1 + t * dy;
    return distance(x0, y0, px, py);
  }
}

// Calculate the distance between two points
double distance(double x1, double y1, double x2, double y2) {
  return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
}

// Adds a marker between two points if the tap is near the polyline
int findInsertIndex(LatLng tapPoint, List<LatLng> routePoints) {
  double minDistance = double.infinity;
  int insertIndex = -1;

  // Find the closest segment to the tapped point
  for (int i = 0; i < routePoints.length - 1; i++) {
    LatLng point1 = routePoints[i];
    LatLng point2 = routePoints[i + 1];

    double distance = distanceToSegment(tapPoint, point1, point2);
    if (distance < minDistance) {
      minDistance = distance;
      insertIndex = i + 1; // Insert between point1 and point2
    }
  }

  return insertIndex;
}

// Helper method to check if a tap is near the polyline
bool isTappedOnPolyline(LatLng tapPoint, List<LatLng> routePoints) {
  for (int i = 0; i < routePoints.length - 1; i++) {
    LatLng point1 = routePoints[i];
    LatLng point2 = routePoints[i + 1];

    double distance = distanceToSegment(tapPoint, point1, point2);
    if (distance < 20) {  // Threshold to detect tapping near polyline
      return true;
    }
  }
  return false;
}
