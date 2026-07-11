// PlantFormulaDescription — the human-readable "내 바다의 식" lines shown in
// the detail sheet. Every line exposes formula + current value so the ocean
// stays mathematically transparent. Split from PlantFormula.swift for size.

import Foundation

extension PlantFormula {
    /// Human-readable formula description shown in the detail sheet.
    public static func formulaDescription(
        seed: UInt64, nutrients: PlantNutrients
    ) -> [PlantFormulaLine] {
        let p = parameters(seed: seed, nutrients: nutrients)
        var lines: [PlantFormulaLine] = [
            .init(label: "파도 레이어 수",
                  formula: "min(4, 1 + ⌊log₁₀(총분 + 1) × 1.5⌋)",
                  value: "\(p.waves.count)"),
            .init(label: "파도 진폭 (기본)",
                  formula: "4 + √(운동 분 ÷ 20)",
                  value: String(format: "%.2f", 4.0 + sqrt(Double(nutrients.workoutMinutes) / 20.0))),
            .init(label: "파도 진동수 (기본)",
                  formula: "0.4 + ln(공부 분 + 1) × 0.08",
                  value: String(format: "%.2f", 0.4 + log(Double(nutrients.studyMinutes) + 1.0) * 0.08)),
            .init(label: "물고기 수",
                  formula: "min(12, max(0, ⌊log₁₀(총분 + 1) × 3⌋ - 1))",
                  value: "\(p.fish.count)"),
            .init(label: "분위기 (mood)",
                  formula: "studyRatio 구간 → deepStudy/study/balanced/active/deepActive",
                  value: p.mood.rawValue),
            .init(label: "마스코트",
                  formula: "ratio ≥ 0.58 → 거북 | 0.42..0.58 → 문어 | < 0.42 → 게",
                  value: p.mascot.rawValue),
            .init(label: "바다 DNA",
                  formula: "씨앗 비트 → 마스코트 색 8종 × 물고기 체형 4종 × 무늬 3종",
                  value: p.dna.summary(mascot: p.mascot, accentHue: p.mood.accentHue)),
            .init(label: "장식 (마일스톤)",
                  formula: "누적 10h 산호 → 25h 해초 → 50h 난파선 → 100h 등대 → 300h 고래",
                  value: p.milestones.map(\.kind.koreanName).joined(separator: "·").isEmpty
                         ? "아직" : p.milestones.map(\.kind.koreanName).joined(separator: "·")),
            .init(label: "거품 수",
                  formula: "min(10, 운동 분 ÷ 15)",
                  value: "\(p.bubbles.count)"),
            .init(label: "불가사리 수",
                  formula: "min(6, 공부 분 ÷ 30)",
                  value: "\(p.seabed.count)"),
            .init(label: "하늘 토큰",
                  formula: "study → 달, balanced → 구름, active → 태양",
                  value: p.skyToken.rawValue),
            .init(label: "배경 색조 (HSL hue)",
                  formula: "mood.topHue",
                  value: String(format: "%.3f", p.bgHue)),
            .init(label: "활동 순서 시드",
                  formula: "FNV-1a(공부·운동 발생 순서) XOR 씨앗",
                  value: String(nutrients.sequenceHash % 100000)),
        ]
        for (i, wave) in p.waves.enumerated() {
            lines.append(.init(
                label: "파도 #\(i + 1)",
                formula: "y = \(String(format: "%.1f", wave.amplitude)) · sin(\(String(format: "%.2f", wave.frequency))x + \(String(format: "%.2f", wave.phase)))",
                value: "depth \(String(format: "%.2f", wave.depth))"
            ))
        }
        return lines
    }
}

public struct PlantFormulaLine: Hashable, Sendable {
    public let label: String
    public let formula: String
    public let value: String

    public init(label: String, formula: String, value: String) {
        self.label = label
        self.formula = formula
        self.value = value
    }
}