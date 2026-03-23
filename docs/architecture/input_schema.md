# 입력 데이터 구조

## 목적

요약 정확도를 프롬프트 문장만으로 끌어올리는 데 한계가 있을 때,
입력 데이터를 역할별로 분리해 모델이 원문, 정제본, 규칙을 구분해서 사용하도록 한다.

핵심 원칙은 아래와 같다.

1. `source.source_text`는 최종 사실 근거다.
2. `source.source_text_cleaned`는 STT 노이즈를 줄인 작업용 입력이다.
3. `stt_preprocess`는 무엇을 제거했고 무엇이 불확실한지 설명하는 전처리 메타데이터다.
4. `feedback_rules`, `analysis_hints`는 사실 생성용이 아니라 점검 규칙이다.

## 권장 상위 구조

```json
{
  "source": {},
  "stt_preprocess": {},
  "task_config": {},
  "feedback_rules": {},
  "analysis_hints": {}
}
```

## 1. `source`

원문과 기본 메타정보를 담는다.

```json
{
  "source_text": "상담 원문",
  "source_text_cleaned": "불필요한 군더더기와 명백한 혼입을 줄인 정제본",
  "channel": "call_center",
  "consult_type": "보험금청구",
  "speaker_map": {
    "A": "고객",
    "B": "상담사"
  }
}
```

역할:

- `source_text`: 최종 판정용 원문
- `source_text_cleaned`: 1차 정보 추출용 작업 입력
- `consult_type`, `speaker_map`: 관계와 문맥 해석 보조 정보

운영 규칙:

1. `source_text_cleaned`가 있으면 모델은 먼저 정제본에서 핵심 정보를 추출한다.
2. 추출 결과가 중요한 판단에 연결될 때는 `source_text`로 다시 확인한다.
3. 정제본에만 있고 원문 근거가 불명확한 내용은 제외한다.

## 2. `stt_preprocess`

정제 과정에서 제거하거나 보류한 내용을 구조화한다.

```json
{
  "cleanup_applied": [
    "반복 인사말 제거",
    "본인확인용 개인정보 제거",
    "무관한 혼입 문장 제거"
  ],
  "uncertain_spans": [
    "상품명으로 보이나 발음이 불명확한 구간",
    "숫자 후보가 여러 개로 들리는 구간"
  ],
  "noise_patterns": [
    "상담 목적과 무관한 확인용 생년월일",
    "반복된 네/네/잠시만요",
    "다른 상담 맥락이 섞인 것으로 보이는 문장"
  ],
  "retained_key_facts": [
    "고객 요청",
    "처리 상태",
    "상담사 후속조치"
  ]
}
```

## 3. `task_config`

이번 실행의 목표와 출력 형식을 담는다.

```json
{
  "summary_goal": "고객 관점 핵심 요약",
  "output_format": "bullet",
  "required_sections": [
    "고객 요청 사항",
    "계약/대상 관계",
    "핵심 상황",
    "민원/불만",
    "처리 상태",
    "상담사 후속조치",
    "기한/긴급성",
    "특이사항"
  ],
  "max_items": 8
}
```

## 4. `feedback_rules`

현업 피드백에서 검증된 운영 규칙을 담는다.

```json
{
  "must_include": [
    "계약자/피보험자 관계",
    "처리 상태",
    "불만 사유",
    "상담사 후속조치"
  ],
  "must_avoid": [
    "상담사 인사말",
    "장황한 배경 설명",
    "본인확인용 개인정보"
  ]
}
```

## 5. `analysis_hints`

이전 평가에서 확인된 취약점을 담는다.

```json
{
  "missing_points": [
    "상담 목적 누락 여부",
    "처리 상태 누락 여부",
    "후속조치 누락 여부"
  ],
  "over_summary_points": [
    "개인정보 과다 포함",
    "업무와 무관한 세부 숫자 포함"
  ]
}
```

## 권장 운영 규칙

1. `source.source_text`는 항상 유지한다.
2. 노이즈가 심한 STT는 `source.source_text_cleaned`와 `stt_preprocess`를 함께 넣는다.
3. 정제 단계에서는 삭제보다 `불확실 표시`를 우선한다.
4. 요약 모델은 정제본을 우선 읽되, 상태/주체/수치 판단은 원문으로 재확인한다.
5. 원문과 정제본이 충돌하면 원문을 우선하고, 원문도 불명확하면 제외한다.
