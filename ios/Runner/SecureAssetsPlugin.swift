import Flutter
import UIKit
import CryptoKit

public class SecureAssetsPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "secure_assets",
      binaryMessenger: registrar.messenger()
    )

    let instance = SecureAssetsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {

    case "decryptAsset":
      guard
        let args = call.arguments as? [String: Any],
        let assetPath = args["path"] as? String
      else {
        result(
          FlutterError(
            code: "BAD_ARGS",
            message: "Missing path",
            details: nil
          )
        )
        return
      }

      let assetKey = FlutterDartProject.lookupKey(forAsset: assetPath)

      guard
        let assetUrl = Bundle.main.url(
          forResource: assetKey,
          withExtension: nil
        )
      else {
        result(
          FlutterError(
            code: "NOT_FOUND",
            message: assetKey,
            details: nil
          )
        )
        return
      }

      var debugDetails: [String: Any] = [
        "assetPath": assetPath,
        "assetKey": assetKey,
        "assetURL": assetUrl.path,
      ]

      do {
        let encryptedData = try Data(contentsOf: assetUrl)

        let assetHash = SHA256.hash(data: encryptedData)
          .map { String(format: "%02x", $0) }
          .joined()

        debugDetails["assetHash"] = assetHash
        debugDetails["assetBytes"] = encryptedData.count

        let keyHex = try SecureKeyProvider.loadContentKeyHex()
        let keyData = Self.hexToData(keyHex)

        let keyHash = SHA256.hash(data: Data(keyHex.utf8))
          .map { String(format: "%02x", $0) }
          .joined()

        debugDetails["keyHash"] = keyHash
        debugDetails["keyHexLength"] = keyHex.count
        debugDetails["keyBytes"] = keyData.count

#if DEBUG
        NSLog("[SECURE_DEBUG] keyHash=%@", keyHash)
        NSLog("[SECURE_DEBUG] assetHash=%@", assetHash)
        NSLog("[SECURE_DEBUG] assetPath=%@", assetPath)
        NSLog("[SECURE_DEBUG] assetURL=%@", assetUrl.path)
#endif

        guard keyData.count == 32 else {
          result(
            FlutterError(
              code: "INVALID_KEY",
              message: "AES-256 key must contain exactly 32 bytes",
              details: debugDetails
            )
          )
          return
        }

        let symmetricKey = SymmetricKey(data: keyData)

        let sealedBox = try AES.GCM.SealedBox(
          combined: encryptedData
        )

        let decrypted = try AES.GCM.open(
          sealedBox,
          using: symmetricKey
        )

        result(FlutterStandardTypedData(bytes: decrypted))
      } catch {
        debugDetails["nativeError"] = String(describing: error)

        result(
          FlutterError(
            code: "DECRYPT_ERROR",
            message: error.localizedDescription,
            details: debugDetails
          )
        )
      }

    case "verifyRuntime":
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func hexToData(_ hex: String) -> Data {
    let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)

    guard normalized.count % 2 == 0 else {
      return Data()
    }

    var data = Data()
    var index = normalized.startIndex

    while index < normalized.endIndex {
      let nextIndex = normalized.index(index, offsetBy: 2)
      let byteString = normalized[index..<nextIndex]

      guard let byte = UInt8(byteString, radix: 16) else {
        return Data()
      }

      data.append(byte)
      index = nextIndex
    }

    return data
  }
}
