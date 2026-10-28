import Foundation
import SCCore

// sc4save <picture> <load format id> <out> <save format id> [existing file]
// Loads the picture the way MegaconvertGS does (true colour pictures are fitted to the
// screen and remapped to 320 mode), then saves it with GS Remap's save format.
// "Add to" formats start from a copy of the existing file.
func fail(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }
let a = CommandLine.arguments
guard a.count >= 5 else { fail("usage: sc4save <picture> <load id> <out> <save id> [existing]") }
let url = URL(fileURLWithPath: a[1])
guard let load = FormatRegistry.loadCategories.flatMap(\.formats).first(where: { $0.id == a[2] }),
      let save = FormatRegistry.saveFormats.first(where: { $0.id == a[4] }) else { fail("unknown format") }

let steps: [(Int, Int)] = [(1, 16), (1, 12), (1, 10), (1, 8), (1, 6), (1, 5), (1, 4), (1, 3), (2, 5), (1, 2),
                           (3, 5), (2, 3), (3, 4), (4, 5), (1, 1)]
func fitted(_ image: TrueColorImage) -> ScreenImage {
    let natural = Remapper.naturalSize(of: image, mode: .mode320)
    var step = 14
    while step > 0 {
        let (n, d) = steps[step]
        if natural.width * n / d <= 320 && natural.height * n / d <= 200 { break }
        step -= 1
    }
    let (n, d) = steps[step]
    let w = min(320, max(1, natural.width * n / d)), h = min(200, max(1, natural.height * n / d))
    return Remapper.remap(image, options: RemapOptions(mode: .mode320, outputWidth: w, outputHeight: h))
}

do {
    var loaded = try load.load(url)
    if case .choice(_, let pick) = loaded { loaded = try pick(0) }
    var screen: ScreenImage
    switch loaded {
    case .screen(let s): screen = s
    case .trueColor(let t): screen = fitted(t)
    case .monochrome(let m):
        var t = TrueColorImage(width: m.width, height: m.height)
        for i in 0..<m.pixels.count where m.pixels[i] != 0 {
            t.rgb[i * 3] = 255; t.rgb[i * 3 + 1] = 255; t.rgb[i * 3 + 2] = 255
        }
        screen = fitted(t)
    case .choice: fail("nested choice")
    }
    // MegaconvertGS holds one screen: the picture is at most a screenful.
    let maxW = screen.is640 ? 640 : 320
    if screen.width > maxW || screen.height > 200 {
        var c = ScreenImage(width: min(maxW, screen.width), height: min(200, screen.height), is640: screen.is640,
                            palettes: screen.palettes)
        for y in 0..<c.height { for x in 0..<c.width { c.pixels[y * c.width + x] = screen.pixels[y * screen.width + x] } }
        c.scbs = Array(screen.scbs.prefix(c.height))
        screen = c
    }
    let out = URL(fileURLWithPath: a[3])
    if a.count > 5 { try? FileManager.default.removeItem(at: out); try FileManager.default.copyItem(atPath: a[5], toPath: a[3]) }
    try save.save(screen, out, SaveOptions())
    print("saved \(screen.width)x\(screen.height) \(screen.is640 ? "640" : "320") mode")
} catch {
    fail("\(error)")
}
