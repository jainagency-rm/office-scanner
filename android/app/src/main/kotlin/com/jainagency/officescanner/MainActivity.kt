package com.jainagency.officescanner

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.jainagency.officescanner/media"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        val folderName = call.argument<String>("folderName")
                        if (bytes != null && fileName != null && folderName != null) {
                            val success = saveImageViaMediaStore(bytes, fileName, folderName)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGS", "Missing arguments", null)
                        }
                    }
                    "savePdfToDocuments" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        val folderName = call.argument<String>("folderName")
                        if (bytes != null && fileName != null && folderName != null) {
                            val path = savePdfViaMediaStore(bytes, fileName, folderName)
                            if (path != null) result.success(path)
                            else result.error("SAVE_FAILED", "Could not save PDF", null)
                        } else {
                            result.error("INVALID_ARGS", "Missing arguments", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveImageViaMediaStore(
        bytes: ByteArray,
        fileName: String,
        folderName: String
    ): Boolean {
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$folderName")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return false
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun savePdfViaMediaStore(
        bytes: ByteArray,
        fileName: String,
        folderName: String
    ): String? {
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Downloads.RELATIVE_PATH, "Documents/$folderName")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
            }
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Downloads.EXTERNAL_CONTENT_URI
            }
            val uri = contentResolver.insert(collection, values) ?: return null
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            // Return human-readable path for record keeping
            "Documents/$folderName/$fileName"
        } catch (e: Exception) {
            null
        }
    }
}