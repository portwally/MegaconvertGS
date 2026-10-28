import Foundation
import SCCore

// sc4filter <in.rgb> <width> <height> <out.rgb> <op> [factor]
// Applies one of GS Remap's True color filters, or its rotate/flip, to raw RGB bytes
// (as MegaconvertGS's SAVE RGB writes them) and writes the result the same way.
// op: 0 histogram equalization, 1 median, 2 sigma, 3 emboss, 4 blur, 5 sharpen,
// 6 solarize, 7 find edges, 8 increase contrast, 9 decrease contrast (the FILTER
// test command's numbers); tN: rotate/flip with bits N (1 mirror, 2 flip, 4 turn).
// Prints the result's width and height.
func fail(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }
let a = CommandLine.arguments
guard a.count >= 6, let w = Int(a[2]), let h = Int(a[3]) else {
    fail("usage: sc4filter <in.rgb> <width> <height> <out.rgb> <op> [factor]")
}
guard let data = FileManager.default.contents(atPath: a[1]), data.count == w * h * 3 else {
    fail("the RGB file isn't width x height x 3 bytes")
}
let factor = a.count > 6 ? Int(a[6]) ?? 50 : 50
let image = TrueColorImage(width: w, height: h, rgb: [UInt8](data))
let out: TrueColorImage
if a[5].hasPrefix("t"), let bits = Int(a[5].dropFirst()) {
    out = image.transformed(bits)
} else {
    switch Int(a[5]) ?? -1 {
    case 0: out = Filters.equalize(image)
    case 1: out = Filters.median(image)
    case 2: out = Filters.sigma(image)
    case 3: out = Filters.emboss(image)
    case 4: out = Filters.blur(image, factor: factor)
    case 5: out = Filters.sharpen(image, factor: factor)
    case 6: out = Filters.solarize(image)
    case 7: out = Filters.findEdges(image, factor: factor)
    case 8: out = Filters.contrast(image, increase: true)
    case 9: out = Filters.contrast(image, increase: false)
    default: fail("unknown operation")
    }
}
try Data(out.rgb).write(to: URL(fileURLWithPath: a[4]))
print("\(out.width) \(out.height)")
