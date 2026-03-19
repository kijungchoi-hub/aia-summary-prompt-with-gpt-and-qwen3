# Layered Summary Prompt Diagram

## Full Architecture

```mermaid
flowchart TB
    A[Raw Input Layer] --> A1[source.source_text]
    A --> A2[source.consult_type]
    A --> A3[source.channel / speaker_map]

    B[Task Configuration Layer] --> B1[task_config.summary_goal]
    B --> B2[task_config.required_sections]
    B --> B3[task_config.output_style]
    B --> B4[task_config.max_items]

    C[Feedback Rule Layer] --> C1[feedback_rules.must_include]
    C --> C2[feedback_rules.must_avoid]
    C --> C3[feedback_rules.preferred_labels]
    C --> C4[feedback_rules.priority_topics]
    C --> C5[feedback_rules.negative_patterns]

    D[Analysis Hint Layer] --> D1[analysis_hints.missing_points]
    D --> D2[analysis_hints.over_summary_points]
    D --> D3[analysis_hints.quality_issues]
    D --> D4[analysis_hints.suggested_focus]

    E[Fixed Rule Layer]
    E --> E1[Grounding to source text]
    E --> E2[No unsupported facts]
    E --> E3[PII and chatter suppression]
    E --> E4[Status meaning preservation]
    E --> E5[Strict output format]

    A --> F[Fact Extraction]
    E --> F

    F --> G[Candidate Fact Set]
    G --> H[Missing Check]
    D --> H

    H --> I[Priority Reordering]
    B --> I
    C --> I

    I --> J[Suppression Filter]
    C --> J
    D --> J
    E --> J

    J --> K[Label Mapping]
    C --> K

    K --> L[Section Assembly]
    B --> L

    L --> M[Self-Check Layer]
    M --> M1[Customer request visible first]
    M --> M2[Processing status included]
    M --> M3[Agent follow-up included]
    M --> M4[Relation info included if present]
    M --> M5[Complaint not buried by background]
    M --> M6[PII and non-core details removed]
    M --> M7[No guesswork or over-interpretation]
    M --> M8[Section order and labels valid]

    M --> N[Final Summary Output]
    N --> N1[고객 요청 사항]
    N --> N2[계약/대상 관계]
    N --> N3[핵심 상황]
    N --> N4[민원/불만]
    N --> N5[처리 상태]
    N --> N6[상담사 후속조치]
    N --> N7[기한/긴급성]
    N --> N8[특이사항]
```

## Simplified Flow

```mermaid
flowchart LR
    A[원문 입력] --> B[사실 추출]
    C[현업 피드백 규칙] --> D[포함/제외/우선순위 제어]
    E[분석 힌트] --> D
    F[고정 정책 규칙] --> D
    B --> D
    D --> G[섹션별 재구성]
    G --> H[자체검증]
    H --> I[최종 상담요약]
```

## Layer Definition

1. Input Layer
   - `source`
   - `task_config`
   - `feedback_rules`
   - `analysis_hints`
2. Control Layer
   - grounding rules
   - inclusion rules
   - exclusion rules
   - priority rules
   - label rules
3. Composition Layer
   - fact extraction
   - missing check
   - reordering
   - filtering
   - section assembly
4. Validation Layer
   - self-check
   - format check
   - final output

## Summary

이 구조는 `원문`에서 사실을 추출하고, `현업 피드백`과 `분석 힌트`로 포함/제외/우선순위를 제어한 뒤, `자체검증`을 거쳐 고정된 실무 섹션으로 출력하는 레이어드 프롬프트 아키텍처다.
