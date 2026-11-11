import SwiftUI

/// Barra de progresso fina, desenhada à mão.
/// A ProgressView padrão do watchOS desenha uma barra muito alta que domina a tela.
struct ThinProgressBar: View {
    let progress: Double          // 0...1
    var color: Color = .orange
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
    }
}
