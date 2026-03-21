import Foundation
import SwiftUI
import Combine  // 👈 이게 없어서 'ObservableObject' 에러가 났던 것입니다!

// MARK: - 단어장 데이터 구조
struct GlossaryEntry: Identifiable, Codable {
    var id = UUID()
    var source: String
    var target: String
}

// MARK: - 단어장 관리 및 주석 로직
class GlossaryStore: ObservableObject {
    @Published var entries: [GlossaryEntry] = []
    private let saveKey = "glossary_entries"
    
    init() {
        load()
    }
    
    // ✨ 핵심 수정: 정규표현식을 사용한 단어 단위 주석 달기
    func annotate(text: String, isKorean: Bool, fontSize: CGFloat) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        
        var result = AttributedString(text)
        
        // ✨ 기본 폰트 설정: .bold 대신 .regular(노멀체) 사용 및 검은색 지정
        result.font = .systemFont(ofSize: fontSize, weight: .regular)
        result.foregroundColor = .black
        
        let plainString = text
        var matches: [(range: Range<String.Index>, translation: String)] = []
        
        for entry in entries {
            let terms = [(entry.source, entry.target), (entry.target, entry.source)]
            
            for item in terms {
                let trimmedTerm = item.0.trimmingCharacters(in: .whitespaces)
                guard !trimmedTerm.isEmpty else { continue }
                
                // 🔍 \b(단어)\b 패턴으로 독립된 단어만 추출 (this 안의 is 방지)
                let escapedTerm = NSRegularExpression.escapedPattern(for: trimmedTerm)
                let pattern = "\\b\(escapedTerm)\\b"
                
                // 🚩 수정됨: 'pattern' 인자가 'options'보다 먼저 와야 합니다.
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let nsRange = NSRange(plainString.startIndex..<plainString.endIndex, in: plainString)
                    let results = regex.matches(in: plainString, options: [], range: nsRange)
                    
                    for match in results {
                        if let range = Range(match.range, in: plainString) {
                            matches.append((range: range, translation: item.1))
                        }
                    }
                }
            }
        }
        
        // 뒤에서부터 주석 삽입 (인덱스 꼬임 방지)
        let sortedMatches = matches.sorted { $0.range.lowerBound > $1.range.lowerBound }
        var lastAppliedRange: Range<String.Index>? = nil
        
        for match in sortedMatches {
                if let attrRange = Range(match.range, in: result) {
                    // 주석이 달리는 부분만 강조하기 위해 배경색 유지
                    result[attrRange].backgroundColor = Color.yellow.opacity(0.3)
                    // 하이라이트 된 단어도 검은색 노멀체 유지 (필요 시 여기서 weight 변경 가능)
                    result[attrRange].font = .systemFont(ofSize: fontSize, weight: .regular)
                    
                    var annotation = AttributedString(" (\(match.translation))")
                    annotation.font = .systemFont(ofSize: fontSize * 0.65, weight: .medium)
                    annotation.foregroundColor = .secondary
                    
                    result.insert(annotation, at: attrRange.upperBound)
                    lastAppliedRange = match.range
                }
            }
            return result
        }
    
    // MARK: - CRUD 및 데이터 저장 로직
    func add(source: String, target: String) {
        let s = source.trimmingCharacters(in: .whitespaces)
        let t = target.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty && !t.isEmpty {
            entries.append(GlossaryEntry(source: s, target: t))
            save()
        }
    }
    
    func update(id: UUID, source: String, target: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].source = source.trimmingCharacters(in: .whitespaces)
            entries[index].target = target.trimmingCharacters(in: .whitespaces)
            save()
        }
    }
    
    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }
    
    func resetAll() {
        entries.removeAll()
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = decoded
        }
    }
    
    func exportToCSV() -> String {
        return entries.map { "\($0.source),\($0.target)" }.joined(separator: "\n")
    }
    
    func importFromCSV(content: String, overwrite: Bool) {
        if overwrite { entries.removeAll() }
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ",")
            if parts.count >= 2 {
                add(source: parts[0], target: parts[1])
            }
        }
    }
}
