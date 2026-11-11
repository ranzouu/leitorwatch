import SwiftUI
import WatchKit

struct ICloudImportView: View {
    @StateObject private var iCloudManager = ICloudManager()
    @Binding var books: [Book]
    @Environment(\.dismiss) var dismiss
    
    @State private var importStatus: String?
    @State private var isImporting = false
    
    var body: some View {
        VStack {
            if !iCloudManager.isICloudAvailable {
                VStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                    Text("iCloud Indisponível")
                        .font(.system(size: 13, weight: .bold))
                    Text("Conecte ao iCloud nas configurações do relógio/simulador.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    Section(header: Text("Arquivos no iCloud").foregroundColor(.gray)) {
                        if iCloudManager.availableFiles.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                Text("Nenhum arquivo .txt")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                Text("Coloque arquivos .txt na pasta do Leitor no iCloud Drive.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(iCloudManager.availableFiles, id: \.self) { url in
                                Button(action: {
                                    importBook(from: url)
                                }) {
                                    HStack {
                                        Image(systemName: "doc.plaintext")
                                            .foregroundColor(.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(url.deletingPathExtension().lastPathComponent)
                                                .font(.system(size: 13, weight: .semibold))
                                                .lineLimit(1)
                                            Text("Toque para importar")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.85)
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.orange)
                        if let status = importStatus {
                            Text(status)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            iCloudManager.startScanning()
        }
        .onDisappear {
            iCloudManager.stopScanning()
        }
        .navigationTitle("Importar")
    }
    
    private func importBook(from url: URL) {
        isImporting = true
        importStatus = "Baixando do iCloud..."
        
        iCloudManager.importFile(at: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newBook):
                    // Verifica se o livro já existe na biblioteca
                    if let index = books.firstIndex(where: { $0.title == newBook.title }) {
                        // Sobrescreve o conteúdo/estado preservando o progresso se possível
                        var updatedBook = newBook
                        updatedBook.currentWordIndex = books[index].currentWordIndex
                        books[index] = updatedBook
                    } else {
                        books.append(newBook)
                    }
                    Book.saveLibrary(books)
                    
                    importStatus = "Sucesso!"
                    WKInterfaceDevice.current().play(.success)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isImporting = false
                        dismiss()
                    }
                case .failure(let error):
                    importStatus = "Erro: \(error.localizedDescription)"
                    WKInterfaceDevice.current().play(.failure)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        isImporting = false
                    }
                }
            }
        }
    }
}
