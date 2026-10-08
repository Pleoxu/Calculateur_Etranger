import Foundation
import UIKit
import MachO
import Darwin

final class SecurityChecker {

    static func isCompromised() -> Bool {
        #if DEBUG
        print("[SECURITY] DEBUG build -> allowed")
        return false
        #else
        let jailbroken = isJailbroken()
        let debugger = isDebuggerAttached()
        let suspiciousDylibs = hasSuspiciousDylibs()

        print(
            "[SECURITY] jailbroken=\(jailbroken) " +
            "debugger=\(debugger) " +
            "suspiciousDylibs=\(suspiciousDylibs)"
        )

        let compromised = jailbroken || debugger || suspiciousDylibs

        print("[SECURITY] compromised=\(compromised)")

        return compromised
        #endif
    }

    private static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/lib/libhooker.dylib",
            "/usr/lib/substitute.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        let testPath = "/private/security_test_\(UUID().uuidString).txt"

        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }

    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride

        var mib: [Int32] = [
            CTL_KERN,
            KERN_PROC,
            KERN_PROC_PID,
            getpid()
        ]

        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)

        if result != 0 {
            return false
        }

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    private static func hasSuspiciousDylibs() -> Bool {
        let suspicious = [
            "frida",
            "fridagadget",
            "gum-js-loop",
            "libhooker",
            "substrate",
            "cydiasubstrate",
            "mobilesubstrate",
            "substitute"
        ]

        let imageCount = _dyld_image_count()

        for i in 0..<imageCount {
            guard let cName = _dyld_get_image_name(i) else {
                continue
            }

            let name = String(cString: cName).lowercased()

            for marker in suspicious {
                if name.contains(marker) {
                    return true
                }
            }
        }

        return false
    }
}
