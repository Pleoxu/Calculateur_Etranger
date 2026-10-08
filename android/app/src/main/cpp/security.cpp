#include <jni.h>
#include <string>
#include <fstream>

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_calculateur_1tir_1ng_SecurityNative_checkFridaNative(
        JNIEnv *env,
        jobject thiz
) {
    std::ifstream maps("/proc/self/maps");
    std::string line;

    while (std::getline(maps, line)) {

        if (
                line.find("frida") != std::string::npos ||
                line.find("gum-js") != std::string::npos ||
                line.find("gadget") != std::string::npos ||
                line.find("xposed") != std::string::npos ||
                line.find("substrate") != std::string::npos
                ) {
            return JNI_TRUE;
        }
    }

    return JNI_FALSE;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_example_calculateur_1tir_1ng_SecurityNative_getNativeKeyPart(
        JNIEnv *env,
        jobject thiz
) {
    std::string part = "NATIVE_QW77_SPLIT";

    return env->NewStringUTF(part.c_str());
}