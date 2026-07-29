# 공유 익스텐션 → 영상 분석 파이프라인

프론트엔드가 릴스 링크를 받아 **음식점·음식·옵션을 뽑아내기까지의 전 과정**을 정리한 문서다.
백엔드가 이 단계를 서버로 가져갈 때 그대로 참고할 수 있도록, 프롬프트 전문과
응답 스키마를 실제 코드와 동일하게 실어 둔다.

작성: 윤수 (프론트엔드)
관련 코드: `lib/services/metadata_fetcher.dart`, `lib/services/gemini_extractor.dart`

---

## 전체 흐름

```
① 인스타 공유 시트 → 앱 실행 (링크 수신)
② 링크의 og 태그에서 제목·설명·계정명·썸네일 수집
③ 그 텍스트를 LLM 에 넣어 음식점·음식·옵션 추출
④ 추출 결과로 조합 구성 (현재는 프론트에서 추정, 향후 백엔드)
```

백엔드가 가져갈 부분은 **③이고, 경우에 따라 ②도 함께**다.
②를 서버가 하면 인스타 로그인 세션을 서버에 둘 수 있어 아래 "알려진 한계"를 해결할 수 있다.

---

## ① 공유 수신 — 플랫폼별로 다르다

| | 방식 | 받는 값 |
|---|---|---|
| **안드로이드** | `AndroidManifest.xml` 의 `ACTION_SEND` intent-filter | `Intent.EXTRA_TEXT` (원문 텍스트) |
| **iOS** | Swift Share Extension → `mukbang://analyze?u=<링크>` | URL 만 |

**현재는 양쪽 모두 URL 만 뽑아 쓰고 나머지 텍스트는 버린다.**
안드로이드는 인스타가 캡션을 함께 넘겨줄 여지가 있어, 이후 개선 대상이다.

iOS 는 익스텐션이 본체 앱을 직접 실행할 수 없어 URL 스킴을 경유한다.
응답자 체인에서 `openURL:options:completionHandler:` 를 찾아 호출하는 방식이며,
구형 `openURL:` 은 iOS 10 에서 폐기돼 `respondsToSelector` 가 true 를 주지만
실제로는 아무 동작도 하지 않는다.

---

## ② 텍스트 수집

링크를 GET 해서 og 태그를 파싱한다. 유튜브는 oEmbed 를 먼저 시도한다.

수집 항목:

| 필드 | 출처 |
|---|---|
| `title` | `og:title` (없으면 `<title>`) |
| `description` | `og:description` |
| `siteName` | `og:site_name` |
| `imageUrl` | `og:image` (유튜브는 oEmbed `thumbnail_url`) |

LLM 에 넘기는 텍스트는 `siteName + title + description` 을 줄바꿈으로 이어붙인 값이다.

### ⚠️ 알려진 한계 — 인스타가 캡션을 주지 않는다

**인스타그램은 로그아웃 상태의 요청에 캡션·제목을 내려주지 않는다.**
이 경우 `og:url` 의 계정명만 건져서 아래 문자열을 대신 넘긴다.

```
인스타그램 @udtmukbang 맛집 게시물
```

즉 **LLM 이 볼 수 있는 정보가 계정명 하나뿐**이 되어 추출 품질이 크게 떨어진다.
계정명이 곧 음식점이면 운 좋게 맞고, 아니면 거의 맞히지 못한다.

**해결 방향 (백엔드와 논의 필요)**
1. 서버가 인스타 세션을 들고 크롤링 → 캡션 확보
2. 안드로이드 공유 인텐트가 넘겨주는 원문 텍스트를 그대로 서버에 전달
3. oEmbed / Graph API 등 공식 경로 확인

`source.rawText` 를 API 에 포함하기로 한 것은 2번에 해당한다.

---

## ③ LLM 추출

모델: `gemini-2.5-flash`
`responseMimeType: application/json` + `responseSchema` 로 **응답이 항상 스키마를 지키도록 강제**한다.
`temperature: 0` 으로 같은 입력이면 같은 결과가 나오게 했다.

### 프롬프트 전문

```
아래는 SNS 게시물(릴스/영상/카드뉴스)의 제목·설명·계정명 텍스트입니다.
이 사람이 먹은 음식을 요기요에서 그대로 주문할 수 있도록 정보를 빠짐없이 뽑아주세요.
근거가 있으면 추론해도 되지만, 전혀 없으면 빈 값으로 두세요.

- restaurantName: 상호명. 지점이 있으면 지점까지 (예: "청년다방 송도점").
  계정명이 음식점이면 그걸 상호명으로. 정말 모를 때만 빈 문자열.
- brandName: 브랜드/체인명만 (예: "청년다방"). 개인 가게면 상호명과 같게.
- branchName: 지점명만 (예: "송도점"). 없으면 빈 문자열.
- foodCategory: 다음 중 하나로만. 한식, 중식, 일식, 양식, 분식, 치킨, 피자, 아시안, 카페·디저트
- area: 동네/지역 이름 (예: "성수동", "송도", "강남"). 모르면 빈 문자열.
- dishes: 영상에 나온 음식들을 등장 순서대로. 각 항목은
    · name: 메뉴 이름 (예: "레드콤보", "로제 닭발")
    · description: 영상에서 묘사된 내용을 한 문장으로
    · options: 주문할 때 골라야 하는 값들의 배열.
      뼈/순살, 맵기 단계, 사리·토핑 추가, 양 선택처럼
      요기요 메뉴 옵션에 해당하는 것을 모두 넣으세요.
      예: ["순살", "매운맛", "중국당면 추가", "치즈 추가"]
- keywords: 매칭·검색에 쓸 단어를 최대한 많이. 음식명, 재료, 조리법, 식감,
  먹는 상황("야식", "혼술", "해장")까지. 중복 없이 3~15개.
- spiceLevel: none, mild, medium, hot, extreme 중 하나. 판단 불가면 빈 문자열.
- servingCount: 몇 인분으로 보이는지 정수. 판단 불가면 0.
- isFranchise: 프랜차이즈면 true.
- summary: "이 영상을 이렇게 이해했다"를 한 문장으로. 사용자에게 그대로 보여줄 문장.
- confidence: 상호명 추출 확신도 0.0~1.0.

텍스트:
{여기에 ②에서 모은 텍스트}
```

### responseSchema

```jsonc
{
  "type": "OBJECT",
  "properties": {
    "restaurantName": { "type": "STRING" },
    "brandName":      { "type": "STRING" },
    "branchName":     { "type": "STRING" },
    "foodCategory":   { "type": "STRING" },
    "area":           { "type": "STRING" },
    "dishes": {
      "type": "ARRAY",
      "items": {
        "type": "OBJECT",
        "properties": {
          "name":        { "type": "STRING" },
          "description": { "type": "STRING" },
          "options":     { "type": "ARRAY", "items": { "type": "STRING" } }
        },
        "required": ["name", "description", "options"]
      }
    },
    "keywords":     { "type": "ARRAY", "items": { "type": "STRING" } },
    "spiceLevel":   { "type": "STRING" },
    "servingCount": { "type": "INTEGER" },
    "isFranchise":  { "type": "BOOLEAN" },
    "summary":      { "type": "STRING" },
    "confidence":   { "type": "NUMBER" }
  },
  "required": ["restaurantName","brandName","branchName","foodCategory","area",
               "dishes","keywords","spiceLevel","servingCount","isFranchise",
               "summary","confidence"]
}
```

---

## 출력 스키마

| 필드 | 타입 | 설명 |
|---|---|---|
| `restaurantName` | string | 상호명 전체. "교촌치킨 강남점" |
| `brandName` | string | 브랜드만. 프랜차이즈면 이걸로 근처 지점 검색 |
| `branchName` | string | 지점만. "강남점" |
| `foodCategory` | string | 9개 중 하나 (한식/중식/일식/양식/분식/치킨/피자/아시안/카페·디저트) |
| `area` | string | 동네 이름 |
| `dishes[]` | array | 영상에 나온 음식들, 등장 순서 |
| `dishes[].name` | string | 메뉴 이름 |
| `dishes[].description` | string | 영상에서 묘사된 내용 |
| **`dishes[].options[]`** | array | **주문 옵션. 요기요 메뉴 옵션과 대응** |
| `keywords[]` | array | 매칭·검색용 단어 3~15개 |
| `spiceLevel` | string | none / mild / medium / hot / extreme |
| `servingCount` | int | 인분 수. 0이면 판단 불가 |
| `isFranchise` | bool | 프랜차이즈 여부 |
| `summary` | string | 한 줄 요약. 사용자에게 그대로 노출 |
| `confidence` | number | 상호명 추출 확신도 0.0~1.0 |

### 실제 예시

**입력** (②에서 모은 텍스트)

```
Instagram
교촌치킨 강남점 신메뉴 먹방
레드콤보 진짜 미쳤다... 순살로 시켜서 치즈 추가했는데 허니콤보보다 맛있음 #강남맛집 #치킨
```

**출력**

```jsonc
{
  "restaurantName": "교촌치킨 강남점",
  "brandName": "교촌치킨",
  "branchName": "강남점",
  "foodCategory": "치킨",
  "area": "강남",
  "dishes": [
    {
      "name": "레드콤보",
      "description": "매콤한 소스에 순살로 나온 반반 치킨",
      "options": ["순살", "매운맛", "치즈 추가"]
    },
    {
      "name": "허니콤보",
      "description": "달콤한 허니 소스 치킨",
      "options": []
    }
  ],
  "keywords": ["치킨", "순살", "매운맛", "치즈", "강남", "야식"],
  "spiceLevel": "hot",
  "servingCount": 2,
  "isFranchise": true,
  "summary": "교촌치킨 강남점 레드콤보를 순살로 시켜 치즈를 추가해 먹는 먹방",
  "confidence": 0.9
}
```

---

## 제안 — `menus[]` 대신 `dishes[]` 를 써 주세요

백엔드 초안(`POST /api/v1/analyses`)의 `extracted` 는 아래 형태였다.

```jsonc
"extracted": {
  "restaurantName": "교촌치킨 강남점",
  "foodCategory": "치킨",
  "area": "강남",
  "menus": ["레드콤보", "허니콤보"],
  "confidence": 0.9
}
```

**`menus: ["레드콤보","허니콤보"]` 로는 주문 옵션이 전부 사라진다.**
`순살`, `매운맛`, `치즈 추가` 같은 값이 없으면 요기요 메뉴에 매칭해도
실제 주문을 구성할 수 없다. 사용자가 영상에서 본 그 조합을 재현하는 것이
이 서비스의 핵심이므로, `dishes[].options` 를 유지하는 쪽을 제안한다.

`brandName` / `isFranchise` 도 매장 검색 전략을 나누는 데 쓸 수 있다.
프랜차이즈면 브랜드명으로 사용자 위치 근처 지점을 찾으면 되고,
개인 가게면 상호명+지역으로 찾아야 한다.

`spiceLevel`, `servingCount` 는 필터 기본값으로 쓸 수 있고,
`summary` 는 "이 영상을 이렇게 이해했어요"를 사용자에게 보여주는 데 쓴다.

---

## 백엔드로 옮길 때 고려사항

- **API 키** — 현재 Gemini 키가 앱에 들어 있다. 서버로 옮기면 이 문제가 사라진다.
- **모델 교체** — 프롬프트와 스키마만 유지하면 모델은 자유롭게 바꿀 수 있다.
  앱은 스키마만 보고 있어서 영향받지 않는다.
- **재시도** — 현재 앱은 실패 시 1회 자동 재시도한다.
- **응답 시간** — Gemini 호출에 보통 2~5초. 타임아웃은 30초로 잡아 두었다.
- **결정성** — `temperature: 0` 이라 같은 입력이면 같은 결과가 나온다.
  캐싱을 붙이면 같은 링크 재분석 비용을 아낄 수 있다.
