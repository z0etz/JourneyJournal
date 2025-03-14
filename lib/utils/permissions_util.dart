import 'package:permission_handler/permission_handler.dart';

class PermissionsUtil {
  static Future<bool> requestPermissions() async {
    PermissionStatus status = await Permission.storage.request();
    return status.isGranted;
  }
}
