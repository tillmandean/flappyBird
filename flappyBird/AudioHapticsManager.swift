import Foundation
import AudioToolbox
#if os(iOS)
import UIKit
#endif

@MainActor
protocol AudioFeedback {
    func prepareHaptics()
    func playFlap()
    func playScore()
    func playDeath()
}

@MainActor
final class AudioHapticsManager: AudioFeedback {
    #if os(iOS)
    private let flapFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let scoreFeedback = UIImpactFeedbackGenerator(style: .light)
    private let deathFeedback = UINotificationFeedbackGenerator()
    #endif

    func prepareHaptics() {
        #if os(iOS)
        flapFeedback.prepare()
        scoreFeedback.prepare()
        deathFeedback.prepare()
        #endif
    }

    func playFlap() {
        #if os(iOS)
        flapFeedback.impactOccurred()
        AudioServicesPlaySystemSound(1104)
        #endif
    }

    func playScore() {
        #if os(iOS)
        scoreFeedback.impactOccurred()
        AudioServicesPlaySystemSound(1057)
        #endif
    }

    func playDeath() {
        #if os(iOS)
        deathFeedback.notificationOccurred(.error)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        #endif
    }
}
