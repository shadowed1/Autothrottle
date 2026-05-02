import SwiftUI

// GradientSlider
// Created by shadowed1

struct GradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private let gradientColors: [Color] = [
        Color(red: 0.45, green: 0.65, blue: 0.85),
        .blue,
        .cyan,
        .green,
        .yellow,
        .orange,
        .red,
        .pink,
        .purple
    ]

    private var fraction: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geo in
            let thumbDiameter: CGFloat = 20
            let trackHeight: CGFloat = 5
            let usable = geo.size.width - thumbDiameter
            let filledWidth = thumbDiameter / 2 + CGFloat(fraction) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: trackHeight)

                LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    .frame(height: trackHeight)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: filledWidth)
                    }

                Circle()
                    .fill(.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: CGFloat(fraction) * usable)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let raw = (drag.location.x - thumbDiameter / 2) / usable
                                let clamped = min(max(Double(raw), 0), 1)
                                let rawVal = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                                let stepped = (rawVal / step).rounded() * step
                                value = min(max(stepped, range.lowerBound), range.upperBound)
                            }
                    )
            }
            .frame(height: thumbDiameter)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let raw = (location.x - thumbDiameter / 2) / usable
                let clamped = min(max(Double(raw), 0), 1)
                let rawVal = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                let stepped = (rawVal / step).rounded() * step
                value = min(max(stepped, range.lowerBound), range.upperBound)
            }
        }
        .frame(height: 20)
    }
}
