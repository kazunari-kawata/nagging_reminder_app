import SwiftUI

// MARK: - OnboardingStep

private struct OnboardingStep: Identifiable {
  let id: Int
  let systemImage: String
  let imageColor: Color
  let title: LocalizedStringResource
  let description: LocalizedStringResource
}

private let steps: [OnboardingStep] = [
  OnboardingStep(
    id: 0,
    systemImage: "plus.circle.fill",
    imageColor: .blue,
    title: "onboarding.step1.title",
    description: "onboarding.step1.description"
  ),
  OnboardingStep(
    id: 1,
    systemImage: "hand.draw.fill",
    imageColor: .green,
    title: "onboarding.step2.title",
    description: "onboarding.step2.description"
  ),
  OnboardingStep(
    id: 2,
    systemImage: "trash.fill",
    imageColor: .red,
    title: "onboarding.step3.title",
    description: "onboarding.step3.description"
  ),
]

// MARK: - OnboardingView

struct OnboardingView: View {
  @Environment(AppSettings.self) private var settings
  @State private var currentStep = 0

  var body: some View {
    VStack(spacing: 0) {
      // Page indicator
      HStack(spacing: 8) {
        ForEach(steps) { step in
          Capsule()
            .fill(currentStep == step.id ? Color.accentColor : Color(.systemGray4))
            .frame(width: currentStep == step.id ? 20 : 8, height: 8)
            .animation(.spring(response: 0.3), value: currentStep)
        }
      }
      .padding(.top, 24)

      // Step content
      TabView(selection: $currentStep) {
        ForEach(steps) { step in
          stepPage(step)
            .tag(step.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(.easeInOut, value: currentStep)

      // Buttons
      VStack(spacing: 12) {
        if currentStep < steps.count - 1 {
          Button {
            withAnimation { currentStep += 1 }
          } label: {
            Text(LocalizedStringResource("onboarding.button.next"))
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(Color.accentColor)
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }

          Button {
            settings.tutorialCompleted = true
          } label: {
            Text(LocalizedStringResource("onboarding.button.skip"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        } else {
          Button {
            settings.tutorialCompleted = true
          } label: {
            Text(LocalizedStringResource("onboarding.button.start"))
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(Color.accentColor)
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 48)
    }
    .background(Color(.systemGroupedBackground).ignoresSafeArea())
  }

  // MARK: - Step Page

  private func stepPage(_ step: OnboardingStep) -> some View {
    VStack(spacing: 32) {
      Spacer()

      // Illustration
      ZStack {
        Circle()
          .fill(step.imageColor.opacity(0.12))
          .frame(width: 140, height: 140)
        Image(systemName: step.systemImage)
          .resizable()
          .scaledToFit()
          .frame(width: 64, height: 64)
          .foregroundStyle(step.imageColor)
      }

      // Swipe hint animation for step 1 and 2
      if step.id == 1 {
        SwipeHintView(direction: .left, amount: .short, color: .green)
      } else if step.id == 2 {
        SwipeHintView(direction: .left, amount: .long, color: .red)
      }

      VStack(spacing: 12) {
        Text(step.title)
          .font(.title2.bold())
          .multilineTextAlignment(.center)
        Text(step.description)
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .lineSpacing(4)
      }
      .padding(.horizontal, 32)

      Spacer()
      Spacer()
    }
  }
}

// MARK: - SwipeHintView

private struct SwipeHintView: View {
  enum Direction { case left, right }
  enum Amount { case short, long }

  let direction: Direction
  let amount: Amount
  let color: Color

  @State private var offset: CGFloat = 0
  @State private var opacity: Double = 0

  private var targetOffset: CGFloat {
    let base: CGFloat = direction == .right ? 1 : -1
    return base * (amount == .short ? 50 : 120)
  }
  private var arrowName: String { direction == .right ? "arrow.right" : "arrow.left" }

  var body: some View {
    ZStack {
      // Mock task card
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(.secondarySystemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .frame(width: 280, height: 60)

      // Finger + arrow(s)
      HStack(spacing: 4) {
        if direction == .right {
          Image(systemName: arrowName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(color)
          if amount == .long {
            Image(systemName: arrowName)
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(color.opacity(0.5))
          }
          Image(systemName: "hand.point.right.fill")
            .font(.system(size: 28))
            .foregroundStyle(.primary)
        } else {
          Image(systemName: "hand.point.left.fill")
            .font(.system(size: 28))
            .foregroundStyle(.primary)
          Image(systemName: arrowName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(color)
          if amount == .long {
            Image(systemName: arrowName)
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(color.opacity(0.5))
          }
        }
      }
      .offset(x: offset)
      .opacity(opacity)
    }
    .onAppear { startAnimation() }
  }

  private func startAnimation() {
    offset = 0
    opacity = 0
    withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
    withAnimation(.easeInOut(duration: 0.7).delay(0.3)) { offset = targetOffset }
    withAnimation(.easeOut(duration: 0.3).delay(1.0)) { opacity = 0 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { startAnimation() }
  }
}

// MARK: - Preview

#Preview {
  OnboardingView()
    .environment(AppSettings())
}
