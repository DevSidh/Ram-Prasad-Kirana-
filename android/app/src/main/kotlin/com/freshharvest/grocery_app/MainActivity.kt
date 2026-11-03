package com.freshharvest.grocery_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.content.Intent
import android.content.ContentValues
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.view.WindowManager
import android.provider.MediaStore
import android.provider.Settings
import java.io.File
import java.io.FileOutputStream
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val orderNotificationChannelId = "faststore_admin_orders"
    private var previousPreferredDisplayModeId = 0

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    override fun onPause() {
        restorePreferredRefreshRate()
        super.onPause()
    }

    @Suppress("DEPRECATION")
    private fun requestHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val windowManager = getSystemService(WindowManager::class.java) ?: return
        val display = windowManager.defaultDisplay ?: return
        val currentModeId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            display.mode.modeId
        } else {
            0
        }
        if (previousPreferredDisplayModeId == 0) {
            previousPreferredDisplayModeId = window.attributes.preferredDisplayModeId
        }
        val mode = display.supportedModes
            .filter { it.refreshRate <= 120.5f }
            .maxByOrNull { it.refreshRate }
            ?: return
        if (mode.modeId != currentModeId) {
            window.attributes = window.attributes.apply {
                preferredDisplayModeId = mode.modeId
            }
        }
    }

    private fun restorePreferredRefreshRate() {
        if (previousPreferredDisplayModeId == 0) return
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = previousPreferredDisplayModeId
        }
        previousPreferredDisplayModeId = 0
    }

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "faststore/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls(),
                    )
                }

                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(null)
                }

                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_apk_path", "The APK path is missing.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path).canonicalFile
                        val cacheRoot = cacheDir.canonicalFile
                        if (!file.path.startsWith(cacheRoot.path + File.separator) ||
                            !file.isFile || file.length() == 0L
                        ) {
                            throw IllegalArgumentException("The update APK is not in FastStore's private cache.")
                        }
                        verifyUpdateApk(file)
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file,
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } catch (error: SecurityException) {
                        result.error("wrong_signing_certificate", error.message, null)
                    } catch (error: Exception) {
                        result.error("apk_install_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun verifyUpdateApk(apk: File) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val archive = packageManager.getPackageArchiveInfo(apk.path, flags)
            ?: throw IllegalArgumentException("Android could not read the downloaded APK.")
        if (archive.packageName != packageName) {
            throw SecurityException("This APK is for a different app and cannot update FastStore.")
        }
        val archiveSignatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archive.signingInfo?.apkContentsSigners
        } else {
            archive.signatures
        } ?: emptyArray()
        if (archiveSignatures.isEmpty()) {
            throw SecurityException("The downloaded APK has no verifiable signing certificate.")
        }

        val matchesInstalledSignature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archiveSignatures.all { signature ->
                packageManager.hasSigningCertificate(
                    packageName,
                    signature.toByteArray(),
                    PackageManager.CERT_INPUT_RAW_X509,
                )
            }
        } else {
            val installed = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                .signatures ?: emptyArray()
            installed.isNotEmpty() && archiveSignatures.size == installed.size &&
                archiveSignatures.all { candidate ->
                    installed.any { it.toByteArray().contentEquals(candidate.toByteArray()) }
                }
        }
        if (!matchesInstalledSignature) {
            throw SecurityException("The APK was signed with a different certificate. Install stopped to protect your app data.")
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

}
