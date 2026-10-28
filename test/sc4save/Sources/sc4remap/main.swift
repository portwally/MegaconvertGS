import Foundation
import SCCore

// sc4remap <picture> <load format id> <out.c1> <mode> <palette> <algorithm> <h step> <v step> <other>
//          [<screen.c1>: palette 5, the stored palette, from Store palette on that screen]
// Remaps the way GS Remap's Remap dialog does (AppModel.runRemap), with the picture kept
// to one screen as MegaconvertGS keeps it. mode 0-3; palette 0 calculated, 1 default,
// 2 greys, 3 other, 4 the picture's current; algorithm 0 closest, 1 pattern, 2 error
// diffusion; steps 0-22 (14 is 1:1), 255: fitted to the screen; other: which other palette
// (multipalette: technique). Mode q: Quick remap (the other numbers are ignored).
// The picture's current palette is the screen's own for a screen picture; a true colour
// picture is first remapped as MegaconvertGS's Open remaps it (320 mode, calculated,
// pattern dither, fitted), and that screen's palette is the current one.
func fail(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }
let a = CommandLine.arguments
if a.count >= 5 && a[4] == "q" {
    guard let load = FormatRegistry.loadCategories.flatMap(\.formats).first(where: { $0.id == a[2] }) else {
        fail("unknown format")
    }
    do {
        var loaded = try load.load(URL(fileURLWithPath: a[1]))
        if case .choice(_, let pick) = loaded { loaded = try pick(0) }
        let image: TrueColorImage
        switch loaded {
        case .screen(let s): image = s.toTrueColor()
        case .trueColor(let t): image = t
        default: fail("not a picture to remap")
        }
        let screen = Remapper.quickRemap(image)
        try Data(SHRFormats.saveScreen(screen)).write(to: URL(fileURLWithPath: a[3]))
        print("quick \(screen.width)x\(screen.height)")
    } catch {
        fail("\(error)")
    }
    exit(0)
}
guard a.count == 10 || a.count == 11, let mode = GraphicMode(rawValue: Int(a[4]) ?? -1), let pal = Int(a[5]),
      var algorithm = RenderAlgorithm(rawValue: Int(a[6]) ?? -1), var hStep = Int(a[7]), var vStep = Int(a[8]),
      let other = Int(a[9]) else { fail("usage: sc4remap <picture> <load id> <out.c1> mode pal alg h v other") }
guard let load = FormatRegistry.loadCategories.flatMap(\.formats).first(where: { $0.id == a[2] }) else {
    fail("unknown format")
}
let steps: [(Int, Int)] = [(1, 16), (1, 12), (1, 10), (1, 8), (1, 6), (1, 5), (1, 4), (1, 3), (2, 5), (1, 2),
                           (3, 5), (2, 3), (3, 4), (4, 5), (1, 1), (5, 4), (4, 3), (3, 2), (5, 3), (2, 1),
                           (5, 2), (3, 1), (4, 1)]
do {
    var loaded = try load.load(URL(fileURLWithPath: a[1]))
    if case .choice(_, let pick) = loaded { loaded = try pick(0) }
    let image: TrueColorImage
    var current: ScreenImage
    switch loaded {
    case .screen(let s): image = s.toTrueColor(); current = s
    case .trueColor(let t):
        image = t
        let n = Remapper.naturalSize(of: t, mode: .mode320)
        var step = 14
        while step > 0 {
            let (sn, sd) = steps[step]
            if n.width * sn / sd <= 320 && n.height * sn / sd <= 200 { break }
            step -= 1
        }
        let (sn, sd) = steps[step]
        let w = max(1, n.width * sn / sd), h = max(1, n.height * sn / sd)
        current = Remapper.remap(t, options: RemapOptions(mode: .mode320, prototype: .calculated(.mode320),
                                                         algorithm: .patternDither, outputWidth: w, outputHeight: h))
    default: fail("not a picture to remap")
    }
    let screenWidth = mode.is640 ? 640 : 320
    let natural = Remapper.naturalSize(of: image, mode: mode)
    if hStep == 255 || vStep == 255 {                      // fitScaleToScreen
        var step = 14
        while step > 0 {
            let (n, d) = steps[step]
            if natural.width * n / d <= screenWidth && natural.height * n / d <= 200 { break }
            step -= 1
        }
        hStep = step; vStep = step
    }
    // prototype(for:) and normalise()
    var prototype: PalettePrototype?
    switch pal {
    case 1: prototype = mode == .multipalette ? nil : .defaultColor(mode)
    case 2: prototype = mode == .multipalette ? nil : .grayscale(mode)
    case 4:
        prototype = current.is640 == mode.is640 && mode != .multipalette ?
            .fixed("Picture's current", palette: current.palettes[0], mode: mode) : nil
    case 5:
        // Stored palette: Store palette on the $C1 screen file given last (AppModel.storePalette)
        if a.count == 11, let d = FileManager.default.contents(atPath: a[10]),
           let s = try? SHRFormats.loadScreen([UInt8](d)) {
            let stored: GraphicMode = !s.is640 ? .mode320
                : (Array(s.palettes[0][0..<4]) == Array(s.palettes[0][4..<8]) ? .mode640 : .mode640Dither)
            prototype = stored == mode ? .fixed("Stored palette", palette: s.palettes[0], mode: mode) : nil
        } else { prototype = nil }
    case 3:
        if mode == .multipalette { prototype = .calculated(mode) } else {
            let list = PalettePrototype.others(mode)
            prototype = list[min(other, list.count - 1)]
        }
    default: prototype = .calculated(mode)
    }
    var palette = pal
    if prototype == nil { palette = 0; prototype = .calculated(mode) }
    let diffusionAllowed = mode != .multipalette && (prototype?.isGrey ?? false)
    if algorithm == .errorDiffusion && !diffusionAllowed { algorithm = .patternDither }
    // outputSize(), clipped to one screen
    let (hn, hd) = steps[hStep], (vn, vd) = steps[vStep]
    let w = max(1, natural.width * hn / hd), h = max(1, natural.height * vn / vd)
    let cw = min(w, screenWidth), ch = min(h, 200)
    var source = image
    if (cw, ch) != (w, h) {
        source = image.cropped(width: image.width * cw / w, height: image.height * ch / h)
    }
    var options = RemapOptions(mode: mode, prototype: prototype, algorithm: algorithm, outputWidth: cw, outputHeight: ch)
    if mode == .multipalette && palette == 3 {
        options.multipalette = MultipaletteOption(rawValue: other + 1) ?? .standard
    }
    let screen = Remapper.remap(source, options: options)
    try Data(SHRFormats.saveScreen(screen)).write(to: URL(fileURLWithPath: a[3]))
    print("\(screen.width)x\(screen.height) \(screen.is640 ? "640" : "320") mode, \(screen.palettes.count) palettes")
} catch {
    fail("\(error)")
}
