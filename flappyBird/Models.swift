import Foundation
import CoreGraphics

enum GamePhase {
    case waiting, playing, dead
}

struct Bird {
    var y: Double
    var velocity: Double
    let radius: Double = 18

    var rect: CGRect {
        CGRect(x: 0, y: y - radius, width: radius * 2, height: radius * 2)
    }
}

struct Pipe: Identifiable {
    let id = UUID()
    var x: Double
    var gapY: Double
    var scored: Bool = false
    let width: Double = 60
    let gapHeight: Double = 160

    func topRect(screenHeight: Double) -> CGRect {
        CGRect(x: x, y: 0, width: width, height: gapY - gapHeight / 2)
    }

    func bottomRect(screenHeight: Double) -> CGRect {
        let top = gapY + gapHeight / 2
        return CGRect(x: x, y: top, width: width, height: screenHeight - top)
    }
}
