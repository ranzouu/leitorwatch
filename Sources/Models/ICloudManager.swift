import Foundation
import Combine
import WatchKit

class ICloudManager: ObservableObject {
    @Published var availableFiles: [URL] = []
    @Published var isICloudAvailable = false
    @Published var isScanning = false
    
    private var metadataQuery = NSMetadataQuery()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupQuery()
    }
    
    deinit {
        // Não chamar stopScanning() aqui: ele mexe em @Published durante a destruição do objeto
        metadataQuery.stop()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupQuery() {
        // Busca a URL do contêiner ubiquitoso do iCloud
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("iCloud não disponível no simulador/dispositivo.")
            isICloudAvailable = false
            return
        }
        
        isICloudAvailable = true
        
        // Cria a pasta Documents se ela não existir
        let documentsURL = containerURL.appendingPathComponent("Documents")
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            } catch {
                print("Falha ao criar pasta Documents no iCloud: \(error)")
            }
        }
        
        // Configura a busca no iCloud para arquivos com extensão .txt
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(format: "%K ENDSWITH '.txt'", NSMetadataItemFSNameKey)
        
        // Registra notificações para atualizações da busca
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: NSNotification.Name.NSMetadataQueryDidUpdate,
            object: metadataQuery
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )
    }
    
    func startScanning() {
        guard isICloudAvailable else { return }
        isScanning = true
        if metadataQuery.isStarted {
            metadataQuery.stop()
        }
        metadataQuery.start()
    }
    
    func stopScanning() {
        metadataQuery.stop()
        isScanning = false
    }
    
    @objc private func queryDidUpdate(_ notification: Notification) {
        metadataQuery.disableUpdates()
        
        var urls: [URL] = []
        for item in metadataQuery.results {
            if let metadataItem = item as? NSMetadataItem,
               let url = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL {
                urls.append(url)
            }
        }
        
        // Classifica os arquivos por nome
        let sortedUrls = urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        
        DispatchQueue.main.async {
            self.availableFiles = sortedUrls
            self.metadataQuery.enableUpdates()
        }
    }
    
    // Método para importar o arquivo de texto e convertê-lo em livro
    func importFile(at url: URL, completion: @escaping (Result<Book, Error>) -> Void) {
        let fileManager = FileManager.default
        
        // Se o arquivo for do iCloud (ubiquitous) e ainda não estiver localmente baixado
        if fileManager.isUbiquitousItem(at: url) {
            do {
                let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                if values.ubiquitousItemDownloadingStatus != .current {
                    // Inicia o download nativo do arquivo
                    try fileManager.startDownloadingUbiquitousItem(at: url)
                    
                    // Loop de espera e verificação em segundo plano
                    DispatchQueue.global().async {
                        var downloaded = false
                        for _ in 0..<15 { // Espera até 15 segundos
                            Thread.sleep(forTimeInterval: 1.0)
                            if let freshValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                               freshValues.ubiquitousItemDownloadingStatus == .current {
                                downloaded = true
                                break
                            }
                        }
                        
                        if downloaded {
                            self.readAndCreateBook(from: url, completion: completion)
                        } else {
                            DispatchQueue.main.async {
                                completion(.failure(NSError(
                                    domain: "ICloudManager",
                                    code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "O download do arquivo no iCloud expirou. Verifique sua conexão."]
                                )))
                            }
                        }
                    }
                    return
                }
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        // Se já está baixado, faz a leitura direta coordenada
        readAndCreateBook(from: url, completion: completion)
    }
    
    private func readAndCreateBook(from url: URL, completion: @escaping (Result<Book, Error>) -> Void) {
        // NSFileCoordinator é obrigatório para ler de forma segura arquivos gerenciados pelo daemon do iCloud
        let coordinator = NSFileCoordinator()
        var readError: NSError?
        var fetchError: NSError?
        var bookResult: Book?
        
        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { coordinateURL in
            do {
                let content = try String(contentsOf: coordinateURL, encoding: .utf8)
                let title = url.deletingPathExtension().lastPathComponent
                
                let newBook = Book(
                    id: UUID(),
                    title: title,
                    author: "Importado do iCloud",
                    content: content
                )
                bookResult = newBook
            } catch {
                fetchError = error as NSError
            }
        }
        
        DispatchQueue.main.async {
            if let book = bookResult {
                completion(.success(book))
            } else {
                completion(.failure(readError ?? fetchError ?? NSError(
                    domain: "ICloudManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Falha ao ler o conteúdo do arquivo."]
                )))
            }
        }
    }
}
