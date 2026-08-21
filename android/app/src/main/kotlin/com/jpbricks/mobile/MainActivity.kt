package com.jpbricks.mobile

import android.content.ContentValues
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "jp_bricks/downloads").setMethodCallHandler { call, result ->
            if (call.method != "saveCsv") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName") ?: "export.csv"
            val content = call.argument<String>("content") ?: ""
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "text/csv")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Kansjor Borewell")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            if (uri == null) {
                result.error("DOWNLOAD_FAILED", "Unable to create the CSV file.", null)
                return@setMethodCallHandler
            }
            try {
                resolver.openOutputStream(uri)?.bufferedWriter()?.use { it.write(content) }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success("Download/Kansjor Borewell/$fileName")
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                result.error("DOWNLOAD_FAILED", error.message, null)
            }
        }
    }
}
