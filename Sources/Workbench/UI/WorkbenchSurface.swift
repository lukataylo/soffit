import SwiftUI

struct WorkbenchSurface: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.09, blue: 0.13),
                            Color(red: 0.14, green: 0.10, blue: 0.14)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(Color(red: 0.45, green: 0.30, blue: 0.55).opacity(0.18))
                        .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                        .blur(radius: 160)
                        .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.2)
                    Circle()
                        .fill(Color(red: 0.30, green: 0.35, blue: 0.55).opacity(0.16))
                        .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                        .blur(radius: 170)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.25)
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.97, blue: 0.93),
                            Color(red: 0.99, green: 0.94, blue: 0.96)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(Color(red: 1.00, green: 0.82, blue: 0.78).opacity(0.55))
                        .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                        .blur(radius: 140)
                        .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.2)
                    Circle()
                        .fill(Color(red: 0.93, green: 0.85, blue: 1.00).opacity(0.5))
                        .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                        .blur(radius: 150)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.25)
                }
            }
        }
        .ignoresSafeArea()
    }
}
