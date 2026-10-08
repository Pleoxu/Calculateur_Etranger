import Foundation

enum SecureKey {

    private static let contentKeyHex =
        "0b6ccab89e3831022f87383b0b2174df695cfa7a0315cb253910e1dfcc645247"

    static func buildKeyHex() -> String {
        return contentKeyHex
    }

    static func loadContentKeyHex() throws -> String {
        return contentKeyHex
    }
}
