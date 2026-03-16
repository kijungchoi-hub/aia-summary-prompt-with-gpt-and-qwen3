# AIA Summary Prompt with GPT and Qwen3

이 디렉터리는 요약 프롬프트 고도화를 위해 `원문`, `LLM 분석 결과`, `현업(고객) 피드백`을 함께 반영하는 설계 문서와 실행 자산을 정리한 공간입니다.

## 폴더 구조

- `docs/architecture`
  - 프롬프트 설계 원칙, 입력 구조, 레이어 분리, 설계 노트
- `docs/evaluation`
  - 요약 품질 평가 기준
- `docs/analysis`
  - 실제 STT 요약 데이터 분석 결과
- `prompts`
  - 실행 프롬프트 템플릿과 요약 프롬프트 초안
- `examples`
  - 입력 예시와 레이어 설정 예시
- `data/origin`
  - 원본 분석 데이터

## 주요 파일

- `docs/architecture/prompt_architecture.md`: 프롬프트 설계 원칙서
- `docs/architecture/input_schema.md`: 입력 데이터 구조안
- `docs/architecture/layered_prompt_strategy.md`: 고정/가변/학습 레이어 분리안
- `docs/architecture/design_notes.md`: 반영 원칙과 충돌 해소 규칙
- `docs/evaluation/summary_quality_criteria.md`: 요약 품질 기준표
- `docs/analysis/stt_summary_20260311_analysis.md`: `stt_summary_20260311_170910.csv` 분석 결과
- `prompts/execution_prompt_template.md`: 실행 프롬프트 템플릿
- `prompts/summary_prompt_v2.md`: 실사용 프롬프트 초안
- `examples/input_example.json`: 모델 입력 예시
- `examples/layer_configs_example.json`: 레이어별 설정 예시

## 분석 결과 반영 요약

실데이터 기준으로 가장 큰 문제는 `정상 STT 과다 반영`과 `업무 핵심 정보 누락`이었습니다.
따라서 현재 프롬프트 자산은 아래 방향으로 보정되어 있습니다.

1. 고객 요청 사항을 먼저 요약
2. 계약자/피보험자 관계, 처리 상태, 후속조치 우선 반영
3. 개인정보와 비핵심 세부값 억제
4. 완료/진행/해지/유지 등 상태 표현 보존

## 권장 운영 방식

1. `source_text`는 항상 1차 근거로 둡니다.
2. `llm_analysis`는 누락/과다/표현 품질 개선에 사용합니다.
3. `customer_feedback`는 출력 우선순위와 현업 용어를 조정하는 데 사용합니다.
4. 세 입력이 충돌하면 `docs/architecture/design_notes.md`의 우선순위 규칙을 따릅니다.
5. 실제 적용 전에는 `docs/architecture/prompt_architecture.md`와 `docs/architecture/layered_prompt_strategy.md` 기준으로 프롬프트 책임 범위를 먼저 고정하는 것이 좋습니다.
