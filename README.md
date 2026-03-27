# AIA Summary Prompt with GPT, Qwen3, and Qwen3.5

이 저장소는 보험 상담 STT 요약 프롬프트를 설계, 운영, 평가하기 위한 문서와 실행 자산을 정리한 공간입니다.
핵심 목표는 `원문`, `분석 힌트`, `현업 피드백 규칙`, `프롬프트 개선 규칙`을 분리해 관리하면서, GPT 계열과 Qwen3 계열 모델 모두에서 안정적으로 재사용 가능한 요약 체계를 만드는 것입니다.

## 핵심 개념

- `source.source_text`를 최우선 근거로 사용합니다.
- `audio_preprocess`는 STT 이전에 요약과 별도로 수행하는 음원 전처리 단계입니다.
- `source.source_text_cleaned`와 `stt_preprocess`는 전사 후 정제 결과입니다.
- 멀티턴 상담은 `speaker_staged` 전략으로 고객 발화와 상담사 발화를 먼저 나눈 뒤 최종 통합 요약합니다.
- 현업 요구사항은 프롬프트 본문에 계속 누적하지 않고 `feedback_rules`로 분리합니다.
- 반복 오류에서 추출한 재사용 규칙은 `prompt_improvement_rules`로 분리합니다.
- 모델별 편차는 프롬프트 자체를 갈아엎기보다 `실행 템플릿`, `모델별 프롬프트`, `평가 포맷`으로 제어합니다.
- 생성 직전 `self-check` 또는 내부 점검 규칙으로 누락, 주체 혼동, 상태 약화를 줄입니다.

## 폴더 구조

- `docs/architecture`
  - 프롬프트 설계 원칙, 입력 스키마, 레이어 전략, 설계 노트, 다이어그램, 원페이저
- `docs/analysis`
  - 실데이터 분석, 현업 피드백 케이스북, 프롬프트 개선 규칙 룰북
- `docs/evaluation`
  - 요약 품질 평가 기준, Qwen3/Qwen3.5/GPT 비교 포맷
- `prompts`
  - 실행 템플릿, GPT용 통합 프롬프트, Qwen3 전용 프롬프트, Qwen3.5 전용 프롬프트
- `examples`
  - 입력 예시, 레이어 설정 예시, 피드백 규칙 예시, 프롬프트 개선 규칙 예시
- `data/origin`
  - 원본 분석 데이터

## 어떤 파일을 보면 되는가

### 설계를 이해할 때

- `docs/architecture/prompt_architecture.md`: 프롬프트를 문장 덩어리가 아니라 운영 가능한 구조로 보는 설계 원칙
- `docs/architecture/input_schema.md`: 실행 입력 JSON 구조 정의
- `docs/architecture/audio_preprocessing_layer.md`: 음원 전처리를 요약과 분리해 다루는 레이어 설계
- `docs/architecture/stt_denoising_layer.md`: 전사 후 텍스트 정제 레이어 설계
- `docs/architecture/speaker_staged_summary.md`: 발화자 단계형 요약 전략 설계
- `docs/architecture/layered_prompt_strategy.md`: 고정/가변/학습 레이어 분리 전략
- `docs/architecture/design_notes.md`: 충돌 해소 우선순위와 반영 원칙
- `docs/architecture/feedback_prediction_guide.md`: 예상 현업 피드백을 규칙 유형으로 분류하는 가이드

### 실제 프롬프트를 사용할 때

- `prompts/execution_prompt_template.md`: 고정 레이어, 가변 레이어, 학습 레이어, 개선 규칙을 조립하는 기준 템플릿
- `prompts/summary_prompt_v2.md`: GPT 계열 모델 기준의 통합 실사용 프롬프트
- `prompts/qwen3_summary_prompt.md`: Qwen3-Instruct 계열 기본 프롬프트
- `prompts/qwen3_summary_prompt_v2.md`: Qwen3-Instruct 계열 보강 프롬프트
- `prompts/qwen3_5_summary_prompt.md`: Qwen3.5-Instruct 계열 권장 프롬프트

### 분석과 운영 규칙을 확장할 때

- `docs/analysis/stt_summary_20260311_analysis.md`: 원본 CSV 기반 STT 요약 품질 분석
- `docs/analysis/ops_feedback_casebook.md`: 현업 피드백 사례와 대응 방식
- `docs/analysis/prompt_improvement_rulebook.md`: 반복 오류를 공통 규칙으로 정리한 룰북
- `examples/feedback_rules_expected_ops.json`: 현업 요구사항을 운영 규칙 형태로 정리한 예시
- `examples/prompt_improvement_rules.json`: 반복 오류 재발 방지 규칙 예시

### 평가할 때

- `docs/evaluation/summary_quality_criteria.md`: 요약 품질 평가 기준표
- `docs/evaluation/qwen3_vs_gpt_ab_format.md`: Qwen3, Qwen3.5, GPT를 같은 기준으로 비교하는 포맷

## 현재 프롬프트가 보정하는 문제

실데이터 분석 기준으로 반복적으로 보인 문제는 아래였습니다.

1. 고객 요청보다 배경 설명이 먼저 나오는 문제
2. 계약자/문의자/피보험자/보장 대상 주체 혼동
3. 처리 상태와 상담사 후속조치 누락
4. 개인정보, 상세 금액, 상세 시각 같은 비핵심 정보 과다 반영
5. 완료/진행/해지/유지 같은 상태 표현 약화
6. 다른 맥락의 STT 조각이 섞인 문장을 과감히 제외하지 못하는 문제
7. 고객 발화와 상담사 발화가 최종 요약에서 섞이는 문제

이에 따라 현재 자산은 아래 방향으로 정리되어 있습니다.

1. 고객 요청 사항을 앞쪽 섹션에 강제
2. 관계 정보, 처리 상태, 상담사 후속조치를 분리해서 요약
3. 개인정보와 비핵심 세부값을 억제
4. 원문 상태 표현을 그대로 보존
5. 본인 계약 문의와 피보험자 실제 상황을 구분
6. 발화자 단계형 요약으로 역할 혼동을 줄임
7. 출력 직전 자체 점검 규칙으로 누락과 과다 반영을 재검토

## 권장 사용 흐름

1. 음원이 있으면 먼저 `audio_preprocess`를 STT 이전 별도 프로세스로 실행합니다.
2. 입력 원문을 `source.source_text`에 넣습니다.
3. STT 전사본은 `scripts/Invoke-SttDenoising.ps1` 또는 `scripts/Invoke-SttAugmentation.ps1`로 정제해 `source.source_text_cleaned`와 `stt_preprocess`를 만듭니다.
4. 화자 정보가 있으면 `speaker_map`을 넣고 `task_config.summary_strategy`를 `speaker_staged`로 설정합니다.
5. 상담 유형별 요구 섹션은 `task_config.required_sections`로 조정합니다.
6. 현업 요구사항은 `feedback_rules`에 넣습니다.
7. 반복 오류 보정 포인트는 `analysis_hints`에 넣습니다.
8. 재발 방지 규칙은 `prompt_improvement_rules`에 넣습니다.
9. GPT 계열은 `prompts/summary_prompt_v2.md`, Qwen3 계열은 `prompts/qwen3_summary_prompt.md` 또는 `prompts/qwen3_summary_prompt_v2.md`, Qwen3.5 계열은 `prompts/qwen3_5_summary_prompt.md`를 기본으로 사용합니다.
10. 결과 평가는 `docs/evaluation/summary_quality_criteria.md`와 `docs/evaluation/qwen3_vs_gpt_ab_format.md`를 함께 사용합니다.

## STT 전처리 오케스트레이션

요약 프로세스와 별도로, 아래 순서로 음원 전처리와 전사 후 정제를 분리해 운영합니다.

```text
Raw Audio
  -> audio_preprocess
  -> STT
  -> stt_preprocess
  -> summary
```

권장 문서:

- `AUDIO_PREPROCESSING.md`
- `docs/architecture/audio_preprocessing_layer.md`
- `docs/architecture/stt_denoising_layer.md`

통합 CSV 증강 스크립트 예시:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-SttAugmentation.ps1 `
  -InputCsv .\examples\stt_denoising_sample.csv
```

이 스크립트는 아래를 함께 생성합니다.

- `source_text_cleaned`
- `stt_preprocess_*`
- `audio_preprocess_*`

## 발화자 단계형 요약

`OPTIMIZATION_2.md` 기준으로, 멀티턴 대화는 아래 절차를 기본 경로로 사용합니다.

```text
STT 전사
  -> 화자 분리
  -> 문장 분할
  -> 고객 발화 정리
  -> 상담사 발화 정리
  -> 발화자별 중간 요약
  -> 최종 통합 요약
```

적용 기준:

- 짧은 대화: 발화자별 원문 묶음 기반 요약
- 긴 대화: 문장 단위 정리 후 발화자별 묶음 요약
- 멀티턴 상담, 후속조치 누락, 역할 혼동이 잦은 케이스: `Qwen3.5-Instruct + speaker_staged`

## 모델별 사용 가이드

### GPT 계열

- `prompts/summary_prompt_v2.md`를 기본 실사용 프롬프트로 사용합니다.
- 발화자 단계형 요약 절차를 내부 규칙으로 포함합니다.
- 다양한 케이스를 하나의 구조에서 관리하려면 이 프롬프트를 기준으로 운영하는 것이 좋습니다.

### Qwen3-Instruct 계열

- `prompts/qwen3_summary_prompt.md` 또는 `prompts/qwen3_summary_prompt_v2.md`를 사용합니다.
- `speaker_staged` 전략을 함께 쓰는 편이 멀티턴 대화에서 더 안정적입니다.
- 저장소 내 권장 시작값은 낮은 `temperature`와 보수적인 `top_p`입니다.

### Qwen3.5-Instruct 계열

- `prompts/qwen3_5_summary_prompt.md`를 우선 사용합니다.
- 역할 혼동, 후속조치 누락, 멀티턴 대화 정리에 가장 우선 적용할 모델 경로로 봅니다.
- 권장 조합은 `Qwen3.5-Instruct + speaker_staged + source_text_cleaned + stt_preprocess`입니다.

## 현업 피드백 반영 절차

1. 현업 코멘트를 `누락`, `과다`, `순서`, `용어`, `근거성`, `주체 혼동`, `상태 약화` 중 하나로 먼저 분류합니다.
2. 단건 수정인지 반복 패턴인지 구분합니다.
3. 반복 패턴이면 `examples/feedback_rules_expected_ops.json` 또는 `examples/prompt_improvement_rules.json`에 먼저 반영합니다.
4. 프롬프트 본문 수정 전에 `feedback_rules`, `prompt_improvement_rules`, `self-check` 보강으로 해결 가능한지 먼저 확인합니다.
5. 유사 사례는 `docs/analysis/ops_feedback_casebook.md`에서 찾아 재사용합니다.
6. 변경 전후 결과는 `docs/evaluation/summary_quality_criteria.md` 기준으로 비교합니다.

## 빠른 시작

1. 설계 원칙이 필요하면 `docs/architecture/prompt_architecture.md`부터 읽습니다.
2. 실행 구조를 확인하려면 `prompts/execution_prompt_template.md`를 봅니다.
3. GPT 계열 실사용은 `prompts/summary_prompt_v2.md`를 사용합니다.
4. Qwen3 실사용은 `prompts/qwen3_summary_prompt.md` 또는 `prompts/qwen3_summary_prompt_v2.md`를 사용합니다.
5. Qwen3.5 실사용은 `prompts/qwen3_5_summary_prompt.md`를 사용합니다.
6. 샘플 입력은 `examples/input_example.json`과 `examples/layer_configs_example.json`을 참고합니다.
7. 평가 포맷은 `docs/evaluation/qwen3_vs_gpt_ab_format.md`를 사용합니다.

## CSV가 깨져 보일 때

- 저장소의 원본 CSV는 `UTF-8 BOM` 기준으로 다루는 것을 권장합니다.
- PowerShell이나 후처리 과정에서 다시 저장하면 BOM이 빠지거나 기본 인코딩으로 바뀌면서 Excel에서 한글이 깨질 수 있습니다.
- 셀 안 줄바꿈이 많은 파일은 메모장에서는 정상이어도 Excel에서 행이 어긋나 보일 수 있습니다.

아래 스크립트로 Excel용 사본을 다시 만들 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Repair-CsvForExcelWinPS.ps1 `
  -InputCsv .\data\origin\stt_summary_20260319_000000.csv
```

탭 구분 TSV가 더 안전하면 아래처럼 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Repair-CsvForExcelWinPS.ps1 `
  -InputCsv .\data\origin\stt_summary_20260319_000000.csv `
  -AsTsv
```
