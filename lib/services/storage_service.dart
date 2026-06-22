import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Copies files into the shared Pictures/Download folders so they show up
/// outside the app (gallery, file manager, etc).
class StorageService {
  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    // Android 13+ uses granular media permissions; older versions use
    // the legacy storage permission. Try both since we don't know the
    // OS version up front.
    final photos = await Permission.photos.request();
    if (photos.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  /// Returns the shared storage root (e.g. /storage/emulated/0), derived
  /// from the app-specific external directory path.
  Future<Directory?> _sharedStorageRoot() async {
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) return null;
    final androidIndex = extDir.path.indexOf('Android');
    if (androidIndex == -1) return null;
    return Directory(extDir.path.substring(0, androidIndex));
  }

  /// Copies [imagePath] into Pictures/OfficeScanner. Returns false if the
  /// permission is denied or the OS refuses the direct write (scoped
  /// storage on Android 10+ can reject this even with permission granted).
  Future<bool> saveImageToGallery(String imagePath) async {
    if (!await _ensureStoragePermission()) return false;
    try {
      final root = await _sharedStorageRoot();
      if (root == null) return false;
      final picturesDir = Directory('${root.path}/Pictures/OfficeScanner');
      await picturesDir.create(recursive: true);
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(imagePath).copy('${picturesDir.path}/$fileName');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Copies [file] into the shared Download folder. Returns the new File on
  /// success, or null if the permission is denied or the write fails.
  Future<File?> saveFileToDownloads(File file) async {
    if (!await _ensureStoragePermission()) return null;
    try {
      final root = await _sharedStorageRoot();
      if (root == null) return null;
      final downloadsDir = Directory('${root.path}/Download');
      await downloadsDir.create(recursive: true);
      final fileName = file.path.split(Platform.pathSeparator).last;
      return await file.copy('${downloadsDir.path}/$fileName');
    } catch (_) {
      return null;
    }
  }
}
