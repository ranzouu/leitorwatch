import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let content: String
    
    // Configurações de progresso salvas
    var currentWordIndex: Int = 0
    var lastReadTimestamp: Date = Date()
    
    // Divide o texto em palavras limpas de pontuação para o RSVP, mantendo caracteres especiais
    var words: [String] {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    // Progresso percentual baseado no índice da palavra atual no RSVP
    var progressPercent: Double {
        let total = words.count
        guard total > 0 else { return 0.0 }
        return Double(currentWordIndex) / Double(total)
    }
    
    // Parágrafos do texto com mapeamento de índice de palavras
    var paragraphInfos: [ParagraphInfo] {
        var infos: [ParagraphInfo] = []
        let lines = content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var currentWordOffset = 0
        for (index, line) in lines.enumerated() {
            let wordCount = line.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
            infos.append(
                ParagraphInfo(
                    id: index,
                    text: line,
                    startWordIndex: currentWordOffset,
                    endWordIndex: currentWordOffset + wordCount
                )
            )
            currentWordOffset += wordCount
        }
        return infos
    }
    
    // Capítulos detectados dinamicamente ou gerados por seções de fallback
    var chapters: [Chapter] {
        var list: [Chapter] = []
        let allWords = words
        guard !allWords.isEmpty else { return [] }
        
        let lines = content.components(separatedBy: "\n")
        var currentWordOffset = 0
        var chaptersFound: [(title: String, wordIndex: Int)] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            let lower = trimmed.lowercased()
            let isChapterHeader = lower.hasPrefix("capítulo") ||
                                  lower.hasPrefix("capitulo") ||
                                  lower.hasPrefix("chapter") ||
                                  lower.hasPrefix("prefácio") ||
                                  lower.hasPrefix("preface") ||
                                  lower.hasPrefix("introdução") ||
                                  lower.hasPrefix("introducao") ||
                                  lower.hasPrefix("parte ") ||
                                  lower.hasPrefix("part ")
            
            let lineWordsCount = trimmed.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
            
            if isChapterHeader {
                let title = trimmed.count > 30 ? String(trimmed.prefix(30)) + "..." : trimmed
                chaptersFound.append((title: title, wordIndex: currentWordOffset))
            }
            
            currentWordOffset += lineWordsCount
        }
        
        // Fallback: divide em blocos de 500 palavras se não achar capítulos
        if chaptersFound.count < 2 {
            chaptersFound.removeAll()
            let chunkSize = 500
            var offset = 0
            var partNum = 1
            while offset < allWords.count {
                chaptersFound.append((title: "Parte \(partNum)", wordIndex: offset))
                offset += chunkSize
                partNum += 1
            }
        }
        
        for i in 0..<chaptersFound.count {
            let current = chaptersFound[i]
            let nextWordIndex: Int
            if i + 1 < chaptersFound.count {
                nextWordIndex = chaptersFound[i+1].wordIndex
            } else {
                nextWordIndex = allWords.count
            }
            
            let start = min(current.wordIndex, allWords.count)
            let end = min(max(start, nextWordIndex), allWords.count)
            
            list.append(
                Chapter(
                    title: current.title,
                    startIndex: start,
                    endIndex: end
                )
            )
        }
        
        return list
    }
    
    // Mock de livros clássicos em português para testes
    static let mockBooks: [Book] = [
        Book(
            id: UUID(),
            title: "Dom Casmurro",
            author: "Machado de Assis",
            content: """
            Uma noite destas, vindo da cidade para o Engenho Novo, encontrei no trem da Central um rapaz aqui do bairro, que eu conheço de vista e de chapéu. Cumprimentou-me, sentou-se ao pé de mim, falou do tempo, dos partidos, dos boatos da rua, e, finalmente, do seu poema. Eu ouvi-o com atenção, mas sem grande entusiasmo.
            
            O trem parou na estação do Engenho Novo. Agradeci-lhe a companhia e saí. Já em casa, comecei a pensar que talvez o poema não fosse mau. Quis lê-lo, mas não o tinha comigo.
            
            A terra vos seja leve! É o que se costuma dizer aos mortos. A nós, os vivos, o que nos cumpre é fazer com que a vida seja leve, e não carregar sobre os ombros o peso do mundo. Capitu era mais mulher do que eu era homem. Olhos de ressaca, olhos de cigana oblíqua e dissimulada. Eu não sabia o que era ressaca, mas a palavra era bonita e definia bem aquele mistério.
            """
        ),
        Book(
            id: UUID(),
            title: "O Cortiço",
            author: "Aluísio Azevedo",
            content: """
            O João Romão era um homem de trinta e cinco anos, galego, magro, de estatura regular, mas forte e muito ativo. Viera para o Brasil ainda rapazinho, com uma mão à frente e outra atrás. Trabalhara como um mouro, economizando cada centavo, até que conseguiu comprar uma casinha de pasto e, depois, a venda que ficava na frente do cortiço.
            
            A Estela, mulher de João Romão, ajudava-o com afinco. O cortiço crescia a olhos vistos. Todos os dias surgiam novas casinhas, novas quitandas, novas lavadeiras que vinham encher o pátio de roupa branca e cantigas barulhentas. O trabalho ali era sagrado e a ambição era o motor que movia aquela gente de sol a sol.
            """
        ),
        Book(
            id: UUID(),
            title: "Guia de Leitura Dinâmica",
            author: "Dicas de Leitura",
            content: """
            Bem-vindo ao modo de Leitura Dinâmica! 
            
            A leitura rápida por RSVP (Apresentação Visual Serial Rápida) funciona exibindo apenas uma palavra por vez no centro da tela. 
            
            Isso elimina a necessidade de mover os olhos da esquerda para a direita, poupando tempo e aumentando o foco. 
            
            Dicas para melhorar sua performance:
            1. Evite vocalizar as palavras mentalmente (subvocalização). Tente apenas absorver o significado visualmente.
            2. Comece com 250 Palavras Por Minuto (WPM) e aumente gradualmente de 50 em 50.
            3. Relaxe os olhos e foque exatamente no centro da tela do relógio.
            
            Pratique diariamente para treinar seu cérebro a processar blocos de informação com mais rapidez!
            """
        )
    ]
    
    // MARK: - Persistência Local da Biblioteca
    
    private static var libraryURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("books.json")
    }
    
    // Carrega a biblioteca local. Semeia com os mocks APENAS na primeira execução
    // (arquivo inexistente) — se o arquivo existir mas não puder ser lido, NÃO sobrescreve
    // a biblioteca do usuário.
    static func loadLibrary() -> [Book] {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else {
            let initialBooks = mockBooks
            saveLibrary(initialBooks)
            return initialBooks
        }
        do {
            let data = try Data(contentsOf: libraryURL)
            return try JSONDecoder().decode([Book].self, from: data)
        } catch {
            print("Falha ao carregar biblioteca (arquivo preservado): \(error)")
            return []
        }
    }
    
    // Grava a lista atualizada de livros no armazenamento local do relógio
    static func saveLibrary(_ books: [Book]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(books)
            try data.write(to: libraryURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("Falha ao gravar livros localmente: \(error)")
        }
    }
}

// MARK: - Modelos Auxiliares para Capítulos e Parágrafos

struct Chapter: Identifiable, Hashable, Codable {
    // Inclui o índice inicial para não colidir quando dois capítulos têm o mesmo título
    var id: String { "\(title)-\(startIndex)" }
    let title: String
    let startIndex: Int
    let endIndex: Int
    
    var range: Range<Int> {
        startIndex..<endIndex
    }
}

struct ParagraphInfo: Identifiable, Codable, Hashable {
    let id: Int
    let text: String
    let startWordIndex: Int
    let endWordIndex: Int
}
