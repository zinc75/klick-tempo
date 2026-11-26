// SPDX-License-Identifier: MIT

import XCTest
@testable import UpdateKit

final class ReleaseVersionTests: XCTestCase {
    func testNumbersAreComparedOneByOne() {
        XCTAssertTrue(ReleaseVersion("0.9.73.6")! < ReleaseVersion("0.9.73.10")!)
        XCTAssertTrue(ReleaseVersion("0.9.9")! < ReleaseVersion("0.10.0")!)
        XCTAssertTrue(ReleaseVersion("1.1.0.2")! > ReleaseVersion("1.0.9.9")!)
    }

    func testAMissingNumberIsZero() {
        XCTAssertEqual(ReleaseVersion("1.0"), ReleaseVersion("1.0.0"))
        XCTAssertEqual(ReleaseVersion("1.0")!.hashValue, ReleaseVersion("1.0.0")!.hashValue)
        XCTAssertFalse(ReleaseVersion("1.0")! < ReleaseVersion("1.0.0")!)
    }

    func testTextThatIsNotAVersion() {
        XCTAssertNil(ReleaseVersion(""))
        XCTAssertNil(ReleaseVersion("1.x"))
        XCTAssertNil(ReleaseVersion("1..2"))
        XCTAssertNil(ReleaseVersion("v1.2"))
    }
}

final class ReleaseLabelTests: XCTestCase {
    func testTheFirstReleaseIsRevisionOne() {
        let label = ReleaseLabel.parse(tag: "jack_capture-v0.9.73-macOS", prefix: "jack_capture-v")
        XCTAssertEqual(label, ReleaseLabel(upstream: "0.9.73", revision: 1))
    }

    func testARevision() {
        let label = ReleaseLabel.parse(tag: "jack_capture-v0.9.73-macOS-6", prefix: "jack_capture-v")
        XCTAssertEqual(label, ReleaseLabel(upstream: "0.9.73", revision: 6))
        XCTAssertEqual(label?.version, ReleaseVersion("0.9.73.6"))
    }

    func testAnotherToolOrTheCollectionIsNotThisTool() {
        XCTAssertNil(ReleaseLabel.parse(tag: "jack_play-v0.19-macOS-4", prefix: "jack_capture-v"))
        XCTAssertNil(ReleaseLabel.parse(tag: "collection-v1.0", prefix: "jack_capture-v"))
        XCTAssertNil(ReleaseLabel.parse(tag: "klick-v0.13.0-macOS-4", prefix: "klick-tempo-v"))
    }

    func testATagThatIsNotAVersion() {
        XCTAssertNil(ReleaseLabel.parse(tag: "klick-vnext-macOS", prefix: "klick-v"))
        XCTAssertNil(ReleaseLabel.parse(tag: "klick-v0.13.0-macOS-x", prefix: "klick-v"))
        XCTAssertNil(ReleaseLabel.parse(tag: "klick-v0.13.0-macOS-0", prefix: "klick-v"))
    }

    func testARevisionIsNewerThanTheOneBeforeAndAnUpstreamVersionThanAllOfThem() {
        let installed = ReleaseLabel(upstream: "0.9.73", revision: 6)
        XCTAssertTrue(ReleaseLabel(upstream: "0.9.73", revision: 7).version > installed.version)
        XCTAssertTrue(ReleaseLabel(upstream: "0.9.74", revision: 1).version > installed.version)
        XCTAssertFalse(ReleaseLabel(upstream: "0.9.73", revision: 6).version > installed.version)
        XCTAssertFalse(ReleaseLabel(upstream: "0.9.73", revision: 5).version > installed.version)
    }

    func testTheLineOfTheAboutPanel() {
        XCTAssertEqual(ReleaseLabel(upstream: "0.9.73", revision: 6).text(revisionWord: "révision"), "0.9.73 macOS Edition · révision 6")
    }

    func testTheInstalledLabelOfADevelopmentRun() {
        XCTAssertEqual(ReleaseLabel.parseInstalled("0.9.73.5"), ReleaseLabel(upstream: "0.9.73", revision: 5))
        XCTAssertNil(ReleaseLabel.parseInstalled("7"))
    }
}

final class UpdateFeedTests: XCTestCase {
    private let json = """
    [
      {"tag_name": "jack_capture-v0.9.73-macOS-6", "draft": false, "prerelease": false, "html_url": "https://github.com/o/r/releases/tag/jack_capture-v0.9.73-macOS-6",
       "assets": [{"name": "JackCapture-0.9.73-macOS-6.pkg", "size": 1000, "browser_download_url": "https://github.com/o/r/releases/download/x6/JackCapture-0.9.73-macOS-6.pkg"},
                  {"name": "JackCapture-0.9.73-macOS-6.pkg.sha256", "size": 90, "browser_download_url": "https://github.com/o/r/releases/download/x6/JackCapture-0.9.73-macOS-6.pkg.sha256"}]},
      {"tag_name": "jack_play-v0.19-macOS-4", "draft": false, "prerelease": false, "html_url": "https://github.com/o/r/releases/tag/p4",
       "assets": [{"name": "JackPlay-0.19-macOS-4.pkg", "size": 5, "browser_download_url": "https://github.com/o/r/releases/download/p4/JackPlay-0.19-macOS-4.pkg"}]},
      {"tag_name": "jack_capture-v0.9.73-macOS-10", "draft": false, "prerelease": false, "html_url": "https://github.com/o/r/releases/tag/x10",
       "assets": [{"name": "JackCapture-0.9.73-macOS-10.pkg", "size": 1001, "browser_download_url": "https://github.com/o/r/releases/download/x10/JackCapture-0.9.73-macOS-10.pkg"}]},
      {"tag_name": "jack_capture-v0.9.73-macOS-11", "draft": true, "prerelease": false, "html_url": "https://github.com/o/r/releases/tag/x11",
       "assets": [{"name": "JackCapture-0.9.73-macOS-11.pkg", "size": 1, "browser_download_url": "https://github.com/o/r/releases/download/x11/a.pkg"}]},
      {"tag_name": "jack_capture-v0.9.73-macOS-12", "draft": false, "prerelease": true, "html_url": "https://github.com/o/r/releases/tag/x12",
       "assets": [{"name": "JackCapture-0.9.73-macOS-12.pkg", "size": 1, "browser_download_url": "https://github.com/o/r/releases/download/x12/a.pkg"}]},
      {"tag_name": "jack_capture-v0.9.73-macOS-13", "draft": false, "prerelease": false, "html_url": "https://github.com/o/r/releases/tag/x13",
       "assets": []},
      {"tag_name": "collection-v1.0", "draft": false, "prerelease": false, "html_url": "https://github.com/o/r/releases/tag/c1",
       "assets": [{"name": "JackAppsCollection-1.0-macOS.pkg", "size": 9, "browser_download_url": "https://github.com/o/r/releases/download/c1/c.pkg"}]}
    ]
    """

    func testTheNewestReleaseOfTheToolIsChosenByNumberNotByOrder() throws {
        let releases = try UpdateFeed.decode(Data(json.utf8))
        XCTAssertEqual(releases.count, 7)
        let offer = try XCTUnwrap(UpdateFeed.newestOffer(in: releases, tagPrefix: "jack_capture-v"))
        // 10 is newer than 6 although it comes after it; the draft, the pre-release and the release without a package are left out.
        XCTAssertEqual(offer.tag, "jack_capture-v0.9.73-macOS-10")
        XCTAssertEqual(offer.label.revision, 10)
        XCTAssertEqual(offer.packageName, "JackCapture-0.9.73-macOS-10.pkg")
        XCTAssertNil(offer.checksumURL)
    }

    func testTheChecksumFileNextToThePackage() throws {
        let releases = try UpdateFeed.decode(Data(json.utf8))
        let only = Array(releases.prefix(1))
        let offer = try XCTUnwrap(UpdateFeed.newestOffer(in: only, tagPrefix: "jack_capture-v"))
        XCTAssertEqual(offer.checksumURL?.lastPathComponent, "JackCapture-0.9.73-macOS-6.pkg.sha256")
    }

    func testAToolWithoutReleases() throws {
        let releases = try UpdateFeed.decode(Data(json.utf8))
        XCTAssertNil(UpdateFeed.newestOffer(in: releases, tagPrefix: "zita-njbridge-v"))
    }

    func testAnAnswerThatIsNotAListOfReleases() {
        // What GitHub says when the rate limit is reached.
        XCTAssertThrowsError(try UpdateFeed.decode(Data(#"{"message": "API rate limit exceeded"}"#.utf8)))
    }
}

final class PackageVerifierTests: XCTestCase {
    func testTheChecksumOfAFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("updatekit-\(UUID().uuidString).txt")
        try Data("abc".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(try PackageVerifier.sha256(of: file), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testTheChecksumThatAFileSays() {
        let digest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        XCTAssertEqual(PackageVerifier.expectedChecksum(in: "\(digest)  JackCapture-0.9.73-macOS-6.pkg\n"), digest)
        XCTAssertEqual(PackageVerifier.expectedChecksum(in: digest.uppercased()), digest)
        XCTAssertNil(PackageVerifier.expectedChecksum(in: "not a digest  file.pkg"))
        XCTAssertNil(PackageVerifier.expectedChecksum(in: ""))
    }

    private let signed = """
    Package "JackCapture-0.9.73-macOS-5.pkg":
       Status: signed by a developer certificate issued by Apple for distribution
       Notarization: trusted by the Apple notary service
       Signed with a trusted timestamp on: 2026-11-19 19:56:29 +0000
       Certificate Chain:
        1. Developer ID Installer: Éric Bavu (R98ZGK7FWR)
           Expires: 2031-07-11 15:15:36 +0000
        2. Developer ID Certification Authority
        3. Apple Root CA
    """

    func testASignedAndNotarizedPackage() {
        XCTAssertTrue(PackageVerifier.signatureIsValid(signed, teamID: "R98ZGK7FWR"))
    }

    func testAnotherTeamIsRefused() {
        XCTAssertFalse(PackageVerifier.signatureIsValid(signed, teamID: "ABCDE12345"))
    }

    func testAPackageThatIsNotNotarizedIsRefused() {
        XCTAssertFalse(PackageVerifier.signatureIsValid(signed.replacingOccurrences(of: "Notarization: trusted by the Apple notary service", with: "Notarization: none"), teamID: "R98ZGK7FWR"))
    }

    func testAnUnsignedPackageIsRefused() {
        XCTAssertFalse(PackageVerifier.signatureIsValid("Package \"x.pkg\":\n   Status: no signature\n", teamID: "R98ZGK7FWR"))
    }

    func testTheTeamIsReadOnTheCertificateOfTheInstaller() {
        // The team id in another line (the name of the package, say) does not count.
        let forged = signed.replacingOccurrences(of: "Éric Bavu (R98ZGK7FWR)", with: "Someone Else (ABCDE12345)")
            .replacingOccurrences(of: "Package \"JackCapture", with: "Package \"(R98ZGK7FWR)")
        XCTAssertFalse(PackageVerifier.signatureIsValid(forged, teamID: "R98ZGK7FWR"))
    }
}

/// Runs the real `pkgutil` and `spctl`: give a signed and notarized package in UPDATEKIT_SIGNED_PKG, and an unsigned one in
/// UPDATEKIT_UNSIGNED_PKG (both optional; the test is skipped without them).
final class PackageVerifierToolsTests: XCTestCase {
    private static func package(_ variable: String) throws -> String {
        guard let path = ProcessInfo.processInfo.environment[variable], !path.isEmpty else { throw XCTSkip("\(variable) is not set") }
        return path
    }

    func testASignedPackageIsAccepted() async throws {
        let path = try Self.package("UPDATEKIT_SIGNED_PKG")
        try await PackageVerifier.verifySignature(of: URL(fileURLWithPath: path), teamID: "R98ZGK7FWR")
    }

    func testAnotherTeamIsRefusedOnARealPackage() async throws {
        let path = try Self.package("UPDATEKIT_SIGNED_PKG")
        do {
            try await PackageVerifier.verifySignature(of: URL(fileURLWithPath: path), teamID: "ABCDE12345")
            XCTFail("a package of another team must be refused")
        } catch {
            XCTAssertEqual(error as? PackageVerifier.Failure, .signature)
        }
    }

    func testAnUnsignedPackageIsRefused() async throws {
        let path = try Self.package("UPDATEKIT_UNSIGNED_PKG")
        do {
            try await PackageVerifier.verifySignature(of: URL(fileURLWithPath: path), teamID: "R98ZGK7FWR")
            XCTFail("an unsigned package must be refused")
        } catch {
            XCTAssertEqual(error as? PackageVerifier.Failure, .signature)
        }
    }
}
