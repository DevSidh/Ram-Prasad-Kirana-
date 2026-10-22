package com.freshharvest.grocery_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
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
