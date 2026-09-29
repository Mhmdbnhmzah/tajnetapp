package com.tajnet.tajnet_app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.tajnet.app/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendWhatsAppDirect") {
                val phone = call.argument<String>("phone") ?: "967784336270"
                val message = call.argument<String>("message") ?: ""
                val imagePath = call.argument<String>("imagePath") ?: ""

                val success = sendToWhatsApp(phone, message, imagePath)
                if (success) {
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "Failed to launch WhatsApp directly", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendToWhatsApp(phone: String, message: String, imagePath: String): Boolean {
        return try {
            val cleanPhone = phone.replace(Regex("[^0-9]"), "").trim()
            val jid = "$cleanPhone@s.whatsapp.net"

            val intent = Intent(Intent.ACTION_SEND)
            intent.type = if (imagePath.isNotEmpty()) "image/*" else "text/plain"
            intent.putExtra(Intent.EXTRA_TEXT, message)
            intent.putExtra("jid", jid)

            if (imagePath.isNotEmpty()) {
                val file = File(imagePath)
                if (file.exists()) {
                    val uri: Uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        file
                    )
                    intent.putExtra(Intent.EXTRA_STREAM, uri)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    try {
                        grantUriPermission("com.whatsapp", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        grantUriPermission("com.whatsapp.w4b", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    } catch (_: Exception) {}
                }
            }

            // Try WhatsApp main app first
            try {
                val waIntent = Intent(intent)
                waIntent.setPackage("com.whatsapp")
                waIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(waIntent)
                true
            } catch (e: Exception) {
                // Try WhatsApp Business app
                try {
                    val w4bIntent = Intent(intent)
                    w4bIntent.setPackage("com.whatsapp.w4b")
                    w4bIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(w4bIntent)
                    true
                } catch (e2: Exception) {
                    false
                }
            }
        } catch (e: Exception) {
            false
        }
    }
}
