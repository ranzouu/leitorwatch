import SwiftUI
import Combine

struct RSVPReaderView: View {
    @State var book: Book
    var onProgressUpdate: (Book) -> Void
    
    @AppStorage("reader_default_wpm") private var defaultWpm: Double = 300.0
    @AppStorage("reader_font_design") private var fontDesign: String = "default"
    @AppStorage("reader_theme") private var readerTheme: String = "black"
    
    @State private var wpm: Double = 300.0 // Palavras por minuto
    @State private var isPlaying = false
    @State private var currentWordIndex = 0
    @State private var timer: AnyCancellable? = nil
    
    // Foco para o Digital Crown
    @FocusState private var isCrownFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Indicador de WPM e progresso no topo
            HStack {
                Text("\(Int(wpm)) WPM")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
                Text("\(currentWordIndex + 1)/\(book.words.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 4)
            
            Spacer()
            
            // Exibição da palavra centralizada com foco visual
            if book.words.isEmpty {
                Text("Sem conteúdo")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                let word = book.words[min(currentWordIndex, book.words.count - 1)]
                RSVPWordContainerView(word: word, fontDesign: fontDesign)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width > 20 {
                                    goBackWords(5)
                                } else if value.translation.width < -20 {
                                    goForwardWords(5)
                                }
                            }
                    )
            }
            
            Spacer()
            
            // Barra de progresso compacta
            ThinProgressBar(
                progress: Double(currentWordIndex) / Double(max(1, book.words.count - 1)),
                color: .orange
            )
            .padding(.horizontal, 4)
            
            // Controles de Play, Pause e Navegação
            HStack(spacing: 16) {
                // Voltar 5 palavras
                Button(action: {
                    goBackWords(5)
                }) {
                    Image(systemName: "gobackward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                
                // Play / Pause
                Button(action: {
                    togglePlay()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                
                // Avançar 5 palavras
                Button(action: {
                    goForwardWords(5)
                }) {
                    Image(systemName: "goforward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal)
        .background(Color.themeBackground(for: readerTheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // Suporte à coroa Digital Crown para alterar o WPM
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation($wpm, from: 100.0, through: 800.0, by: 25.0, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear {
            wpm = defaultWpm
            currentWordIndex = book.currentWordIndex
            // Limitar se o índice salvo for maior que o total
            if currentWordIndex >= book.words.count {
                currentWordIndex = 0
            }
            // Foca a coroa automaticamente na abertura da tela
            isCrownFocused = true
        }
        .onChange(of: wpm) { _, _ in
            // Coroa mudou a velocidade: reinicia o timer para o novo ritmo valer na hora
            if isPlaying {
                startTimer()
            }
        }
        .onDisappear {
            saveProgress()
        }
    }
    
    private func togglePlay() {
        isPlaying.toggle()
        WKInterfaceDevice.current().play(.click)
        
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
            saveProgress()
        }
    }
    
    private func startTimer() {
        stopTimer() // Garante que não há múltiplos timers ativos
        
        let interval = 60.0 / wpm
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if currentWordIndex < book.words.count - 1 {
                    currentWordIndex += 1
                } else {
                    // Fim do livro
                    isPlaying = false
                    stopTimer()
                    saveProgress()
                    // Feedback tátil de conclusão
                    WKInterfaceDevice.current().play(.success)
                }
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func goBackWords(_ count: Int) {
        currentWordIndex = max(0, currentWordIndex - count)
        WKInterfaceDevice.current().play(.click)
        saveProgress()
    }
    
    private func goForwardWords(_ count: Int) {
        currentWordIndex = min(book.words.count - 1, currentWordIndex + count)
        WKInterfaceDevice.current().play(.click)
        saveProgress()
    }
    
    private func saveProgress() {
        var updatedBook = book
        updatedBook.currentWordIndex = currentWordIndex
        updatedBook.lastReadTimestamp = Date()
        onProgressUpdate(updatedBook)
    }
}

// Container visual para a palavra RSVP com destaque no caractere central (Optimal Recognition Point - ORP)
struct RSVPWordContainerView: View {
    let word: String
    let fontDesign: String
    
    @AppStorage("reader_theme") private var readerTheme: String = "black"
    
    private var fontSize: CGFloat {
        let length = word.count
        if length <= 5 {
            return 24
        } else if length <= 8 {
            return 21
        } else if length <= 11 {
            return 18
        } else {
            return 15
        }
    }
    
    var body: some View {
        let parts = splitWord(word)
        let currentFontSize = fontSize
        
        HStack(spacing: 0) {
            // Lado Esquerdo (Alinhado à direita)
            Text(parts.prefix)
                .foregroundColor(Color.themeForeground(for: readerTheme).opacity(0.6))
                .font(.readerFont(size: currentFontSize, designString: fontDesign, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Ponto de Foco Central (Destaque em Laranja)
            Text(parts.focus)
                .foregroundColor(.orange)
                .font(.readerFont(size: currentFontSize, designString: fontDesign, weight: .bold))
                .lineLimit(1)
            
            // Lado Direito (Alinhado à esquerda)
            Text(parts.suffix)
                .foregroundColor(Color.themeForeground(for: readerTheme).opacity(0.6))
                .font(.readerFont(size: currentFontSize, designString: fontDesign, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 36) // Mantém a altura estável e evita que a interface trema na troca de palavras
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
    
    // Divide a palavra para alinhar pelo Optimal Recognition Point (normalmente ~30-40% do comprimento da palavra)
    private func splitWord(_ word: String) -> (prefix: String, focus: String, suffix: String) {
        guard !word.isEmpty else { return ("", "", "") }
        
        let length = word.count
        let focusIndex: Int
        
        if length <= 1 {
            focusIndex = 0
        } else if length <= 5 {
            focusIndex = 1
        } else if length <= 9 {
            focusIndex = 2
        } else {
            focusIndex = 3
        }
        
        let start = word.startIndex
        let focusStart = word.index(start, offsetBy: focusIndex)
        let focusEnd = word.index(focusStart, offsetBy: 1)
        
        let prefix = String(word[start..<focusStart])
        let focus = String(word[focusStart..<focusEnd])
        let suffix = String(word[focusEnd..<word.endIndex])
        
        return (prefix, focus, suffix)
    }
}
