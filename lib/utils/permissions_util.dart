import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionsUtil {
  // Request permissions for Android 11+ (scoped storage)
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 11+ (API 30+), no broad storage permission needed for app-specific dirs
      // Check if we need media access for shared storage (optional)
      PermissionStatus status = await Permission.photos.request(); // For Media Store access
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        openAppSettings(); // Prompt user to enable manually
        return false;
      }
      return false;
    }
    return true; // iOS or other platforms may not need this
  }
}