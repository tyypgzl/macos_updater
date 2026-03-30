import Cocoa
import FlutterMacOS

public class MacosUpdaterPlugin: NSObject, FlutterPlugin {
    private func getCurrentVersion() -> String? {
        let infoDictionary = Bundle.main.infoDictionary!
        return infoDictionary["CFBundleShortVersionString"] as? String
    }

    private func restartApp(result: @escaping FlutterResult) {
        // 1. Sandbox guard (synchronous check, return early)
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            result(FlutterError(
                code: "SANDBOX_INCOMPATIBLE",
                message: "App Sandbox is enabled. macos_updater requires a non-sandboxed macOS app. Remove the com.apple.security.app-sandbox entitlement.",
                details: nil
            ))
            return
        }

        let executablePath = Bundle.main.executablePath!
        let updateFolder = Bundle.main.bundlePath + "/Contents/update"
        let bundleContents = Bundle.main.bundlePath + "/Contents"

        // 2. File ops on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // 2a. Copy files
            do {
                try self.copyAndReplaceFiles(from: updateFolder, to: bundleContents)
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "COPY_FAILED", message: error.localizedDescription, details: nil))
                }
                return
            }

            // 2b. Set permissions and launch new process
            do {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = []
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "RELAUNCH_FAILED", message: error.localizedDescription, details: nil))
                }
                return
            }

            // 2c. Signal success to Dart, then terminate on main thread
            DispatchQueue.main.async {
                result(nil)
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func copyAndReplaceFiles(from sourcePath: String, to destinationPath: String) throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: sourcePath)

        while let element = enumerator?.nextObject() as? String {
            let sourceItemPath = (sourcePath as NSString).appendingPathComponent(element)
            let destinationItemPath = (destinationPath as NSString).appendingPathComponent(element)

            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: sourceItemPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    // Ensure the directory exists at destination
                    if !fileManager.fileExists(atPath: destinationItemPath) {
                        try fileManager.createDirectory(atPath: destinationItemPath, withIntermediateDirectories: true, attributes: nil)
                    }
                } else {
                    // Handle file or symbolic link
                    let attributes = try fileManager.attributesOfItem(atPath: sourceItemPath)
                    if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                        // Handle symbolic link
                        if fileManager.fileExists(atPath: destinationItemPath) {
                            try fileManager.removeItem(atPath: destinationItemPath)
                        }
                        let target = try fileManager.destinationOfSymbolicLink(atPath: sourceItemPath)
                        try fileManager.createSymbolicLink(atPath: destinationItemPath, withDestinationPath: target)
                    } else {
                        // Handle regular file
                        if fileManager.fileExists(atPath: destinationItemPath) {
                            // Replace existing file
                            try fileManager.replaceItem(at: URL(fileURLWithPath: destinationItemPath), withItemAt: URL(fileURLWithPath: sourceItemPath), backupItemName: nil, options: [], resultingItemURL: nil)
                        } else {
                            // Copy new file
                            try fileManager.copyItem(atPath: sourceItemPath, toPath: destinationItemPath)
                        }
                    }
                }
            }
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "macos_updater", binaryMessenger: registrar.messenger)
        let instance = MacosUpdaterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "restartApp":
            Task { [weak self] in
                self?.restartApp(result: result)
            }
        case "getCurrentVersion":
            result(getCurrentVersion())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
