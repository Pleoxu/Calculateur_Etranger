package com.example.calculateur_tir_ng

object SecurityNative {

    init {
        System.loadLibrary("security")
    }

    external fun checkFridaNative(): Boolean

    external fun getNativeKeyPart(): String
}