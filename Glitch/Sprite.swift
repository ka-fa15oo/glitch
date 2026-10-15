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

    private static func loadShared(_ name: String) -> CGImage {
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
