# AIA Summary Prompt with GPT and Qwen3

이 디렉터리는 요약 프롬프트 고도화를 위해 `원문`, `LLM 분석 결과`, `현업(고객) 피드백`을 함께 반영하는 설계 문서와 실행 자산을 정리한 공간입니다.
핵심 목표는 현업 피드백을 프롬프트 본문에 계속 누적하지 않고, `고정 규칙`, `가변 설정`, `학습 규칙`, `프롬프트 개선 규칙`, `자체검증`으로 분리해 안정적으로 운영하는 것입니다.

## 폴더 구조

- `docs/architecture`
  - 프롬프트 설계 원칙, 입력 구조, 레이어 분리, 설계 노트, 현업 피드백 예측 가이드, 다이어그램 문서
- `docs/evaluation`
  - 요약 품질 평가 기준
- `docs/analysis`
  - 실제 STT 요약 데이터 분석 결과, 샘플 기반 현업 피드백 대응표, 공통 프롬프트 개선 규칙 룰북
- `prompts`
  - 실행 프롬프트 템플릿과 요약 프롬프트 초안
- `examples`
  - 입력 예시와 레이어 설정 예시, 프롬프트 개선 규칙 예시
- `data/origin`
  - 원본 분석 데이터

## 주요 파일

- `docs/architecture/prompt_architecture.md`: 프롬프트 설계 원칙서
- `docs/architecture/input_schema.md`: 입력 데이터 구조안
- `docs/architecture/layered_prompt_strategy.md`: 고정/가변/학습 레이어 분리안
- `docs/architecture/design_notes.md`: 반영 원칙과 충돌 해소 규칙
- `docs/architecture/feedback_prediction_guide.md`: 예상 현업 피드백을 규칙 유형으로 분류하는 가이드
- `docs/architecture/layered_summary_prompt_diagram.md`: 문서용 Mermaid 아키텍처 다이어그램
- `docs/architecture/layered_summary_prompt_onepager.md`: 발표용 1장 설명 문서
- `docs/evaluation/summary_quality_criteria.md`: 요약 품질 기준표
- `docs/analysis/stt_summary_20260311_analysis.md`: `stt_summary_20260311_170910.csv` 분석 결과
- `docs/analysis/ops_feedback_casebook.md`: 샘플 기반 현업 피드백 대응표
- `docs/analysis/prompt_improvement_rulebook.md`: CSV 기반 공통 프롬프트 개선 규칙 룰북
- `prompts/execution_prompt_template.md`: 실행 프롬프트 템플릿
- `prompts/summary_prompt_v2.md`: 실사용 프롬프트 초안
- `examples/input_example.json`: 모델 입력 예시
- `examples/layer_configs_example.json`: 레이어별 설정 예시
- `examples/feedback_rules_expected_ops.json`: 예상 현업 피드백을 반영한 운영용 규칙 예시
- `examples/prompt_improvement_rules.json`: 반복 오류를 공통 규칙으로 정리한 프롬프트 개선 규칙 세트

## 분석 결과 반영 요약

실데이터 기준으로 가장 큰 문제는 `정상 STT 과다 반영`과 `업무 핵심 정보 누락`이었습니다.
따라서 현재 프롬프트 자산은 아래 방향으로 보정되어 있습니다.

1. 고객 요청 사항을 먼저 요약
2. 계약자/피보험자 관계, 처리 상태, 후속조치 우선 반영
3. 개인정보와 비핵심 세부값 억제
4. 완료/진행/해지/유지 등 상태 표현 보존
5. 본인 계약 문의와 피보험자 주체를 분리하는 관계 규칙 반영
6. 생성 직전 `self-check`로 누락과 과다 반영을 점검

## 권장 운영 방식

1. `source_text`는 항상 1차 근거로 둡니다.
2. `analysis_hints`는 반복적으로 발견된 누락, 과다 반영, 품질 이슈를 보정하는 데 사용합니다.
3. `feedback_rules`는 현업이 실제로 요구하는 포함 항목, 제외 항목, 우선순위, 용어를 관리하는 데 사용합니다.
4. `prompt_improvement_rules`는 반복 오류에서 공통 규칙을 추출해 재사용하는 데 사용합니다.
5. 세 입력이 충돌하면 `docs/architecture/design_notes.md`의 우선순위 규칙을 따릅니다.
6. 실행 전에는 `prompts/execution_prompt_template.md`의 `self-check` 항목까지 포함해 조립하는 것이 좋습니다.
7. 반복 오류는 `examples/prompt_improvement_rules.json`과 `docs/analysis/prompt_improvement_rulebook.md`에 누적해 재사용합니다.

## 현업 피드백 반영 절차

1. 현업 코멘트를 먼저 `누락`, `과다`, `순서`, `용어`, `근거성` 중 하나로 분류합니다.
2. 반복되는 피드백은 `examples/feedback_rules_expected_ops.json`, `examples/prompt_improvement_rules.json`에 반영합니다.
3. 프롬프트 본문 수정이 필요한지 보기 전에 `feedback_rules`, `prompt_improvement_rules`, `self-check` 보강으로 해결 가능한지 먼저 확인합니다.
4. 실제 샘플 기준으로는 `docs/analysis/ops_feedback_casebook.md`에서 유사 케이스를 찾아 대응 방식을 재사용합니다.
5. 변경 전후 품질은 `docs/evaluation/summary_quality_criteria.md` 기준으로 비교합니다.
