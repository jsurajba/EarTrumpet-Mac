import SwiftUI

public struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(spacing: 16) {
            // Trumpet Logo / Header
            Image(systemName: "tuningfork")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 54, height: 54)
                .foregroundColor(.teal)
                .padding(.top, 10)
            
            Text("EarTrumpet for Mac")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text("Version 2.3.0 (macOS Edition)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Original Creator Attribution & Credits")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("EarTrumpet for Mac is a macOS port inspired by and functionally matching the legendary Windows volume control app created by **File-New-Project**.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.teal)
                        Text("Rafael Rivera (@riverar)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.teal)
                        Text("Dave Amenta (@daveamenta)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(.teal)
                        Link("Original Windows Repository (GitHub)", destination: URL(string: "https://github.com/File-New-Project/EarTrumpet")!)
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 12)
        }
        .frame(width: 420, height: 380)
        .padding()
    }
}
