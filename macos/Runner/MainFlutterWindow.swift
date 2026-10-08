import Cocoa
import FlutterMacOS
import CryptoKit

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {

    let flutterViewController = FlutterViewController()

    let windowFrame = self.frame

    self.contentViewController = flutterViewController

    self.setFrame(windowFrame, display: true)

    let channel = FlutterMethodChannel(
      name: "secure_assets",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in

      switch call.method {

      case "decryptAsset":

        guard let args = call.arguments as? [String: Any],
              let assetPath = args["path"] as? String else {

          result(
            FlutterError(
              code: "BAD_ARGS",
              message: "Missing path",
              details: nil
            )
          )

          return
        }

        let flutterAssetKey = FlutterDartProject.lookupKey(
          forAsset: assetPath
        )

        print("[SECURE_ASSET_DEBUG] assetPath =", assetPath)
        print("[SECURE_ASSET_DEBUG] flutterAssetKey =", flutterAssetKey)

        guard let appFrameworkUrl = Bundle.main.privateFrameworksURL?
          .appendingPathComponent("App.framework")
          .appendingPathComponent("Resources") else {

          result(
            FlutterError(
              code: "NO_APP_FRAMEWORK_RESOURCES",
              message: nil,
              details: nil
            )
          )

          return
        }

        let assetUrl = appFrameworkUrl
          .appendingPathComponent("flutter_assets")
          .appendingPathComponent(assetPath)

        print("[SECURE_ASSET_DEBUG] assetUrl =", assetUrl.path)

        guard FileManager.default.fileExists(
          atPath: assetUrl.path
        ) else {

          result(
            FlutterError(
              code: "NOT_FOUND",
              message: assetUrl.path,
              details: nil
            )
          )

          return
        }

        do {

          let encryptedData = try Data(contentsOf: assetUrl)

          let keyHex = SecureKey.buildKeyHex()

          let keyData = Self.hexToData(keyHex)

          let symmetricKey = SymmetricKey(data: keyData)

          let sealedBox = try AES.GCM.SealedBox(
            combined: encryptedData
          )

          let decrypted = try AES.GCM.open(
            sealedBox,
            using: symmetricKey
          )

          result(
            FlutterStandardTypedData(bytes: decrypted)
          )

          return

        } catch {

          result(
            FlutterError(
              code: "DECRYPT_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )

          return
        }

      case "verifyRuntime":

        result(true)

        return

      default:

        result(FlutterMethodNotImplemented)

        return
      }
    }

    RegisterGeneratedPlugins(
      registry: flutterViewController
    )

    super.awakeFromNib()
  }

  private static func hexToData(
    _ hex: String
  ) -> Data {

    var data = Data()

    var temp = ""

    for c in hex {

      temp.append(c)

      if temp.count == 2 {

        if let byte = UInt8(temp, radix: 16) {

          data.append(byte)
        }

        temp = ""
      }
    }

    return data
  }
}

