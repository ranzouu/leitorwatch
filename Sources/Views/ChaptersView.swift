import SwiftUI

struct ChaptersView: View {
    @Binding var book: Book
    @Binding var path: [Route]
    var onChapterSelected: (Int) -> Void
    
    @AppStorage("reader_theme") private var readerTheme: String = "black"
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(book.chapters) { chapter in
                    Button(action: {
                        onChapterSelected(chapter.startIndex)
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(chapter.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isCurrentChapter(chapter) ? .orange : .white)
                                Spacer()
                                if isCurrentChapter(chapter) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            
                            let progress = chapterProgress(chapter)
                            HStack(spacing: 6) {
                                ThinProgressBar(progress: progress, color: .orange, height: 3)
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .background(Color.themeBackground(for: readerTheme).ignoresSafeArea())
        .navigationTitle("Capítulos")
    }
    
    private func isCurrentChapter(_ chapter: Chapter) -> Bool {
        return chapter.range.contains(book.currentWordIndex) ||
               (book.currentWordIndex >= book.words.count && chapter.title == book.chapters.last?.title)
    }
    
    private func chapterProgress(_ chapter: Chapter) -> Double {
        let index = book.currentWordIndex
        if index >= chapter.range.upperBound {
            return 1.0
        } else if index <= chapter.range.lowerBound {
            return 0.0
        } else {
            let chapterLength = chapter.range.upperBound - chapter.range.lowerBound
            guard chapterLength > 0 else { return 0.0 }
            return Double(index - chapter.range.lowerBound) / Double(chapterLength)
        }
    }
}
