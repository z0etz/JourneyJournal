import 'package:permission_handler/permission_handler.dart';

class PermissionsUtil {
  // Request storage permissions (Android and iOS)
  static Future<bool> requestPermissions() async {
    // For Android: Request storage permission
    PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    } else {
      // Handle the case where permission is denied
      return false;
    }
  }
}
