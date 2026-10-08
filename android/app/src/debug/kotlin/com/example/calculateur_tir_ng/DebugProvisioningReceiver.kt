package com.example.calculateur_tir_ng

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DebugProvisioningReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DEBUG_PROVISION"
        private const val KEY_FILE = "asset_key_v2.hex"
    }

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        val keyFile = context.filesDir.resolve(KEY_FILE)

        if (!keyFile.exists()) {
            Log.e(
                TAG,
                "Fichier de provisionnement introuvable."
            )
            return
        }

        var keyBytes: ByteArray? = null

        try {
            val keyHex = keyFile
                .readText()
                .trim()

            if (
                keyHex.length != 64 ||
                !keyHex.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }
            ) {
                throw IllegalArgumentException(
                    "Clé hexadécimale invalide."
                )
            }

            keyBytes = hexToBytes(keyHex)

            SecureKeyProvider.storeContentKey(
                context,
                keyBytes
            )

            Log.i(
                TAG,
                "Clé de contenu provisionnée avec succès."
            )

        } catch (e: Exception) {
            Log.e(
                TAG,
                "Échec du provisionnement : ${e.message}",
                e
            )

        } finally {
            keyBytes?.fill(0)

            if (keyFile.exists()) {
                keyFile.delete()
            }
        }
    }

    private fun hexToBytes(
        hex: String
    ): ByteArray {
        return ByteArray(hex.length / 2) { index ->
            hex.substring(
                index * 2,
                index * 2 + 2
            ).toInt(16).toByte()
        }
    }
}