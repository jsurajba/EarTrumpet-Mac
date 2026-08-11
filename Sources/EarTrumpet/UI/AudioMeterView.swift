import SwiftUI

public struct AudioMeterView: View {
    public let level: Float // 0.0 to 1.0
    public var accentColor: Color = Color.teal
    public var height: CGFloat = 4.0
    
    public init(level: Float, accentColor: Color = Color.teal, height: CGFloat = 4.0) {
        self.level = level
        self.accentColor = accentColor
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background meter track
                RoundedRectangle(cornerRadius: height / 2.0)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: height)
                
                // Active peak level fill
                RoundedRectangle(cornerRadius: height / 2.0)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.7), accentColor, Color.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(level))), height: height)
                    .animation(.easeOut(duration: 0.05), value: level)
            }
        }
        .frame(height: height)
    }
}
