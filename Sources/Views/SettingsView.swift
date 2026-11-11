import SwiftUI

struct SettingsView: View {
    @AppStorage("reader_font_size") private var fontSize: Double = 16.0
    @AppStorage("reader_font_design") private var fontDesign: String = "default"
    @AppStorage("reader_default_wpm") private var defaultWpm: Double = 300.0
    @AppStorage("reader_theme") private var readerTheme: String = "black"
    
    let designs = ["default", "serif", "rounded", "monospaced"]
    let themes = ["black", "gray", "sepia", "green"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Ajuste de Tamanho da Fonte
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tamanho da Fonte")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        Button(action: {
                            adjustFontSize(-1)
                        }) {
                            Text("A-")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                        
                        Spacer()
                        
                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        
                        Spacer()
                        
                        Button(action: {
                            adjustFontSize(1)
                        }) {
                            Text("A+")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                    }
                }
                
                Divider()
                
                // Escolha do Design da Fonte
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estilo da Fonte")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    ForEach(designs, id: \.self) { design in
                        Button(action: {
                            fontDesign = design
                            WKInterfaceDevice.current().play(.click)
                        }) {
                            HStack {
                                Text(displayDesignName(design))
                                    .font(getFontForPreview(design))
                                    .foregroundColor(.white)
                                Spacer()
                                if fontDesign == design {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(fontDesign == design ? .blue.opacity(0.15) : .gray.opacity(0.1))
                    }
                }
                
                Divider()
                
                // Escolha do Tema de Fundo
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tema de Fundo")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    ForEach(themes, id: \.self) { theme in
                        Button(action: {
                            readerTheme = theme
                            WKInterfaceDevice.current().play(.click)
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color.themeBackground(for: theme))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(.trailing, 4)
                                
                                Text(displayThemeName(theme))
                                    .foregroundColor(.white)
                                    .font(.system(size: 13, weight: .medium))
                                
                                Spacer()
                                
                                if readerTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(readerTheme == theme ? .blue.opacity(0.15) : .gray.opacity(0.1))
                    }
                }
                
                Divider()
                
                // Velocidade RSVP Padrão
                VStack(alignment: .leading, spacing: 4) {
                    Text("Velocidade RSVP")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        Button(action: {
                            adjustWPM(-25)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange.opacity(0.15))
                        .frame(width: 32, height: 32)
                        
                        Spacer()
                        
                        Text("\(Int(defaultWpm)) WPM")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button(action: {
                            adjustWPM(25)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange.opacity(0.15))
                        .frame(width: 32, height: 32)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Ajustes")
    }
    
    private func adjustFontSize(_ delta: Double) {
        fontSize = max(10.0, min(24.0, fontSize + delta))
        WKInterfaceDevice.current().play(.click)
    }
    
    private func adjustWPM(_ delta: Double) {
        defaultWpm = max(100.0, min(800.0, defaultWpm + delta))
        WKInterfaceDevice.current().play(.click)
    }
    
    private func displayDesignName(_ raw: String) -> String {
        switch raw {
        case "default": return "Padrão"
        case "serif": return "Serifa (Georgia)"
        case "rounded": return "Arredondado"
        case "monospaced": return "Espaçado"
        default: return raw.capitalized
        }
    }
    
    private func displayThemeName(_ raw: String) -> String {
        switch raw {
        case "black": return "Preto Absoluto"
        case "gray": return "Cinza Escuro"
        case "sepia": return "Sépia Escuro"
        case "green": return "Verde Floresta"
        default: return raw.capitalized
        }
    }
    
    private func getFontForPreview(_ raw: String) -> Font {
        let design: Font.Design
        switch raw {
        case "serif": design = .serif
        case "rounded": design = .rounded
        case "monospaced": design = .monospaced
        default: design = .default
        }
        return Font.system(size: 13, weight: .semibold, design: design)
    }
}

// Extensão utilitária para obter Font.Design baseada na string salva
extension Font {
    static func readerFont(size: CGFloat, designString: String, weight: Font.Weight = .regular) -> Font {
        let design: Font.Design
        switch designString {
        case "serif": design = .serif
        case "rounded": design = .rounded
        case "monospaced": design = .monospaced
        default: design = .default
        }
        return Font.system(size: size, weight: weight, design: design)
    }
}

// Extensão para cores e fundos temáticos nos leitores
extension Color {
    static func themeBackground(for theme: String) -> Color {
        switch theme {
        case "gray":
            return Color(white: 0.12)
        case "sepia":
            return Color(red: 0.15, green: 0.12, blue: 0.09)
        case "green":
            return Color(red: 0.08, green: 0.13, blue: 0.09)
        default:
            return Color.black
        }
    }
    
    static func themeForeground(for theme: String) -> Color {
        if theme == "sepia" {
            return Color(red: 0.95, green: 0.92, blue: 0.85)
        }
        return Color.white
    }
}
