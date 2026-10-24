package com.freshharvest.grocery_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.content.Intent
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val orderNotificationChannelId = "faststore_admin_orders"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "faststore/admin_order_alerts",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            4057,
                        )
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }

                "showNewOrder" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(false)
                    } else {
                        showNewOrderNotification(
                            call.argument<String>("orderNumber") ?: "New order",
                        )
                        result.success(true)
                    }
                }

                "shareText" -> {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank()) {
                        result.error("invalid_share_text", "Share text is empty.", null)
                    } else {
                        val subject = call.argument<String>("subject") ?: "FastStore"
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(shareIntent, "Share product"))
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "faststore/invoices",
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePdf") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val filename = call.argument<String>("filename")
            val bytes = call.argument<ByteArray>("bytes")
            if (filename.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
                result.error("invalid_invoice", "Invoice file data is missing.", null)
                return@setMethodCallHandler
            }
            try {
                result.success(saveInvoicePdf(filename, bytes))
            } catch (error: Exception) {
                result.error("invoice_save_failed", "Could not save the invoice PDF.", error.message)
            }
        }
    }

    private fun saveInvoicePdf(filename: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/Ram Prasad Kirana",
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values,
            ) ?: throw IllegalStateException("The Downloads folder is unavailable.")
            try {
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: throw IllegalStateException("The invoice file could not be opened.")
                val published = contentResolver.update(
                    uri,
                    ContentValues().apply {
                        put(MediaStore.Downloads.IS_PENDING, 0)
                    },
                    null,
                    null,
                )
                if (published != 1) {
                    throw IllegalStateException("The invoice could not be published in Downloads.")
                }
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            return "Downloads/Ram Prasad Kirana/$filename"
        }

        val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("The Downloads folder is unavailable.")
        val file = File(directory, filename)
        try {
            FileOutputStream(file).use { it.write(bytes) }
            return file.absolutePath
        } catch (error: Exception) {
            file.delete()
            throw error
        }
    }

    private fun showNewOrderNotification(orderNumber: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                orderNotificationChannelId,
                "New store orders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts administrators when customer orders arrive."
            },
        )
        val notification = Notification.Builder(this, orderNotificationChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("FastStore")
            .setContentText("New order received: $orderNumber")
            .setAutoCancel(true)
            .build()
        manager.notify(
            (System.currentTimeMillis() and 0x7FFFFFFF).toInt(),
            notification,
        )
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = windowManager.defaultDisplay
            val currentMode = display.mode
            val preferredMode = display.supportedModes
                .filter {
                    it.physicalWidth == currentMode.physicalWidth &&
                        it.physicalHeight == currentMode.physicalHeight
                }
                .maxByOrNull { it.refreshRate }
            window.attributes = window.attributes.apply {
                preferredMode?.let {
                    preferredDisplayModeId = it.modeId
                    preferredRefreshRate = it.refreshRate
                }
            }
        }
    }
}
