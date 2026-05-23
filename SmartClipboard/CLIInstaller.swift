import Foundation
import AppKit

/// Installs the `clip` shell script into /usr/local/bin via a symlink to the
/// copy that ships inside the app bundle's Resources folder.
enum CLIInstaller {
    enum Error: Swift.Error, LocalizedError {
        case noBundleScript
        case symlinkFailed(underlying: Swift.Error)
        case requiresAdmin

        var errorDescription: String? {
            switch self {
            case .noBundleScript: return "Bundled `clip` script not found."
            case .symlinkFailed(let e): return e.localizedDescription
            case .requiresAdmin:
                return "/usr/local/bin requires admin. Re-run from Terminal: " +
                       "`sudo ln -sf \"$(mdfind kMDItemCFBundleIdentifier == com.shailka.SmartClipboard | head -1)/Contents/Resources/clip\" /usr/local/bin/clip`"
            }
        }
    }

    static func install() throws {
        guard let bundled = Bundle.main.url(forResource: "clip", withExtension: nil) else {
            throw Error.noBundleScript
        }
        try ensureExecutable(at: bundled)

        let targetDir = URL(fileURLWithPath: "/usr/local/bin")
        let target = targetDir.appendingPathComponent("clip")
        let fm = FileManager.default

        // Try /usr/local/bin first; if no write perms, fall back to ~/bin
        if !fm.isWritableFile(atPath: targetDir.path) {
            try installToHomeBin(source: bundled)
            return
        }

        if fm.fileExists(atPath: target.path) {
            try? fm.removeItem(at: target)
        }
        do {
            try fm.createSymbolicLink(at: target, withDestinationURL: bundled)
        } catch {
            throw Error.symlinkFailed(underlying: error)
        }
    }

    private static func installToHomeBin(source: URL) throws {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let binDir = home.appendingPathComponent("bin", isDirectory: true)
        try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
        let target = binDir.appendingPathComponent("clip")
        if fm.fileExists(atPath: target.path) {
            try? fm.removeItem(at: target)
        }
        do {
            try fm.createSymbolicLink(at: target, withDestinationURL: source)
        } catch {
            throw Error.symlinkFailed(underlying: error)
        }
    }

    private static func ensureExecutable(at url: URL) throws {
        let fm = FileManager.default
        if let mode = (try? fm.attributesOfItem(atPath: url.path))?[.posixPermissions] as? NSNumber,
           (mode.intValue & 0o111) == 0 {
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}
