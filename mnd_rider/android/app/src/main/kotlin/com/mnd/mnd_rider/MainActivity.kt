package com.mnd.mnd_rider

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes the Maps API key that Gradle already wrote into AndroidManifest.xml
 * (from android/local.properties) back to Dart, so the Directions API call in
 * RiderDirectionsService gets road-following routes without every run needing
 * `--dart-define=GOOGLE_MAPS_KEY=...` passed by hand.
 */
class MainActivity : FlutterActivity() {
    private val configChannel = "com.mnd.mnd_rider/config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, configChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "googleMapsApiKey") {
                    result.success(readGoogleMapsApiKeyFromManifest())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun readGoogleMapsApiKeyFromManifest(): String? {
        return try {
            val appInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            appInfo.metaData?.getString("com.google.android.geo.API_KEY")
        } catch (_: Exception) {
            null
        }
    }
}
