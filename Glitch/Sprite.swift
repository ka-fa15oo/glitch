import AppKit

/// The four turnarounds. Every one has the same parts and the same rig; only the art and joint positions differ.
enum ViewKind: CaseIterable {
    case threeQuarter

    var prefix: String {
        switch self {
        case .threeQuarter: ""
        }
    }
}

/// Every body part of one view as a 72x96 image (see Tools/make_sprites.py and Tools/make_views.py).
final class SpriteSet: @unchecked Sendable {
    let cape: CGImage
    let capeRows: [CGImage]
    let thighL, shinL, footL, thighR, shinR, footR: CGImage
    let sash, tunic, cloak, pauldronFar, pauldronNear: CGImage
    let armFarUpper, armFarFore, armNearUpper, armNearFore: CGImage
    let head: CGImage
    let eyes: [Brain.EyeKind: CGImage]

    init(prefix: String) {
        func load(_ name: String) -> CGImage {
            guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
                  let image = NSImage(contentsOf: url),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else { fatalError("Missing sprite \(name).png") }
            return cg
        }
        func part(_ name: String) -> CGImage { load(prefix + name) }
        let capeImage = part("cape")
        cape = capeImage
        capeRows = stride(from: 0, to: Sprite.height, by: 2).compactMap {
            capeImage.cropping(to: CGRect(x: 0, y: $0, width: Sprite.width, height: 2))
        }
        thighL = part("thighL"); shinL = part("shinL"); footL = part("footL")
        thighR = part("thighR"); shinR = part("shinR"); footR = part("footR")
        sash = part("sash"); tunic = part("tunic"); cloak = part("cloak")
        pauldronFar = part("pauldronFar"); pauldronNear = part("pauldronNear")
        armFarUpper = part("armFarUpper"); armFarFore = part("armFarFore")
        armNearUpper = part("armNearUpper"); armNearFore = part("armNearFore")
        head = part("head")
        eyes = [
            .open: part("eyes_open"), .half: part("eyes_half"), .closed: part("eyes_closed"),
            .wide: part("eyes_wide"), .angry: part("eyes_angry"), .happy: part("eyes_happy"),
        ]
    }
}

enum Sprite {
    static let width = 72
    static let height = 96

    static let shadow: CGImage = loadShared("shadow")
    static let sword: CGImage = loadShared("sword")

    /// Loaded once, on first use.
    static let sets: [ViewKind: SpriteSet] = Dictionary(
        uniqueKeysWithValues: ViewKind.allCases.map { ($0, SpriteSet(prefix: $0.prefix)) }
    )

    /// Which pixels of the 72x96 grid the standing character covers (all body parts plus the sword at rest),
    /// so clicks only count on the character itself and fall through everywhere else.
    /// shortcut: built from the rest pose; a raised arm or sword mid-move is matched only near its rest place.
    private static let knightMask: [Bool] = {
        let set = sets[.threeQuarter]!
        let parts = [set.cape, set.thighL, set.shinL, set.footL, set.thighR, set.shinR, set.footR, set.sash, set.tunic,
                     set.cloak, set.pauldronFar, set.pauldronNear, set.armFarUpper, set.armFarFore, set.armNearUpper,
                     set.armNearFore, set.head]
        // the sword hangs at the hip, shifted from where its PNG puts it
        let shift = CGPoint(x: Skeleton.grip.x - Skeleton.spriteGrip.x, y: Skeleton.grip.y - Skeleton.spriteGrip.y)
        return coverage(parts.map { ($0, CGPoint.zero) } + [(sword, shift)])
    }()
    private static let knightBounds = bounds(of: knightMask)

    /// The selected character's mask and the box round it (Wizzy has its own shape: staff, hood and cape).
    static var hitMask: [Bool] {
        Mage.isSelected ? Mage.hitMask : Elf.isSelected ? Elf.hitMask : Phoenix.isSelected ? Phoenix.hitMask : knightMask
    }
    static var hitBounds: CGRect {
        Mage.isSelected ? Mage.hitBounds : Elf.isSelected ? Elf.hitBounds : Phoenix.isSelected ? Phoenix.hitBounds : knightBounds
    }

    /// Which grid pixels these images cover, each moved by its offset in art pixels (y grows down).
    static func coverage(_ images: [(CGImage, CGPoint)]) -> [Bool] {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            let full = CGRect(x: 0, y: 0, width: width, height: height)
            for (image, shift) in images { ctx.draw(image, in: full.offsetBy(dx: shift.x, dy: -shift.y)) }   // CG y grows up
        }
        return (0 ..< width * height).map { data[$0 * 4 + 3] > 20 }
    }

    /// The box round every covered pixel of a mask.
    static func bounds(of mask: [Bool]) -> CGRect {
        var minX = width, maxX = 0, minY = height, maxY = 0
        for y in 0 ..< height {
            for x in 0 ..< width where mask[y * width + x] {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// True when (x, y) on the sprite grid, or a pixel right next to it, is part of the character.
    static func hit(_ x: Int, _ y: Int) -> Bool {
        let hitMask = hitMask
        for dy in -1 ... 1 {
            for dx in -1 ... 1 {
                let px = x + dx, py = y + dy
                if px >= 0, py >= 0, px < width, py < height, hitMask[py * width + px] { return true }
            }
        }
        return false
    }

    static func loadShared(_ name: String) -> CGImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { fatalError("Missing sprite \(name).png") }
        return cg
    }
}

/// Joint positions of the 3/4 view (art pixels). The brain describes poses in these coordinates;
/// other views translate them through their own `Rig`.
enum Skeleton {
    static let neck = CGPoint(x: 39, y: 36)
    static let waist = CGPoint(x: 39, y: 58)

    static let shoulderNear = CGPoint(x: 51, y: 38)
    static let elbowNear = CGPoint(x: 55, y: 49)
    static let handNear = CGPoint(x: 42.5, y: 53.7)

    static let shoulderFar = CGPoint(x: 29, y: 38)
    static let elbowFar = CGPoint(x: 25, y: 48)
    static let handFar = CGPoint(x: 35.5, y: 56)

    static let hipL = CGPoint(x: 38, y: 60)
    static let kneeL = CGPoint(x: 33, y: 74)
    static let ankleL = CGPoint(x: 28, y: 88)
    static let hipR = CGPoint(x: 44, y: 60)
    static let kneeR = CGPoint(x: 47, y: 74)
    static let ankleR = CGPoint(x: 50, y: 88)

    /// Where the hilt sits on the sword sprite itself.
    static let spriteGrip = CGPoint(x: 39.2, y: 54.5)
    /// Where the hilt rests: one hand low at the hip, blade angled down and forward, tip near the ground.
    static let grip = CGPoint(x: 37, y: 58)
    static let swordRestRot = 0.12
    /// The free hand rests on the hip.
    static let relaxedNear = CGPoint(x: 47.5, y: 58.5)
    static let gripNearOffset = CGPoint(x: 3.3, y: -0.8)
    static let gripFarOffset = CGPoint(x: -3.7, y: 1.5)
}

/// The skeleton of one view. Sizes of bones follow from these joint positions.
struct Rig {
    var neck: CGPoint
    var waist: CGPoint
    var shoulderNear, elbowNear, handNear: CGPoint
    var shoulderFar, elbowFar, handFar: CGPoint
    var hipL, kneeL, ankleL, hipR, kneeR, ankleR: CGPoint
    var grip: CGPoint
    var relaxedNear: CGPoint
    var footDX: Double          // boot centre relative to the ankle (toes point left in side views)
    var capeInFront: Bool       // false in every view that remains; kept for clarity of the rig

    static func of(_ view: ViewKind) -> Rig {
        switch view {
        case .threeQuarter:
            Rig(neck: Skeleton.neck, waist: Skeleton.waist,
                shoulderNear: Skeleton.shoulderNear, elbowNear: Skeleton.elbowNear, handNear: Skeleton.handNear,
                shoulderFar: Skeleton.shoulderFar, elbowFar: Skeleton.elbowFar, handFar: Skeleton.handFar,
                hipL: Skeleton.hipL, kneeL: Skeleton.kneeL, ankleL: Skeleton.ankleL,
                hipR: Skeleton.hipR, kneeR: Skeleton.kneeR, ankleR: Skeleton.ankleR,
                grip: Skeleton.grip, relaxedNear: Skeleton.relaxedNear, footDX: -3, capeInFront: false)
        }
    }
}
