package com.example.calculateur_tir_ng

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object SecureKeyProvider {

    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val WRAPPING_KEY_ALIAS =
        "calculateur_tir_asset_wrapping_key_v1"

    private const val PREFS_NAME =
        "calculateur_tir_secure_assets"

    private const val PREF_WRAPPED_KEY =
        "wrapped_content_key_v2"

    private const val PREF_WRAPPED_IV =
        "wrapped_content_key_iv_v2"

    private const val AES_MODE =
        "AES/GCM/NoPadding"

    class KeyNotProvisionedException :
        Exception("Clé de contenu non provisionnée.")

    class InvalidContentKeyException :
        Exception("Clé AES-256 invalide.")

    fun loadContentKey(context: Context): ByteArray {

        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val wrappedBase64 =
            prefs.getString(PREF_WRAPPED_KEY, null)
                ?: throw KeyNotProvisionedException()

        val ivBase64 =
            prefs.getString(PREF_WRAPPED_IV, null)
                ?: throw KeyNotProvisionedException()

        val wrapped = Base64.decode(
            wrappedBase64,
            Base64.NO_WRAP
        )

        val iv = Base64.decode(
            ivBase64,
            Base64.NO_WRAP
        )

        val wrappingKey = getOrCreateWrappingKey()

        val cipher = Cipher.getInstance(AES_MODE)

        cipher.init(
            Cipher.DECRYPT_MODE,
            wrappingKey,
            GCMParameterSpec(128, iv)
        )

        val contentKey = cipher.doFinal(wrapped)

        if (contentKey.size != 32) {
            contentKey.fill(0)
            throw InvalidContentKeyException()
        }

        return contentKey
    }

    fun storeContentKey(
        context: Context,
        contentKey: ByteArray
    ) {
        if (contentKey.size != 32) {
            throw InvalidContentKeyException()
        }

        val wrappingKey = getOrCreateWrappingKey()

        val cipher = Cipher.getInstance(AES_MODE)

        cipher.init(
            Cipher.ENCRYPT_MODE,
            wrappingKey
        )

        val wrapped = cipher.doFinal(contentKey)
        val iv = cipher.iv

        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        prefs.edit()
            .putString(
                PREF_WRAPPED_KEY,
                Base64.encodeToString(
                    wrapped,
                    Base64.NO_WRAP
                )
            )
            .putString(
                PREF_WRAPPED_IV,
                Base64.encodeToString(
                    iv,
                    Base64.NO_WRAP
                )
            )
            .apply()
    }

    fun hasContentKey(context: Context): Boolean {

        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        return prefs.contains(PREF_WRAPPED_KEY) &&
            prefs.contains(PREF_WRAPPED_IV)
    }

    private fun getOrCreateWrappingKey(): SecretKey {

        val keyStore = KeyStore.getInstance(
            ANDROID_KEYSTORE
        )

        keyStore.load(null)

        val existing = keyStore.getKey(
            WRAPPING_KEY_ALIAS,
            null
        )

        if (existing is SecretKey) {
            return existing
        }

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )

        val spec = KeyGenParameterSpec.Builder(
            WRAPPING_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or
                KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(
                KeyProperties.BLOCK_MODE_GCM
            )
            .setEncryptionPaddings(
                KeyProperties.ENCRYPTION_PADDING_NONE
            )
            .setKeySize(256)
            .build()

        generator.init(spec)

        return generator.generateKey()
    }
}
