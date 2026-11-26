import SwiftUI
import UIKit
import AVFoundation

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let cream = Color(hex: 0xFFF8F4)
    static let ink = Color(hex: 0x1B1A2E)
    static let flaubBlue = Color(hex: 0x0A5CFF)
    static let blueTint = Color(hex: 0xE3ECFF)
    static let line = Color(hex: 0xEADFD8)
    static let muted = Color(hex: 0x5F5868)
}

extension Font {
    /// System serif (New York). Swap for a bundled Alegreya later if wanted.
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// One place for every haptic, so each page change and choice feels the same.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func page() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Speaks a word with the voice chosen in onboarding or Profile.
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ text: String, language: String? = nil) {
        let chosen = language ?? UserDefaults.standard.string(forKey: "voiceLanguage") ?? "en-US"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: chosen)
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}

// MARK: - Shared pieces

struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Capsule().fill(Color.flaubBlue))
        }
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
    }
}

struct CardStyle: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.line, lineWidth: 1.5)
            )
    }
}

extension View {
    func card(radius: CGFloat = 16) -> some View {
        modifier(CardStyle(radius: radius))
    }
}

/// An illustration that fills its frame, cropped, whatever the image's own size.
struct FillImage: View {
    let name: String

    var body: some View {
        Color.clear
            .overlay(Image(name).resizable().scaledToFill())
            .clipped()
    }
}

struct PremiumBanner: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.serif(22))
                Text(subtitle).font(.system(size: 14))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image("premium")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        }
        .padding(16)
        .background(Color.flaubBlue)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(1)
            .foregroundStyle(Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
