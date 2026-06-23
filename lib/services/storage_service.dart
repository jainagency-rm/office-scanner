import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const _appFolderName = 'Office Scanner';
  static const _platform = MethodChannel('com.jainagency.officescanner/media');

  /// Save image to public Pictures via MediaStore (Android 10+ compatible)
  Future<bool> saveImageToGallery(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await _platform.invokeMethod<bool>('saveImageToGallery', {
        'bytes': bytes,
        'fileName': fileName,
        'folderName': _appFolderName,
      });
      return result ?? false;
    } catch (e, st) {
      debugPrint('saveImageToGallery error: $e\n$st');
      return false;
    }
  }

  /// Save image permanently for app-internal use (temp → permanent path)
  Future<String?> saveImagePermanently(String sourcePath) async {
    try {
      final appExtDir = await getExternalStorageDirectory();
      final baseDir = appExtDir ?? await getApplicationDocumentsDirectory();
      final dir = Directory('${baseDir.path}/$_appFolderName/images');
      await dir.create(recursive: true);
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = '${dir.path}/$fileName';
      await File(sourcePath).copy(dest);
      return dest;
    } catch (e) {
      debugPrint('saveImagePermanently error: $e');
      return null;
    }
  }

  /// Save PDF to public Documents via MediaStore (Android 10+ compatible)
  Future<File?> saveFileToDownloads(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final result = await _platform.invokeMethod<String>('savePdfToDocuments', {
        'bytes': bytes,
        'fileName': fileName,
        'folderName': _appFolderName,
      });
      if (result != null) {
        debugPrint('PDF saved via MediaStore: $result');
        // Return a dummy File — actual file is in MediaStore,
        // path is only used for updateScan record
        return File(result);
      }
      return null;
    } catch (e, st) {
      debugPrint('saveFileToDownloads error: $e\n$st');
      return null;
    }
  }
}