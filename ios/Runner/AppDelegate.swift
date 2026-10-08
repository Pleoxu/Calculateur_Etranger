import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

      GeneratedPluginRegistrant.register(with: self)

      if let registrar = registrar(forPlugin: "SecureAssetsPlugin") {
          SecureAssetsPlugin.register(with: registrar)
      }

      #if DEBUG
      provisionDebugSecureAssetKeyFromFileIfPresent()
      #endif

      if let controller = window?.rootViewController as? FlutterViewController {

          let channel = FlutterMethodChannel(
              name: "native_security",
              binaryMessenger: controller.binaryMessenger
          )

          channel.setMethodCallHandler { call, result in
            if call.method == "checkSecurity" {
              result(SecurityChecker.isCompromised())
            } else {
              result(FlutterMethodNotImplemented)
            }
          }
      }

      return super.application(
        application,
        didFinishLaunchingWithOptions: launchOptions
      )
    }

    #if DEBUG
    private func provisionDebugSecureAssetKeyFromFileIfPresent() {
      let fm = FileManager.default

      guard let documents = fm.urls(
        for: .documentDirectory,
        in: .userDomainMask
      ).first else {
        print("[DEBUG_PROVISION][ERROR] Documents directory unavailable.")
        return
      }

      let keyFile = documents.appendingPathComponent("asset_key_v2.hex")

      guard fm.fileExists(atPath: keyFile.path) else {
        return
      }

      do {
        let keyHex = try String(
          contentsOf: keyFile,
          encoding: .utf8
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        try SecureKeyProvider.storeContentKeyHex(keyHex)

        print(
          "[DEBUG_PROVISION] Clé de contenu provisionnée avec succès."
        )
      } catch {
        print(
          "[DEBUG_PROVISION][ERROR] Échec du provisionnement : " +
          error.localizedDescription
        )
      }

      do {
        try fm.removeItem(at: keyFile)
        print("[DEBUG_PROVISION] Fichier de provisionnement supprimé.")
      } catch {
        print(
          "[DEBUG_PROVISION][ERROR] Suppression du fichier impossible : " +
          error.localizedDescription
        )
      }
    }
    #endif
}
