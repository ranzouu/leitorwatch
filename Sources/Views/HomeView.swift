import SwiftUI

// Rotas de navegação do aplicativo
enum Route: Hashable {
    case bookActions(Book)
    case rsvpReader(Book)
    case manualReader(Book)
    case ttsReader(Book)
    case chapters(Book)
    case settings
    case icloudImport
}

struct HomeView: View {
    @State private var books: [Book] = []
    @State private var path: [Route] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: Route.icloudImport) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.orange)
                            Text("Importar Livro")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                    }
                }
                
                Section(header: Text("Minha Biblioteca").foregroundColor(.gray)) {
                    if books.isEmpty {
                        Text("Biblioteca vazia")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    } else {
                        ForEach(books) { book in
                            NavigationLink(value: Route.bookActions(book)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(book.author)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        ProgressView(value: book.progressPercent, total: 1.0)
                                            .tint(.orange)
                                        
                                        Text("\(Int(book.progressPercent * 100))%")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leitor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Route.settings) {
                        Label("Ajustes", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .bookActions(let book):
                    if let index = books.firstIndex(where: { $0.id == book.id }) {
                        BookActionsView(book: books[index], books: $books)
                    } else {
                        BookActionsView(book: book, books: $books)
                    }
                case .rsvpReader(let book):
                    RSVPReaderView(book: book, onProgressUpdate: { updatedBook in
                        updateBookProgress(updatedBook)
                    })
                case .manualReader(let book):
                    if let index = books.firstIndex(where: { $0.id == book.id }) {
                        ManualReaderView(book: books[index], onProgressUpdate: { updatedBook in
                            updateBookProgress(updatedBook)
                        })
                    } else {
                        ManualReaderView(book: book, onProgressUpdate: { updatedBook in
                            updateBookProgress(updatedBook)
                        })
                    }
                case .ttsReader(let book):
                    if let index = books.firstIndex(where: { $0.id == book.id }) {
                        TTSReaderView(book: books[index], onProgressUpdate: { updatedBook in
                            updateBookProgress(updatedBook)
                        })
                    } else {
                        TTSReaderView(book: book, onProgressUpdate: { updatedBook in
                            updateBookProgress(updatedBook)
                        })
                    }
                case .chapters(let book):
                    if let index = books.firstIndex(where: { $0.id == book.id }) {
                        ChaptersView(book: $books[index], path: $path, onChapterSelected: { startIndex in
                            var updated = books[index]
                            updated.currentWordIndex = startIndex
                            updateBookProgress(updated)
                            path.removeLast()
                        })
                    } else {
                        ChaptersView(book: .constant(book), path: $path, onChapterSelected: { _ in
                            path.removeLast()
                        })
                    }
                case .settings:
                    SettingsView()
                case .icloudImport:
                    ICloudImportView(books: $books)
                }
            }
            .onAppear {
                books = Book.loadLibrary()
            }
        }
    }
    
    private func updateBookProgress(_ updatedBook: Book) {
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            books[index] = updatedBook
            Book.saveLibrary(books)
        }
    }
}

struct BookActionsView: View {
    let book: Book
    @Binding var books: [Book]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(book.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
                
                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)
                
                NavigationLink(value: Route.chapters(book)) {
                    ActionRow(icon: "list.bullet", title: "Capítulos", color: .orange)
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.rsvpReader(book)) {
                    ActionRow(icon: "bolt.fill", title: "Leitura Rápida", color: .orange)
                }
                .buttonStyle(.plain)
                
                NavigationLink(value: Route.manualReader(book)) {
                    ActionRow(icon: "book.fill", title: "Leitura Manual", color: .blue)
                }
                .buttonStyle(.plain)
                
                NavigationLink(value: Route.ttsReader(book)) {
                    ActionRow(icon: "headphones", title: "Leitura por Voz", color: .green)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    var resetBook = book
                    resetBook.currentWordIndex = 0
                    updateBookProgress(resetBook)
                    WKInterfaceDevice.current().play(.directionDown)
                }) {
                    ActionRow(icon: "arrow.counterclockwise", title: "Reiniciar Progresso", color: .red)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .navigationTitle("Opções")
    }
    
    private func updateBookProgress(_ updatedBook: Book) {
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            books[index] = updatedBook
            Book.saveLibrary(books)
        }
    }
}

// Linha de ação compacta usada na tela de opções do livro
struct ActionRow: View {
    let icon: String
    let title: String
    var color: Color = .orange

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
