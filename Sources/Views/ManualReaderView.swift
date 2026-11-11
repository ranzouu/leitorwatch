import SwiftUI

// Classe de estado interno para evitar loops de renderização no SwiftUI ao atualizar o progresso durante o scroll
class ManualReaderState {
    var currentWordIndex = 0
    var visibleParagraphIds = Set<Int>()
}

struct ManualReaderView: View {
    @State var book: Book
    var onProgressUpdate: (Book) -> Void
    
    @AppStorage("reader_font_size") private var fontSize: Double = 16.0
    @AppStorage("reader_font_design") private var fontDesign: String = "default"
    @AppStorage("reader_theme") private var readerTheme: String = "black"
    
    // Estado de foco para ativação automática do Digital Crown
    @FocusState private var isScrollViewFocused: Bool
    
    // Armazena o estado não reativo
    @State private var readerState = ManualReaderState()
    @State private var initialScrolled = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Controles de ajuste de fonte no topo
            HStack {
                Button(action: {
                    adjustFontSize(-1.0)
                }) {
                    Text("A-")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 40, height: 26)
                .contentShape(Rectangle())
                .focusable(false)
                
                Spacer()
                
                Text("\(Int(fontSize)) pt")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    adjustFontSize(1.0)
                }) {
                    Text("A+")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 40, height: 26)
                .contentShape(Rectangle())
                .focusable(false)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
            
            // Área de leitura com scroll
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(book.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                            .padding(.bottom, 2)
                        
                        ForEach(book.paragraphInfos) { paragraph in
                            Text(paragraph.text)
                                .font(.readerFont(size: CGFloat(fontSize), designString: fontDesign, weight: .medium))
                                .lineSpacing(4)
                                .foregroundColor(Color.themeForeground(for: readerTheme))
                                .multilineTextAlignment(.leading)
                                .id(paragraph.id)
                                .onAppear {
                                    if initialScrolled {
                                        readerState.visibleParagraphIds.insert(paragraph.id)
                                        updateCurrentWordIndexFromVisible()
                                    }
                                }
                                .onDisappear {
                                    if initialScrolled {
                                        readerState.visibleParagraphIds.remove(paragraph.id)
                                        updateCurrentWordIndexFromVisible()
                                    }
                                }
                        }
                        
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal)
                }
                // Habilita a Digital Crown para rolar a ScrollView automaticamente
                .focusable(true)
                .focused($isScrollViewFocused)
                .onAppear {
                    // Rola para o parágrafo onde o progresso atual do usuário está localizado
                    let targetParagraph = book.paragraphInfos.first {
                        $0.startWordIndex <= book.currentWordIndex && book.currentWordIndex < $0.endWordIndex
                    } ?? book.paragraphInfos.first
                    
                    if let target = targetParagraph {
                        proxy.scrollTo(target.id, anchor: .top)
                    }
                    
                    // Espera o carregamento inicial da tela para evitar falso positivo do onAppear/onDisappear no layout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        initialScrolled = true
                        // Inicializa o rastreamento dos parágrafos logo após o scroll inicial
                        if let target = targetParagraph {
                            readerState.visibleParagraphIds.insert(target.id)
                            updateCurrentWordIndexFromVisible()
                        }
                    }
                }
            }
        }
        .background(Color.themeBackground(for: readerTheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            readerState.currentWordIndex = book.currentWordIndex
            isScrollViewFocused = true
        }
        .onDisappear {
            saveProgress()
        }
    }
    
    private func adjustFontSize(_ delta: Double) {
        fontSize = max(10.0, min(24.0, fontSize + delta))
        WKInterfaceDevice.current().play(.click)
    }
    
    private func updateCurrentWordIndexFromVisible() {
        guard !readerState.visibleParagraphIds.isEmpty else { return }
        let topParagraphId = readerState.visibleParagraphIds.min()!
        if let info = book.paragraphInfos.first(where: { $0.id == topParagraphId }) {
            readerState.currentWordIndex = info.startWordIndex
        }
    }
    
    private func saveProgress() {
        var updatedBook = book
        updatedBook.currentWordIndex = readerState.currentWordIndex
        updatedBook.lastReadTimestamp = Date()
        onProgressUpdate(updatedBook)
    }
}
