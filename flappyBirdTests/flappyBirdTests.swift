import Testing
import CoreGraphics
@testable import flappyBird

// MARK: - Mock

@MainActor
final class MockAudio: AudioFeedback {
    var prepareCount = 0
    var flapCount = 0
    var scoreCount = 0
    var deathCount = 0

    func prepareHaptics() { prepareCount += 1 }
    func playFlap()       { flapCount += 1 }
    func playScore()      { scoreCount += 1 }
    func playDeath()      { deathCount += 1 }
}

// MARK: - Model Tests

struct BirdTests {
    @Test func radius_isEighteen() {
        let bird = Bird(y: 100, velocity: 0)
        #expect(bird.radius == 18)
    }
}

struct PipeTests {
    @Test func topRect_originIsAtYZero() {
        let pipe = Pipe(x: 100, gapY: 300)
        #expect(pipe.topRect().origin.y == 0)
    }

    @Test func topRect_xMatchesPipeX() {
        let pipe = Pipe(x: 150, gapY: 300)
        #expect(pipe.topRect().origin.x == 150)
    }

    @Test func topRect_heightIsGapYMinusHalfGapHeight() {
        let pipe = Pipe(x: 100, gapY: 300)
        // gapHeight = 160, so height = 300 - 80 = 220
        #expect(pipe.topRect().height == 220)
    }

    @Test func topRect_widthMatchesPipeWidth() {
        let pipe = Pipe(x: 100, gapY: 300)
        #expect(pipe.topRect().width == CGFloat(pipe.width))
    }

    @Test func bottomRect_startsAtGapYPlusHalfGapHeight() {
        let pipe = Pipe(x: 100, gapY: 300)
        // gapHeight = 160, so top of bottom pipe = 300 + 80 = 380
        #expect(pipe.bottomRect(screenHeight: 800).origin.y == 380)
    }

    @Test func bottomRect_extendsToScreenBottom() {
        let pipe = Pipe(x: 100, gapY: 300)
        let rect = pipe.bottomRect(screenHeight: 800)
        #expect(rect.maxY == 800)
    }

    @Test func bottomRect_xMatchesPipeX() {
        let pipe = Pipe(x: 200, gapY: 300)
        #expect(pipe.bottomRect(screenHeight: 800).origin.x == 200)
    }

    @Test func scored_defaultsToFalse() {
        let pipe = Pipe(x: 100, gapY: 300)
        #expect(pipe.scored == false)
    }

    @Test func pipeIds_areUnique() {
        let a = Pipe(x: 100, gapY: 300)
        let b = Pipe(x: 100, gapY: 300)
        #expect(a.id != b.id)
    }
}

// MARK: - GameViewModel Tests

@MainActor
struct GameViewModelInitialStateTests {
    func makeVM() -> (GameViewModel, MockAudio) {
        let audio = MockAudio()
        let vm = GameViewModel(audio: audio)
        vm.screenSize = CGSize(width: 390, height: 844)
        return (vm, audio)
    }

    @Test func phase_isWaiting() {
        let (vm, _) = makeVM()
        #expect(vm.phase == .waiting)
    }

    @Test func score_isZero() {
        let (vm, _) = makeVM()
        #expect(vm.score == 0)
    }

    @Test func pipes_isEmpty() {
        let (vm, _) = makeVM()
        #expect(vm.pipes.isEmpty)
    }

    @Test func deathFlashOpacity_isZero() {
        let (vm, _) = makeVM()
        #expect(vm.deathFlashOpacity == 0)
    }

    @Test func init_callsPrepareHaptics() {
        let audio = MockAudio()
        _ = GameViewModel(audio: audio)
        #expect(audio.prepareCount == 1)
    }
}

@MainActor
struct GameViewModelFlapTests {
    func makeVM() -> (GameViewModel, MockAudio) {
        let audio = MockAudio()
        let vm = GameViewModel(audio: audio)
        vm.screenSize = CGSize(width: 390, height: 844)
        return (vm, audio)
    }

    @Test func flap_inWaiting_transitionsToPlaying() {
        let (vm, _) = makeVM()
        vm.flap()
        #expect(vm.phase == .playing)
    }

    @Test func flap_inWaiting_setsBirdVelocityToFlapImpulse() {
        let (vm, _) = makeVM()
        vm.flap()
        #expect(vm.bird.velocity == -420)
    }

    @Test func flap_inPlaying_setsBirdVelocityToFlapImpulse() {
        let (vm, _) = makeVM()
        vm.flap()
        vm.bird.velocity = 300
        vm.flap()
        #expect(vm.bird.velocity == -420)
    }

    @Test func flap_inDead_doesNotChangePhase() {
        let (vm, _) = makeVM()
        vm.phase = .dead
        vm.flap()
        #expect(vm.phase == .dead)
    }

    @Test func flap_inDead_doesNotChangeVelocity() {
        let (vm, _) = makeVM()
        vm.phase = .dead
        let before = vm.bird.velocity
        vm.flap()
        #expect(vm.bird.velocity == before)
    }

    @Test func flap_playsHapticFeedback() {
        let (vm, audio) = makeVM()
        vm.flap()
        #expect(audio.flapCount == 1)
    }
}

@MainActor
struct GameViewModelPhysicsTests {
    func makeVM() -> GameViewModel {
        let vm = GameViewModel(audio: MockAudio())
        vm.screenSize = CGSize(width: 390, height: 844)
        return vm
    }

    // Helper: advance the VM by one warm-up frame then a real frame of dt seconds
    func advance(_ vm: GameViewModel, dt: Double, baseTimestamp: Double = 1.0) {
        vm.update(timestamp: baseTimestamp)       // warms up lastTimestamp
        vm.update(timestamp: baseTimestamp + dt)  // real physics step
    }

    @Test func update_inWaiting_doesNotMoveBird() {
        let vm = makeVM()
        let initialY = vm.bird.y
        vm.update(timestamp: 1)
        vm.update(timestamp: 1.016)
        #expect(vm.bird.y == initialY)
    }

    @Test func update_withZeroScreenSize_doesNothing() {
        let vm = GameViewModel(audio: MockAudio())
        // screenSize is .zero — no screen size set
        vm.flap()
        let initialY = vm.bird.y
        vm.update(timestamp: 1)
        vm.update(timestamp: 1.016)
        #expect(vm.bird.y == initialY)
    }

    @Test func update_appliesGravityToVelocity() {
        let vm = makeVM()
        vm.flap() // velocity = -420
        let before = vm.bird.velocity
        advance(vm, dt: 0.016)
        // gravity = 1500, dt = 0.016 → velocity increases by ~24
        #expect(vm.bird.velocity > before)
    }

    @Test func update_movesBirdByVelocity() {
        let vm = makeVM()
        vm.flap() // negative velocity → bird moves up
        let before = vm.bird.y
        advance(vm, dt: 0.016)
        #expect(vm.bird.y < before)
    }

    @Test func update_clampsBirdVelocityAtMaximum() {
        let vm = makeVM()
        vm.flap()
        vm.bird.velocity = 900
        advance(vm, dt: 0.016)
        #expect(vm.bird.velocity <= 800)
    }

    @Test func update_clampsBirdVelocityAtMinimum() {
        let vm = makeVM()
        vm.flap()
        vm.bird.velocity = -700
        advance(vm, dt: 0.016)
        #expect(vm.bird.velocity >= -600)
    }
}

@MainActor
struct GameViewModelCollisionTests {
    let screenSize = CGSize(width: 390, height: 844)

    func makeVM() -> GameViewModel {
        let vm = GameViewModel(audio: MockAudio())
        vm.screenSize = screenSize
        return vm
    }

    func triggerOneFrame(_ vm: GameViewModel, base: Double = 1.0) {
        vm.update(timestamp: base)
        vm.update(timestamp: base + 0.016)
    }

    @Test func groundCollision_setsPhaseToDead() {
        let vm = makeVM()
        vm.flap()
        vm.bird.y = screenSize.height   // at or below ground
        triggerOneFrame(vm)
        #expect(vm.phase == .dead)
    }

    @Test func ceilingCollision_setsPhaseToDead() {
        let vm = makeVM()
        vm.flap()
        vm.bird.y = 0                   // at ceiling
        triggerOneFrame(vm)
        #expect(vm.phase == .dead)
    }

    @Test func pipeCollision_topPipe_setsPhaseToDead() {
        let vm = makeVM()
        vm.flap()
        // Place bird inside the top pipe body (far above the gap)
        let birdX = vm.birdXFraction * screenSize.width
        vm.pipes = [Pipe(x: birdX - 30, gapY: 400)]
        vm.bird.y = 50   // gapY - gapHeight/2 = 320, bird at 50 is inside top pipe
        triggerOneFrame(vm)
        #expect(vm.phase == .dead)
    }

    @Test func pipeCollision_bottomPipe_setsPhaseToDead() {
        let vm = makeVM()
        vm.flap()
        // Place bird inside the bottom pipe body (far below the gap)
        let birdX = vm.birdXFraction * screenSize.width
        vm.pipes = [Pipe(x: birdX - 30, gapY: 200)]
        vm.bird.y = 700  // gapY + gapHeight/2 = 280, bird at 700 is inside bottom pipe
        triggerOneFrame(vm)
        #expect(vm.phase == .dead)
    }

    @Test func collision_triggersDeath_setsDeathFlash() {
        let vm = makeVM()
        vm.flap()
        vm.bird.y = screenSize.height
        triggerOneFrame(vm)
        #expect(vm.deathFlashOpacity == 1.0)
    }

    @Test func collision_playsDeathAudio() {
        let audio = MockAudio()
        let vm = GameViewModel(audio: audio)
        vm.screenSize = screenSize
        vm.flap()
        vm.bird.y = screenSize.height
        triggerOneFrame(vm)
        #expect(audio.deathCount == 1)
    }
}

@MainActor
struct GameViewModelScoringTests {
    let screenSize = CGSize(width: 390, height: 844)

    func makeVM() -> (GameViewModel, MockAudio) {
        let audio = MockAudio()
        let vm = GameViewModel(audio: audio)
        vm.screenSize = screenSize
        return (vm, audio)
    }

    @Test func score_incrementsWhenBirdPassesPipeCenter() {
        let (vm, _) = makeVM()
        vm.flap()
        let birdX = vm.birdXFraction * screenSize.width
        // Place a pipe so its center is just behind the bird — scoring condition met
        vm.pipes = [Pipe(x: birdX - 60, gapY: vm.bird.y)]
        vm.update(timestamp: 1)        // warm up lastTimestamp
        vm.update(timestamp: 1.016)    // scoring loop runs
        #expect(vm.score == 1)
    }

    @Test func score_eachPipeOnlyScoredOnce() {
        let (vm, _) = makeVM()
        vm.flap()
        let birdX = vm.birdXFraction * screenSize.width
        vm.pipes = [Pipe(x: birdX - 60, gapY: vm.bird.y)]
        vm.update(timestamp: 1)
        vm.update(timestamp: 1.016)   // scores once
        vm.update(timestamp: 1.032)   // same pipe, should not score again
        #expect(vm.score == 1)
    }

    @Test func score_playsScoreAudio() {
        let (vm, audio) = makeVM()
        vm.flap()
        let birdX = vm.birdXFraction * screenSize.width
        vm.pipes = [Pipe(x: birdX - 60, gapY: vm.bird.y)]
        vm.update(timestamp: 1)
        vm.update(timestamp: 1.016)
        #expect(audio.scoreCount == 1)
    }

    @Test func die_updatesHighScoreWhenNewRecord() {
        let (vm, _) = makeVM()
        vm.highScore = 10
        vm.score = 15
        vm.flap()
        vm.bird.y = screenSize.height  // ground collision
        vm.update(timestamp: 1)
        vm.update(timestamp: 1.016)
        #expect(vm.highScore == 15)
    }

    @Test func die_doesNotLowerHighScore() {
        let (vm, _) = makeVM()
        vm.highScore = 20
        vm.score = 5
        vm.flap()
        vm.bird.y = screenSize.height
        vm.update(timestamp: 1)
        vm.update(timestamp: 1.016)
        #expect(vm.highScore == 20)
    }
}

@MainActor
struct GameViewModelDifficultyTests {
    func makeVM() -> GameViewModel {
        let vm = GameViewModel(audio: MockAudio())
        vm.screenSize = CGSize(width: 390, height: 844)
        return vm
    }

    @Test func pipeSpeed_increasesWithScore() {
        let vm = makeVM()
        vm.score = 0
        let baseSpeed = vm.currentPipeSpeed
        vm.score = 10
        #expect(vm.currentPipeSpeed > baseSpeed)
    }

    @Test func spawnInterval_decreasesWithScore() {
        let vm = makeVM()
        vm.score = 0
        let baseInterval = vm.currentSpawnInterval
        vm.score = 30
        #expect(vm.currentSpawnInterval < baseInterval)
    }

    @Test func spawnInterval_clampsAtMinimum() {
        let vm = makeVM()
        vm.score = 1000   // far past the clamping threshold
        #expect(vm.currentSpawnInterval == 0.9)
    }
}

@MainActor
struct GameViewModelResetTests {
    let screenSize = CGSize(width: 390, height: 844)

    func makeVM() -> GameViewModel {
        let vm = GameViewModel(audio: MockAudio())
        vm.screenSize = screenSize
        return vm
    }

    @Test func reset_clearsPipes() {
        let vm = makeVM()
        vm.pipes = [Pipe(x: 100, gapY: 300), Pipe(x: 200, gapY: 400)]
        vm.reset()
        #expect(vm.pipes.isEmpty)
    }

    @Test func reset_setsScoreToZero() {
        let vm = makeVM()
        vm.score = 15
        vm.reset()
        #expect(vm.score == 0)
    }

    @Test func reset_setsPhaseToWaiting() {
        let vm = makeVM()
        vm.flap()
        vm.reset()
        #expect(vm.phase == .waiting)
    }

    @Test func reset_setsBirdYToFortyFivePercentHeight() {
        let vm = makeVM()
        vm.reset()
        #expect(vm.bird.y == Double(screenSize.height) * 0.45)
    }

    @Test func reset_clearsDeathFlashOpacity() {
        let vm = makeVM()
        vm.deathFlashOpacity = 0.8
        vm.reset()
        #expect(vm.deathFlashOpacity == 0)
    }

    @Test func reset_callsPrepareHaptics() {
        let audio = MockAudio()
        let vm = GameViewModel(audio: audio)
        vm.screenSize = screenSize
        let countBefore = audio.prepareCount
        vm.reset()
        #expect(audio.prepareCount == countBefore + 1)
    }
}

@MainActor
struct GameViewModelMedalTests {
    func makeVM(score: Int) -> GameViewModel {
        let vm = GameViewModel(audio: MockAudio())
        vm.score = score
        return vm
    }

    @Test func medal_scoreZero_isNone()      { #expect(makeVM(score: 0).medalName == "none") }
    @Test func medal_scoreNine_isNone()      { #expect(makeVM(score: 9).medalName == "none") }
    @Test func medal_scoreTen_isBronze()     { #expect(makeVM(score: 10).medalName == "bronze") }
    @Test func medal_scoreNineteen_isBronze(){ #expect(makeVM(score: 19).medalName == "bronze") }
    @Test func medal_scoreTwenty_isSilver()  { #expect(makeVM(score: 20).medalName == "silver") }
    @Test func medal_scoreThirtyNine_isSilver() { #expect(makeVM(score: 39).medalName == "silver") }
    @Test func medal_scoreForty_isGold()     { #expect(makeVM(score: 40).medalName == "gold") }
    @Test func medal_scoreHundred_isGold()   { #expect(makeVM(score: 100).medalName == "gold") }
}
