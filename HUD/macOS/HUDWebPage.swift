import Foundation

/// The HUD page is embedded in the binary so a phone only needs the Mac's
/// address — there is no bundle to copy and nothing to fetch from the internet.
enum HUDWebPage {
    static let html: String = String(decoding: PackageResources.hud_html, as: UTF8.self)
}
