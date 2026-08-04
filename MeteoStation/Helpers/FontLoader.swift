import CoreText
import Foundation

/// Enregistre les polices embarquées (DSEG 7/14 segments, licence SIL OFL)
/// pour le process courant.
enum FontLoader {
    static func registerBundledFonts() {
        for ext in ["ttf", "otf"] {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
