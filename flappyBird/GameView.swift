import SwiftUI

struct GameView: View {
    @State private var vm = GameViewModel()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard size.height > 1 else { return }

                // 1. Gradient sky
                let skyGradient = Gradient(colors: [
                    Color(red: 0.35, green: 0.60, blue: 0.85),
                    Color(red: 0.65, green: 0.82, blue: 0.95)
                ])
                // Solid fill first as fallback in case gradient fails (Metal/IOSurface issues)
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.35, green: 0.60, blue: 0.85))
                )
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        skyGradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 2. Scrolling ground
                let groundY = vm.groundYFraction * size.height
                let tileWidth: Double = 60
                let offset = vm.groundScrollOffset

                var tileX = -(offset.truncatingRemainder(dividingBy: tileWidth))
                while tileX < size.width {
                    let isEven = Int((tileX + offset) / tileWidth) % 2 == 0
                    let dirtColor = isEven
                        ? Color(red: 0.55, green: 0.35, blue: 0.15)
                        : Color(red: 0.50, green: 0.32, blue: 0.12)
                    context.fill(
                        Path(CGRect(x: tileX, y: groundY + 12, width: tileWidth, height: size.height - groundY - 12)),
                        with: .color(dirtColor)
                    )
                    tileX += tileWidth
                }

                var grassX = -(offset.truncatingRemainder(dividingBy: tileWidth))
                while grassX < size.width {
                    let isEven = Int((grassX + offset) / tileWidth) % 2 == 0
                    let grassColor = isEven
                        ? Color(red: 0.28, green: 0.68, blue: 0.18)
                        : Color(red: 0.32, green: 0.72, blue: 0.22)
                    context.fill(
                        Path(CGRect(x: grassX, y: groundY, width: tileWidth, height: 12)),
                        with: .color(grassColor)
                    )
                    grassX += tileWidth
                }

                // 3. Pipes with caps
                for pipe in vm.pipes {
                    let topRect = pipe.topRect()
                    let bottomRect = pipe.bottomRect(screenHeight: size.height)
                    let capHeight: Double = 26
                    let capExtra: Double = 12

                    context.fill(Path(topRect), with: .color(Color(red: 0.2, green: 0.65, blue: 0.2)))
                    context.fill(Path(bottomRect), with: .color(Color(red: 0.2, green: 0.65, blue: 0.2)))

                    let capColor = Color(red: 0.1, green: 0.55, blue: 0.1)
                    context.fill(Path(CGRect(
                        x: pipe.x - capExtra / 2,
                        y: topRect.maxY - capHeight,
                        width: pipe.width + capExtra,
                        height: capHeight
                    )), with: .color(capColor))
                    context.fill(Path(CGRect(
                        x: pipe.x - capExtra / 2,
                        y: bottomRect.minY,
                        width: pipe.width + capExtra,
                        height: capHeight
                    )), with: .color(capColor))
                }

                // 4. Bird with rotation
                let birdX = vm.birdXFraction * size.width
                let birdY = vm.bird.y
                let r = vm.bird.radius

                let clampedVel = max(-400, min(600, vm.bird.velocity))
                let rotationRad = (clampedVel / 600.0 * 90.0) * .pi / 180.0

                var birdContext = context
                birdContext.translateBy(x: birdX, y: birdY)
                birdContext.rotate(by: Angle(radians: rotationRad))

                birdContext.fill(
                    Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 1.0, green: 0.85, blue: 0.0))
                )
                birdContext.fill(
                    Path(ellipseIn: CGRect(x: r * 0.2, y: -r * 0.5, width: 7, height: 7)),
                    with: .color(.white)
                )
                birdContext.fill(
                    Path(ellipseIn: CGRect(x: r * 0.2 + 2, y: -r * 0.5 + 2, width: 3, height: 3)),
                    with: .color(.black)
                )
                var beak = Path()
                beak.move(to: CGPoint(x: r, y: -5))
                beak.addLine(to: CGPoint(x: r + 10, y: 0))
                beak.addLine(to: CGPoint(x: r, y: 5))
                beak.closeSubpath()
                birdContext.fill(beak, with: .color(Color(red: 1.0, green: 0.5, blue: 0.0)))

                // 5. Death flash overlay (drawn last)
                if vm.deathFlashOpacity > 0 {
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color.white.opacity(vm.deathFlashOpacity))
                    )
                }
            }
            .background(Color(red: 0.35, green: 0.60, blue: 0.85))
            .ignoresSafeArea()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
                guard newSize != .zero && newSize != vm.screenSize else { return }
                vm.screenSize = newSize
                vm.reset()
            }
            .onChange(of: timeline.date) { _, newDate in
                vm.update(timestamp: newDate.timeIntervalSinceReferenceDate)
            }
            .gesture(TapGesture().onEnded { vm.flap() })
            .accessibilityLabel("Flappy Bird game canvas")
            .accessibilityAddTraits(.allowsDirectInteraction)
            .overlay(alignment: .top) {
                scoreOverlay.padding(.top, 60)
            }
            .overlay {
                if vm.phase == .waiting { startOverlay }
                if vm.phase == .dead { gameOverOverlay }
            }
        }
    }

    // MARK: - Overlays

    private func medalColor(_ name: String) -> Color {
        switch name {
        case "bronze": return Color(red: 0.80, green: 0.50, blue: 0.20)
        case "silver": return Color(red: 0.75, green: 0.75, blue: 0.75)
        case "gold":   return Color(red: 1.00, green: 0.84, blue: 0.00)
        default:       return .clear
        }
    }

    private func medalEmoji(_ name: String) -> String {
        switch name {
        case "bronze": return "🥉"
        case "silver": return "🥈"
        case "gold":   return "🥇"
        default:       return ""
        }
    }

    private var scoreOverlay: some View {
        Text("\(vm.score)")
            .font(.system(size: 52, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 2, y: 2)
    }

    private var startOverlay: some View {
        VStack(spacing: 12) {
            Text("Flappy Bird")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 2)
            Text("Tap to Start")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text("Game Over")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)

            VStack(spacing: 4) {
                Text("Score: \(vm.score)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Best: \(vm.highScore)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if vm.medalName != "none" {
                Text("\(medalEmoji(vm.medalName)) \(vm.medalName.capitalized) Medal")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(medalColor(vm.medalName))
                    .padding(.top, 4)
            }

            Button(action: {
                vm.reset()
            }) {
                Text("Tap to Retry")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.2, green: 0.7, blue: 0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            }
        }
    }
}

#Preview {
    GameView()
}
