// SPDX-License-Identifier: MIT

import Foundation

/// A release as the GitHub API gives it; only what the kit reads.
public struct GitHubRelease: Decodable, Sendable, Equatable {
    public struct Asset: Decodable, Sendable, Equatable {
        public let name: String
        public let size: Int
        public let url: URL

        enum CodingKeys: String, CodingKey { case name, size, url = "browser_download_url" }

        public init(name: String, size: Int, url: URL) {
            self.name = name
            self.size = size
            self.url = url
        }
    }

    public let tag: String
    public let draft: Bool
    public let prerelease: Bool
    public let page: URL
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey { case tag = "tag_name", draft, prerelease, page = "html_url", assets }

    public init(tag: String, draft: Bool = false, prerelease: Bool = false, page: URL, assets: [Asset]) {
        self.tag = tag
        self.draft = draft
        self.prerelease = prerelease
        self.page = page
        self.assets = assets
    }
}

/// A release that can be installed: its label, its page, its package and the file that says the checksum of the package.
public struct UpdateOffer: Codable, Equatable, Sendable {
    public let tag: String
    public let label: ReleaseLabel
    public let page: URL
    public let packageName: String
    public let packageURL: URL
    public let packageSize: Int
    public let checksumURL: URL?
}

public enum UpdateFeed {
    /// The releases of a repository, newest first, 100 at most (the collection has some twenty).
    public static func feedURL(repository: String) -> URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=100")!
    }

    public static func decode(_ data: Data) throws -> [GitHubRelease] {
        try JSONDecoder().decode([GitHubRelease].self, from: data)
    }

    /// The newest release of the tool: its tag begins with `tagPrefix`, it is neither a draft nor a pre-release, and it has a `.pkg`.
    /// A repository holds the releases of several tools (and of the collection as a whole), so "the latest release" of GitHub is not it.
    public static func newestOffer(in releases: [GitHubRelease], tagPrefix: String) -> UpdateOffer? {
        var best: UpdateOffer?
        for release in releases where !release.draft && !release.prerelease {
            guard let label = ReleaseLabel.parse(tag: release.tag, prefix: tagPrefix),
                  let package = release.assets.first(where: { $0.name.hasSuffix(".pkg") }) else { continue }
            if let best, best.label.version >= label.version { continue }
            let checksum = release.assets.first { $0.name == package.name + ".sha256" }
            best = UpdateOffer(tag: release.tag, label: label, page: release.page, packageName: package.name,
                               packageURL: package.url, packageSize: package.size, checksumURL: checksum?.url)
        }
        return best
    }
}
