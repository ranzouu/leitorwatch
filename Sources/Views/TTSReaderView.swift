import SwiftUI
import AVFoundation

struct SentenceInfo {
    let text: String
    let startWordIndex: Int
    let endWordIndex: Int
}

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var rate: Float = 0.5 { // Default is 0.5 (AVSpeechUtteranceDefaultSpeechRate)
        didSet {
            // Se mudar o ritmo enquanto estiver falando, reinicia o áudio no ponto atual
            if isPlaying {
                restartSpeech()
            }
        }
    }
    
    private let synthesizer = AVSpeechSynthesizer()
    private let text: String
    private var sentenceInfos: [SentenceInfo] = []
    private var currentSentenceIndex = 0
    
    var onProgressUpdate: ((Int) -> Void)?
    
    init(text: String, currentWordIndex: Int) {
        self.text = text
        super.init()
        self.synthesizer.delegate = self
        prepareText()
        
        // Determina a frase correta para iniciar baseada no índice de palavra do progresso salvo
        if let targetIndex = sentenceInfos.firstIndex(where: { $0.startWordIndex <= currentWordIndex && currentWordIndex < $0.endWordIndex }) {
            self.currentSentenceIndex = targetIndex
        } else {
            self.currentSentenceIndex = 0
        }
        updateProgress()
    }
    
    private func prepareText() {
        // Quebra o texto por frases/pontuação para leitura segmentada, permitindo melhor controle de progresso
        let rawSentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var offset = 0
        for sentence in rawSentences {
            let wordsCount = sentence.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
            sentenceInfos.append(SentenceInfo(
                text: sentence,
                startWordIndex: offset,
                endWordIndex: offset + wordsCount
            ))
            offset += wordsCount
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        configureAudioSession()
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            WKInterfaceDevice.current().play(.start)
        } else {
            speakCurrentSentence()
            WKInterfaceDevice.current().play(.start)
        }
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
        deactivateAudioSession()
        WKInterfaceDevice.current().play(.stop)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        currentSentenceIndex = 0
        progress = 0.0
        isPlaying = false
        deactivateAudioSession()
    }
    
    func skipForward() {
        guard currentSentenceIndex < sentenceInfos.count - 1 else { return }
        currentSentenceIndex += 1
        if isPlaying {
            restartSpeech()
        } else {
            updateProgress()
        }
        WKInterfaceDevice.current().play(.click)
        notifyProgress()
    }
    
    func skipBackward() {
        guard currentSentenceIndex > 0 else { return }
        currentSentenceIndex -= 1
        if isPlaying {
            restartSpeech()
        } else {
            updateProgress()
        }
        WKInterfaceDevice.current().play(.click)
        notifyProgress()
    }
    
    private func speakCurrentSentence() {
        guard currentSentenceIndex < sentenceInfos.count else {
            stop()
            return
        }
        
        let utterance = AVSpeechUtterance(string: sentenceInfos[currentSentenceIndex].text)
        
        // Seleciona a voz em Português do Brasil (pt-BR)
        if let voice = AVSpeechSynthesisVoice(language: "pt-BR") {
            utterance.voice = voice
        }
        
        utterance.rate = rate
        
        synthesizer.speak(utterance)
        isPlaying = true
        updateProgress()
    }
    
    private func restartSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
        speakCurrentSentence()
    }
    
    private func updateProgress() {
        guard sentenceInfos.count > 0 else { return }
        progress = Double(currentSentenceIndex) / Double(sentenceInfos.count)
    }
    
    private func notifyProgress() {
        guard currentSentenceIndex < sentenceInfos.count else { return }
        let currentWordIndex = sentenceInfos[currentSentenceIndex].startWordIndex
        onProgressUpdate?(currentWordIndex)
    }
    
    // MARK: - AVAudioSession Setup
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Falha ao configurar AVAudioSession para watchOS: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Falha ao desativar AVAudioSession: \(error)")
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentSentenceIndex += 1
        if currentSentenceIndex < sentenceInfos.count {
            speakCurrentSentence()
            notifyProgress()
        } else {
            stop()
            WKInterfaceDevice.current().play(.success)
        }
    }
}

struct TTSReaderView: View {
    @State var book: Book
    var onProgressUpdate: (Book) -> Void
    
    @StateObject private var ttsManager: TTSManager
    @AppStorage("reader_theme") private var readerTheme: String = "black"
    
    // Estado de foco para a Digital Crown
    @FocusState private var isCrownFocused: Bool
    
    init(book: Book, onProgressUpdate: @escaping (Book) -> Void) {
        self._book = State(initialValue: book)
        self.onProgressUpdate = onProgressUpdate
        self._ttsManager = StateObject(wrappedValue: TTSManager(text: book.content, currentWordIndex: book.currentWordIndex))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Cabeçalho com título curto
            Text(book.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .lineLimit(1)
            
            Spacer()
            
            // Visualizador Animado de Voz
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    AudioWaveBar(isPlaying: ttsManager.isPlaying, delay: Double(index) * 0.15)
                }
            }
            .frame(height: 36)
            
            Spacer()
            
            // Ritmo da fala (Speech Rate)
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundColor(.gray)
                Text(String(format: "Velocidade: %.1fx", ttsManager.rate * 2.0)) // Escala visual 0.5x a 2.0x
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            // Barra de Progresso compacta
            ThinProgressBar(progress: ttsManager.progress, color: .green)
                .padding(.horizontal, 8)
            
            // Controles de Áudio
            HStack(spacing: 12) {
                // Voltar
                Button(action: {
                    ttsManager.skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                
                // Play / Pause
                Button(action: {
                    ttsManager.togglePlayPause()
                }) {
                    Image(systemName: ttsManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                // Avançar
                Button(action: {
                    ttsManager.skipForward()
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal)
        .background(Color.themeBackground(for: readerTheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // Permite usar a Digital Crown para ajustar a velocidade da voz
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(Binding(
            get: { Double(ttsManager.rate) },
            set: { ttsManager.rate = Float($0) }
        ), from: 0.2, through: 0.8, by: 0.05, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear {
            isCrownFocused = true
            ttsManager.onProgressUpdate = { newIndex in
                book.currentWordIndex = newIndex
                saveProgress()
            }
        }
        .onDisappear {
            ttsManager.stop()
            saveProgress()
        }
    }
    
    private func saveProgress() {
        var updatedBook = book
        updatedBook.currentWordIndex = book.currentWordIndex
        updatedBook.lastReadTimestamp = Date()
        onProgressUpdate(updatedBook)
    }
}

// Pequeno componente visualizador que oscila quando o áudio está sendo falado
struct AudioWaveBar: View {
    let isPlaying: Bool
    let delay: Double
    
    @State private var scale: CGFloat = 0.2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.green)
            .frame(width: 6)
            .scaleEffect(y: isPlaying ? scale : 0.2, anchor: .center)
            .onAppear {
                if isPlaying {
                    startAnimation()
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    startAnimation()
                } else {
                    scale = 0.2
                }
            }
    }
    
    private func startAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            scale = CGFloat.random(in: 0.5...1.0)
        }
    }
}
