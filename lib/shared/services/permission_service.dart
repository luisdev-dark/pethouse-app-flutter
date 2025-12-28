import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> requestPhotos() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    if (Platform.isAndroid) {
      final sdk = _androidSdkInt();
      final permission =
          sdk >= 33 ? Permission.photos : Permission.storage;
      final status = await permission.request();
      return status.isGranted;
    }
    return false;
  }

  int _androidSdkInt() {
    final match =
        RegExp(r'SDK\s+(\d+)').firstMatch(Platform.operatingSystemVersion);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }
}
