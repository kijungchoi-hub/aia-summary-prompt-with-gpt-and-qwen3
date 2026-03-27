# 음원 전처리 레이어 설계

## 목적

`AUDIO_PREPROCESSING.md`에서 제안한 음원 품질 개선 단계를
요약 프롬프트나 STT 텍스트 정제와 분리된 별도 프로세스로 운영하기 위한 문서다.

핵심 원칙은 아래 3가지다.

1. 음원 전처리는 요약 프로세스의 일부가 아니라 STT 이전 독립 단계다.
2. 요약 모델은 음원 전처리 결과를 상담 사실이 아니라 입력 품질 메타데이터로만 사용한다.
3. 음원 전처리와 텍스트 전처리를 분리해 병목 위치를 명확히 본다.

## 권장 처리 순서

```text
Raw Audio
  -> audio_preprocess
  -> STT
  -> stt_preprocess
  -> summary
```

## `audio_preprocess` 역할

`audio_preprocess`는 아래 항목을 기록한다.

- 어떤 전처리 파이프라인을 적용했는지
- 어느 단계가 우선순위인지
- STT 이전 별도 단계로 돌렸는지
- 목표 포맷이 무엇인지
- 실제 실행 여부 또는 계획 상태가 무엇인지

이 블록은 요약 사실 생성용 입력이 아니다.
모델이 참조해야 하는 것은 상담 내용이 아니라 입력 신뢰도와 운영 방식이다.

## 권장 스키마

```json
{
  "audio_preprocess": {
    "run_mode": "separate_pre_stt",
    "status": "planned",
    "pipeline": [
      "noise_reduction",
      "volume_normalization",
      "vad",
      "speaker_diarization",
      "overlap_handling",
      "segment_split",
      "format_normalization_16khz_mono"
    ],
    "priority_steps": [
      "noise_reduction",
      "vad",
      "speaker_diarization"
    ],
    "target_format": "16kHz mono",
    "notes": [
      "음원 전처리는 요약 프로세스와 분리된 STT 사전 단계로 운영"
    ]
  }
}
```

## 단계별 운영 기준

1. `noise_reduction`
배경 소음, 키보드, 환경음을 줄인다.

2. `volume_normalization`
발화 크기 편차를 줄여 모델 입력을 안정화한다.

3. `vad`
무음 구간을 줄여 STT 입력 길이와 불필요 전사를 낮춘다.

4. `speaker_diarization`
고객과 상담사 역할을 분리해 요약 구조 인식을 돕는다.

5. `overlap_handling`
동시 발화 구간을 별도 세그먼트로 분리해 오인식을 줄인다.

6. `segment_split`
긴 음원을 짧은 세그먼트로 분할해 STT 안정성을 높인다.

7. `format_normalization_16khz_mono`
입력 포맷을 통일해 엔진별 편차를 줄인다.

## 요약 단계와의 연결 원칙

1. `audio_preprocess`는 요약문에 직접 출력하지 않는다.
2. 요약 사실 추출은 `source.source_text_cleaned` 우선, 최종 검증은 `source.source_text` 우선 원칙을 유지한다.
3. 음원 전처리 실패 또는 미적용이 확인되면, 요약 단계에서는 불확실 정보 제외 기준을 더 엄격히 적용한다.

