import Foundation
import SwiftUI
import Combine

// 1. 단어 데이터 구조
struct GlossaryEntry: Identifiable, Codable {
    var id = UUID()
    var source: String
    var target: String
}

// 2. 단어장 관리 및 가공 로직
class GlossaryStore: ObservableObject {
    @Published var entries: [GlossaryEntry] = []
    private let saveKey = "glossary_entries"
    
    init() { load() }
    
    // MARK: - ✨ 동시통역용 실시간 가공 함수 (대소문자/띄어쓰기 무시)
    func annotate(text: String, isKorean: Bool, fontSize: CGFloat) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        
        var result = AttributedString(text)
        // 기본 폰트 설정
        result.font = .systemFont(ofSize: fontSize, weight: .bold)
        
        // 검색 효율을 위해 띄어쓰기를 무시한 비교용 텍스트 준비 (필요 시)
        // 여기서는 원본 문자열의 인덱스를 유지하며 검색합니다.
        let plainString = text
        var matches: [(range: Range<String.Index>, translation: String)] = []
        
        for entry in entries {
            // source-target 쌍방향 검색 (bus -> 버스, 버스 -> bus)
            let terms = [
                (term: entry.source, trans: entry.target),
                (term: entry.target, trans: entry.source)
            ]
            
            for item in terms {
                guard item.term.count >= 1 else { continue }
                
                var searchRange = plainString.startIndex..<plainString.endIndex
                
                // 대소문자 무시(caseInsensitive), 발음기호 무시(diacriticInsensitive) 옵션 적용
                while let range = plainString.range(of: item.term, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
                    matches.append((range: range, translation: item.trans))
                    searchRange = range.upperBound..<plainString.endIndex
                }
            }
        }
        
        // 겹치는 단어가 있을 경우 더 긴 단어를 우선하거나, 시작 위치순으로 정렬
        // 뒤에서부터 삽입해야 AttributedString의 인덱스가 깨지지 않습니다.
        let sortedMatches = matches.sorted { $0.range.lowerBound > $1.range.lowerBound }
        
        var lastAppliedRange: Range<String.Index>? = nil
        
        for match in sortedMatches {
            // 중복 범위 처리 (이미 주석이 달린 영역과 겹치면 패스)
            if let last = lastAppliedRange, match.range.upperBound > last.lowerBound {
                continue
            }
            
            // AttributedString 인덱스로 변환하여 적용
            if let attrRange = Range(match.range, in: result) {
                // 1. 형광펜 효과 (노란색)
                result[attrRange].backgroundColor = Color.yellow.opacity(0.5)
                
                // 2. 주석(번역어) 생성
                var anno = AttributedString("(\(match.translation))")
                anno.font = .systemFont(ofSize: fontSize * 0.6, weight: .medium)
                anno.foregroundColor = .secondary // 주석은 회색으로 처리하여 시선 분산 방지
                
                // 3. 삽입
                result.insert(anno, at: attrRange.upperBound)
                lastAppliedRange = match.range
            }
        }
        
        return result
    }
    // GlossaryStore 클래스 내부에 추가/수정
    func importFromCSV(content: String, overwrite: Bool) {
        if overwrite { entries.removeAll() }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            // 쉼표(,)나 탭(\t)으로 구분된 경우 모두 대응
            let parts = line.components(separatedBy: CharacterSet(charactersIn: ",\t"))
            if parts.count >= 2 {
                let src = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let tgt = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !src.isEmpty && !tgt.isEmpty {
                    entries.append(GlossaryEntry(source: src, target: tgt))
                }
            }
        }
        save()
    }
    // MARK: - CRUD 및 관리 기능
    func add(source: String, target: String) {
        let cleanSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanSource.isEmpty && !cleanTarget.isEmpty {
            entries.append(GlossaryEntry(source: cleanSource, target: cleanTarget))
            save()
        }
    }
    
    func update(id: UUID, source: String, target: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].source = source
            entries[index].target = target
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
    
    // MARK: - 가져오기 / 내보내기 로직
    func exportToCSV() -> String {
        return entries.map { "\($0.source),\($0.target)" }.joined(separator: "\n")
    }
    
    func importFromCSV(_ csv: String, overwrite: Bool) {
        if overwrite { entries.removeAll() }
        let lines = csv.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ",")
            if parts.count >= 2 {
                add(source: parts[0], target: parts[1])
            }
        }
    }

    // MARK: - 저장 및 불러오기 (UserDefaults)
    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = decoded
        }
    }
}
