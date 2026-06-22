import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const _appFolderName = 'Office Scanner';

  Future<Directory> _getPublicDir(String type) async {
    // Try public external storage first
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      // Go up to /storage/emulated/0/
      final parts = extDir.path.split('/');
      final androidIdx = parts.indexOf('Android');
      if (androidIdx != -1) {
        final root = parts.sublist(0, androidIdx).join('/');
        final dir = Directory('$root/$type/$_appFolderName');
        try {
          await dir.create(recursive: true);
          // Test if writable
          final testFile = File('${dir.path}/.test');
          await testFile.writeAsString('test');
          await testFile.delete();
          debugPrint('Using public dir: ${dir.path}');
          return dir;
        } catch (_) {}
      }
    }
    // Fallback — app specific external
    final appExtDir = await getExternalStorageDirectory();
    if (appExtDir != null) {
      final dir = Directory('${appExtDir.path}/$_appFolderName/$type');
      await dir.create(recursive: true);
      debugPrint('Using app external dir: ${dir.path}');
      return dir;
    }
    // Final fallback — internal
    final appDoc = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDoc.path}/$_appFolderName/$type');
    await dir.create(recursive: true);
    debugPrint('Using internal dir: ${dir.path}');
    return dir;
  }

  Future<bool> saveImageToGallery(String imagePath) async {
    try {
      final dir = await _getPublicDir('Pictures');
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = '${dir.path}/$fileName';
      await File(imagePath).copy(dest);
      debugPrint('Image saved: $dest');
      return true;
    } catch (e, st) {
      debugPrint('saveImageToGallery error: $e\n$st');
      return false;
    }
  }

  Future<File?> saveFileToDownloads(File file) async {
    try {
      final dir = await _getPublicDir('Documents');
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final dest = '${dir.path}/$fileName';
      final saved = await file.copy(dest);
      debugPrint('PDF saved: $dest');
      return saved;
    } catch (e, st) {
      debugPrint('saveFileToDownloads error: $e\n$st');
      return null;
    }
  }
}