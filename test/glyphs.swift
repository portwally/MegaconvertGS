import CoreGraphics
import CoreText
import Foundation
// Draws Print Char 21 at 8 points, one font unit per pixel, as GS Remap does,
// and prints the 7 x 8 glyphs for $20-$7E as Merlin data (bit 6 = leftmost pixel).
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let provider = CGDataProvider(url: url as CFURL)!
let cgFont = CGFont(provider)!
let font = CTFontCreateWithGraphicsFont(cgFont, 8, nil, nil)
print("* Apple II text glyphs, 7 x 8, for characters $20-$7E: one byte per row,")
print("* bit 6 = leftmost pixel. Drawn from the Print Char 21 font by Kreative Software")
print("* (made by test/glyphs.swift).")
for code in 0x20...0x7E {
    var pixels = [UInt8](repeating: 0, count: 7 * 8)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: 7, height: 8, bitsPerComponent: 8,
                                bytesPerRow: 7, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.setShouldAntialias(false)
        context.setFillColor(gray: 1, alpha: 1)
        var character = [UniChar(code)]
        var glyph = [CGGlyph(0)]
        guard CTFontGetGlyphsForCharacters(font, &character, &glyph, 1) else { return }
        var position = [CGPoint(x: 0, y: 1)]
        CTFontDrawGlyphs(font, &glyph, &position, 1, context)
    }
    let rows = (0..<8).map { row in
        (0..<7).reduce(UInt8(0)) { $0 | (pixels[row * 7 + $1] > 127 ? 0x40 >> UInt8($1) : 0) }
    }
    let label = code == 0x20 ? "Glyphs     " : "           "
    print("\(label) hex   " + rows.map { String(format: "%02X", $0) }.joined() + "    ; " + (code == 0x27 ? "quote" : String(UnicodeScalar(code)!)))
}
