// SPDX-License-Identifier: MIT

import Foundation
import CryptoKit

/// What is checked on a package before it is handed to the Installer: the checksum published next to it (it tells a damaged download), then its
/// signature and its notarization (they tell who made it: this is the check that counts).
public enum PackageVerifier {
    public enum Failure: Error, Equatable {
        case checksum
        case signature
    }

    /// The SHA-256 of a file, in lower-case hexadecimal.
    public static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The checksum a `.sha256` file says: its first word of 64 hexadecimal digits (`shasum` writes "<digest>  <file name>").
    public static func expectedChecksum(in text: String) -> String? {
        for word in text.split(whereSeparator: \.isWhitespace) where word.count == 64 && word.allSatisfy(\.isHexDigit) {
            return word.lowercased()
        }
        return nil
    }

    /// Reads the output of `pkgutil --check-signature`: signed with a Developer ID, notarized, and the certificate of the installer is the one
    /// of the team.
    public static func signatureIsValid(_ output: String, teamID: String) -> Bool {
        output.contains("Status: signed by a developer certificate issued by Apple")
            && output.contains("Notarization: trusted by the Apple notary service")
            && output.split(separator: "\n").contains { $0.contains("1. Developer ID Installer:") && $0.contains("(\(teamID))") }
    }

    /// Throws `Failure.signature` unless the package is signed by the team and notarized, and Gatekeeper accepts it as an installer.
    public static func verifySignature(of package: URL, teamID: String) async throws {
        let check = try await Tool.run("/usr/sbin/pkgutil", ["--check-signature", package.path])
        guard check.status == 0, signatureIsValid(check.output, teamID: teamID) else { throw Failure.signature }
        let assessment = try await Tool.run("/usr/sbin/spctl", ["--assess", "--type", "install", package.path])
        guard assessment.status == 0 else { throw Failure.signature }
    }
}

enum Tool {
    /// Runs a program and gives its status and its output (standard output and error together). The programs used here write a few lines.
    static func run(_ path: String, _ arguments: [String]) async throws -> (status: Int32, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { finished in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (finished.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
