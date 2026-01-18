package com.yokwejuste.numfyx

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "numfyx/file_writer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val args = call.arguments as? Map<String, Any>
                val fileName = args?.get("fileName") as? String
                val bytes = args?.get("bytes") as? ByteArray
                val mimeType = args?.get("mimeType") as? String ?: "application/octet-stream"

                if (fileName == null || bytes == null) {
                    result.error("INVALID_ARGS", "fileName and bytes are required", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedPath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        saveWithMediaStore(fileName, bytes, mimeType)
                    } else {
                        saveToDownloadsLegacy(fileName, bytes)
                    }

                    if (savedPath != null) {
                        result.success(savedPath)
                    } else {
                        result.error("SAVE_FAILED", "Could not save file", null)
                    }
                } catch (e: Exception) {
                    result.error("WRITE_FAILED", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveWithMediaStore(fileName: String, bytes: ByteArray, mimeType: String): String? {
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }

        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            ?: return null

        resolver.openOutputStream(uri)?.use { os ->
            os.write(bytes)
            os.flush()
        }

        return "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/$fileName"
    }

    private fun saveToDownloadsLegacy(fileName: String, bytes: ByteArray): String? {
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDir.exists()) {
            downloadsDir.mkdirs()
        }

        val file = File(downloadsDir, fileName)
        file.writeBytes(bytes)

        return if (file.exists()) file.absolutePath else null
    }
}
