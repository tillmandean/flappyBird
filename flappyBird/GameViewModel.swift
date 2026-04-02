import SwiftUI

@Observable
class GameViewModel {
    // MARK: - State
    var bird: Bird = Bird(y: 400, velocity: 0)
    var pipes: [Pipe] = []
    var score: Int = 0
    var highScore: Int = 0
    var phase: GamePhase = .waiting
    var deathFlashOpacity: Double = 0

    let audio = AudioHapticsManager()

    // MARK: - Screen Info (set by View on appear)
    var screenSize: CGSize = .zero
    var groundScrollOffset: Double = 0

    // MARK: - Physics Constants
    private let gravity: Double = 1500
    private let flapImpulse: Double = -420
    private let pipeSpeed: Double = 200
    private let pipeSpawnInterval: Double = 1.8
    private let groundYFraction: Double = 0.88
    private let birdXFraction: Double = 0.22

    // MARK: - Simulation State
    private var lastTimestamp: TimeInterval = 0
    private var timeSinceLastPipe: Double = 0

    // MARK: - Difficulty (increases with score)
    private var currentPipeSpeed: Double { pipeSpeed + Double(score) * 2.5 }
    private var currentSpawnInterval: Double { max(0.9, pipeSpawnInterval - Double(score) * 0.02) }

    // MARK: - Init
    init() {
        highScore = UserDefaults.standard.integer(forKey: "flappy_highscore")
        audio.prepareHaptics()
    }

    // MARK: - Public Interface

    func flap() {
        guard phase == .playing || phase == .waiting else { return }
        if phase == .waiting {
            phase = .playing
            lastTimestamp = 0
        }
        bird.velocity = flapImpulse
        audio.playFlap()
    }

    func update(timestamp: TimeInterval) {
        guard phase == .playing else { return }
        guard screenSize != .zero else { return }

        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }

        let dt = min(timestamp - lastTimestamp, 0.05)
        lastTimestamp = timestamp

        // Bird physics
        bird.velocity += gravity * dt
        bird.velocity = max(-600, min(800, bird.velocity))
        bird.y += bird.velocity * dt

        // Ground scroll (visual only, updated here for convenience)
        groundScrollOffset += currentPipeSpeed * dt
        groundScrollOffset = groundScrollOffset.truncatingRemainder(dividingBy: 60)

        // Death flash fade
        if deathFlashOpacity > 0 {
            deathFlashOpacity = max(0, deathFlashOpacity - dt / 0.3)
        }

        // Pipe movement
        for i in pipes.indices {
            pipes[i].x -= currentPipeSpeed * dt
        }
        pipes.removeAll { $0.x < -$0.width - 20 }

        // Pipe spawning
        timeSinceLastPipe += dt
        if timeSinceLastPipe >= currentSpawnInterval {
            timeSinceLastPipe = 0
            let minGapY = screenSize.height * 0.25
            let maxGapY = screenSize.height * 0.72
            let gapY = Double.random(in: minGapY...maxGapY)
            pipes.append(Pipe(x: screenSize.width + 60, gapY: gapY))
        }

        // Scoring
        let birdX = birdXFraction * screenSize.width
        for i in pipes.indices {
            if !pipes[i].scored && pipes[i].x + pipes[i].width / 2 < birdX {
                pipes[i].scored = true
                score += 1
                audio.playScore()
            }
        }

        // Collision detection
        let groundY = groundYFraction * screenSize.height
        if bird.y + bird.radius >= groundY { die(); return }
        if bird.y - bird.radius <= 0 { die(); return }

        let birdRect = CGRect(
            x: birdX - bird.radius,
            y: bird.y - bird.radius,
            width: bird.radius * 2,
            height: bird.radius * 2
        )
        for pipe in pipes {
            if birdRect.intersects(pipe.topRect(screenHeight: screenSize.height)) ||
               birdRect.intersects(pipe.bottomRect(screenHeight: screenSize.height)) {
                die()
                return
            }
        }
    }

    func reset() {
        bird = Bird(y: screenSize.height * 0.45, velocity: 0)
        pipes = []
        score = 0
        phase = .waiting
        lastTimestamp = 0
        timeSinceLastPipe = 0
        deathFlashOpacity = 0
        groundScrollOffset = 0
    }

    var medalName: String {
        switch score {
        case 0..<10:  return "none"
        case 10..<20: return "bronze"
        case 20..<40: return "silver"
        default:      return "gold"
        }
    }

    // MARK: - Private

    private func die() {
        phase = .dead
        deathFlashOpacity = 1.0
        audio.playDeath()
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "flappy_highscore")
        }
    }
}
