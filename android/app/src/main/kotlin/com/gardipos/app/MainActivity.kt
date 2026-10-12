package com.gardipos.app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.gardipos.app/media"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveImageToGallery") {
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName") ?: "gardi_qr_${System.currentTimeMillis()}.png"
                if (bytes == null) {
                    result.error("INVALID_ARGS", "Bytes cannot be null", null)
                    return@setMethodCallHandler
                }
                try {
                    val saved = saveImage(bytes, fileName)
                    if (saved) {
                        result.success(true)
                    } else {
                        result.error("SAVE_FAILED", "Failed to save image", null)
                    }
                } catch (e: Exception) {
                    result.error("EXCEPTION", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveImage(bytes: ByteArray, fileName: String): Boolean {
        val safeName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/GardiERP")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues) ?: return false
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: return false
            contentValues.clear()
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)
            true
        } else {
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val gardiDir = File(picturesDir, "GardiERP")
            if (!gardiDir.exists()) {
                gardiDir.mkdirs()
            }
            val file = File(gardiDir, safeName)
            FileOutputStream(file).use { stream ->
                stream.write(bytes)
                stream.flush()
            }
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf("image/png"),
                null
            )
            true
        }
    }
}

