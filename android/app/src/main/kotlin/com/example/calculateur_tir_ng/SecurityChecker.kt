package com.example.calculateur_tir_ng

import android.content.Context
import android.os.Build
import java.io.File

object SecurityChecker {

    fun checkSecurity(context: Context): Boolean {

        return isRooted() ||
                isFridaDetected() ||
                isDebuggerAttached() ||
                isEmulator()
    }

    private fun isRooted(): Boolean {

        val paths = arrayOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/app/Superuser.apk",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su-backup",
            "/system/xbin/mu",
            "/system/bin/busybox",
            "/system/xbin/busybox"
        )

        return paths.any {
            File(it).exists()
        }
    }

    private fun isFridaDetected(): Boolean {
        return SecurityNative.checkFridaNative()
    }

    private fun isDebuggerAttached(): Boolean {
        return android.os.Debug.isDebuggerConnected()
    }

    private fun isEmulator(): Boolean {

        return (
                Build.FINGERPRINT.contains("generic") ||
                        Build.MODEL.contains("Emulator") ||
                        Build.MODEL.contains("Android SDK built for x86") ||
                        Build.MANUFACTURER.contains("Genymotion") ||
                        Build.BRAND.startsWith("generic") &&
                        Build.DEVICE.startsWith("generic") ||
                        "google_sdk" == Build.PRODUCT
                )
    }
}