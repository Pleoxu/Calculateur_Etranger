package com.example.calculateur_tir_ng

import android.content.res.AssetManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class MainActivity : FlutterActivity() {

    companion object {
        private const val NATIVE_SECURITY_CHANNEL = "native_security"
        private const val SECURITY_CHANNEL = "security_channel"
        private const val SECURE_ASSETS_CHANNEL = "secure_assets"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val securityHandler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceSecure",
                "isEnvironmentTrusted",
                "verifyEnvironment" -> result.success(true)

                "isCompromised",
                "isRooted",
                "isTampered",
                "checkEnvironment",
                "checkSecurity" -> result.success(false)

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_SECURITY_CHANNEL
        ).setMethodCallHandler(securityHandler)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL
        ).setMethodCallHandler(securityHandler)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURE_ASSETS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "decryptAsset" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String

                    if (path.isNullOrBlank()) {
                        result.error(
                            "BAD_ARGS",
                            "Missing path",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val assetKey = FlutterInjector.instance()
                            .flutterLoader()
                            .getLookupKeyForAsset(path)

                        val encrypted = readAssetBytes(
                            assets,
                            assetKey
                        )

                        val decrypted = decryptAesGcm(encrypted)

                        result.success(decrypted)

                    } catch (
                        e: SecureKeyProvider.KeyNotProvisionedException
                    ) {
                        result.error(
                            "KEY_NOT_PROVISIONED",
                            e.message,
                            null
                        )

                    } catch (e: Exception) {
                        result.error(
                            "DECRYPT_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                "verifyRuntime" -> result.success(true)

                else -> result.notImplemented()
            }
        }
    }

    private fun readAssetBytes(
        assetManager: AssetManager,
        path: String
    ): ByteArray {
        assetManager.open(path).use { input ->
            val buffer = ByteArrayOutputStream()
            val chunk = ByteArray(8192)

            while (true) {
                val read = input.read(chunk)

                if (read <= 0) {
                    break
                }

                buffer.write(
                    chunk,
                    0,
                    read
                )
            }

            return buffer.toByteArray()
        }
    }

    private fun decryptAesGcm(
        encryptedData: ByteArray
    ): ByteArray {

        // AES-GCM :
        // 12 octets de nonce + au moins 16 octets de tag.
        if (encryptedData.size < 28) {
            throw IllegalArgumentException(
                "Asset AES-GCM invalide."
            )
        }

        val keyBytes = SecureKeyProvider.loadContentKey(this)

        try {
            val key = SecretKeySpec(
                keyBytes,
                "AES"
            )

            val iv = encryptedData.copyOfRange(
                0,
                12
            )

            val cipherTextAndTag = encryptedData.copyOfRange(
                12,
                encryptedData.size
            )

            val cipher = Cipher.getInstance(
                "AES/GCM/NoPadding"
            )

            cipher.init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(
                    128,
                    iv
                )
            )

            return cipher.doFinal(
                cipherTextAndTag
            )

        } finally {
            // Efface cette copie de la clé de contenu
            // dès que le déchiffrement est terminé.
            keyBytes.fill(0)
        }
    }
}