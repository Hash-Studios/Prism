import SwiftUI

extension Color {
  init(argb: Int) {
    let value = UInt32(truncatingIfNeeded: argb)
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: Double((value >> 24) & 0xFF) / 255
    )
  }

  static let prismInk = Color(red: 0.055, green: 0.055, blue: 0.067)
}

/// The Prism logo: Glint's rainbow ring around the white crystal, drawn from the 160 x 160 design box in glint_data.dart.
struct PrismMark: View {
  var size: CGFloat
  var ringOpacity: Double = 1
  var crystal = true

  static let ringColors: [Color] = [
    Color(argb: 0xFFB65CF0), Color(argb: 0xFF9FA6F5), Color(argb: 0xFF4FE3EE), Color(argb: 0xFF7CF0C0),
    Color(argb: 0xFFEDE84E), Color(argb: 0xFFF9A24E), Color(argb: 0xFFF77E7E), Color(argb: 0xFFE45BD6),
    Color(argb: 0xFFB65CF0),
  ]

  static var ring: AngularGradient {
    AngularGradient(colors: ringColors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
  }

  var body: some View {
    ZStack {
      Circle()
        .inset(by: size * 5 / 160)
        .stroke(Self.ring, lineWidth: size * 10 / 160)
        .opacity(ringOpacity)
      if crystal {
        PrismCrystal()
          .frame(width: size * 0.42, height: size * 0.44)
      }
    }
    .frame(width: size, height: size)
  }
}

struct PrismCrystal: View {
  var body: some View {
    ZStack {
      CrystalShape().fill(Color(argb: 0xFFD9DBE8))
      CrystalShape().fill(Color(argb: 0xFFF5F5F7)).mask(alignment: .leading) {
        GeometryReader { proxy in
          Rectangle().frame(width: proxy.size.width / 2)
        }
      }
    }
  }
}

private struct CrystalShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.82))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.82))
    path.closeSubpath()
    return path
  }
}
