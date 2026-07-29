# 요기족보 API 명세 (초안)

**요기족보** — 사용자들이 자기 먹방 조합을 공유하고, 실시간 인기 조합을 보고,
마음에 들면 그대로 주문하는 커뮤니티 기능. (구 '먹슐랭')

작성: 윤수 (프론트엔드) · 상태: **초안, 논의용**
근거: Figma `수정됨` 섹션의 먹슐랭 플로우 4화면 + 3차 회의록

> 이 문서는 프론트에서 화면을 보고 역산한 초안이다.
> 실제 스키마·경로는 백엔드에서 확정해 주시면 그에 맞추겠다.

---

## 화면 → API 대응

| Figma 화면 | 필요한 API |
|---|---|
| 요기족보 홈 (`55:249`) | 게시글 목록 조회 |
| 조합 상세 (`63:1146`) | 게시글 상세, 댓글 목록, 좋아요, 나도 주문하기 |
| 조합 공유 (`23:1224`) | 게시글 작성, 이미지 업로드 |

---

## 도메인 모델

### Post (조합 게시글)

```jsonc
{
  "id": "post_01H8X...",
  "title": "떵개 추천 두찜 로제 닭발",     // 최대 20자 (Figma: 0/20)
  "body": "진짜 미쳤어요 꼭 드셔보세요",    // 최대 400자 (Figma: 0/400)
  "imageUrls": ["https://.../1.jpg"],      // 첨부 사진
  "author": {
    "id": "user_01H8X...",
    "nickname": "배고픈 요기요",
    "profileImageUrl": "https://..."
  },
  "combo": { /* 아래 Combo */ },
  "likeCount": 12,
  "likedByMe": false,                      // 하트 채움 여부
  "commentCount": 4,
  "createdAt": "2026-07-07T12:30:00+09:00",
  "orderableHere": true                    // 내 위치에서 주문 가능한지 (아래 참고)
}
```

### Combo (게시글에 담긴 조합)

**중요: 게시글의 조합은 작성 시점의 스냅샷으로 저장해 주세요.**
매장이 메뉴를 바꾸거나 가격을 올려도 예전 게시글은 그때 모습 그대로 보여야 한다.
"나도 주문하기"를 누를 때 현재 가격으로 다시 조회하면 된다.

```jsonc
{
  "store": {
    "id": "store_123",
    "name": "두찜-잠실새내점",
    "imageUrl": "https://...",
    "rating": 4.2,
    "reviewCount": 312
  },
  "items": [
    {
      "menuId": "menu_456",
      "name": "[원조 K 로제] 로제 닭발",
      "options": ["순살", "보통맛", "분모자로 변경", "치즈몽땅 추가"],
      "description": "",
      "unitPrice": 23000,
      "quantity": 1,
      "imageUrl": "https://..."
    }
  ],
  "itemsTotal": 27000,
  "deliveryFee": 1500,
  "payableTotal": 28500        // Figma 조합 상세의 "결제 금액"
}
```

---

## 엔드포인트

### 1. 게시글 목록 — 요기족보 홈

```
GET /api/v1/posts
```

**Query**

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `sort` | enum | `LATEST` \| `POPULAR` — Figma 상단 "최신순" 드롭다운 |
| `orderableOnly` | bool | "내 위치에서 가능한 조합만" 체크박스 |
| `lat`, `lng` | number | `orderableOnly=true` 일 때 필수 |
| `cursor` | string | 페이지네이션 |
| `size` | int | 기본 20 |

**Response**

```jsonc
{
  "items": [ /* Post 배열. 목록에서는 combo.items 를 생략해도 됨 */ ],
  "nextCursor": "eyJpZCI6..."
}
```

목록 화면에는 **제목·썸네일·좋아요 수**만 보이므로, 조합 전체를 내려주면 낭비다.
목록용 축약 응답을 따로 두는 쪽을 제안한다.

> **논의 필요** — "실시간 인기"의 기준이 무엇인가?
> 전체 누적 좋아요인지, 최근 24시간 좋아요인지, 조회수를 섞는지.

---

### 2. 게시글 상세

```
GET /api/v1/posts/{postId}
```

**Response**: `Post` 전체 (combo 포함)

---

### 3. 게시글 작성 — 조합 공유

```
POST /api/v1/posts
```

**Request**

```jsonc
{
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "진짜 미쳤어요",
  "imageUrls": ["https://..."],   // 업로드 API 로 먼저 올린 뒤 URL 만 전달
  "orderId": "order_789"          // 주문 이력에서 조합을 가져올 때
}
```

Figma의 "주문한 메뉴" 영역이 **주문 이력에서 고르는 UI** 로 보인다.
그렇다면 `orderId` 만 보내고 서버가 조합 스냅샷을 만드는 쪽이 깔끔하다.

> **논의 필요** — 주문하지 않은 조합도 공유할 수 있어야 하나?
> 그렇다면 `combo` 객체를 통째로 받는 형태도 필요하다.

**Response**: 생성된 `Post`

---

### 4. 이미지 업로드

```
POST /api/v1/uploads/images
```

멀티파트 업로드 또는 presigned URL 발급 중 서버 편한 쪽으로.
프론트는 **최종 URL 문자열만** 받으면 된다.

> **논의 필요** — 장수 제한, 용량 제한, 허용 포맷

---

### 5. 좋아요

```
POST   /api/v1/posts/{postId}/likes     좋아요
DELETE /api/v1/posts/{postId}/likes     취소
```

**Response**

```jsonc
{ "likeCount": 13, "likedByMe": true }
```

낙관적 업데이트를 위해 **변경 후 카운트를 응답에 포함**해 주면 좋다.

---

### 6. 댓글

```
GET  /api/v1/posts/{postId}/comments?cursor=&size=
POST /api/v1/posts/{postId}/comments   { "body": "저도 시켜봤어요" }
```

**Comment**

```jsonc
{
  "id": "comment_01H...",
  "author": { "id": "...", "nickname": "배고픈 요기요", "profileImageUrl": "..." },
  "body": "저도 시켜봤어요",
  "createdAt": "2026-07-07T12:35:00+09:00"
}
```

> **논의 필요** — 대댓글이 필요한가? Figma 에는 1단계 댓글만 보인다.
> 삭제·수정은 이번 범위에 넣을 것인가?

---

### 7. 나도 주문하기

조합 상세의 핵심 CTA. 남의 조합을 내 장바구니로 복사한다.

```
POST /api/v1/posts/{postId}/reorder
```

**Request**

```jsonc
{ "lat": 37.5445, "lng": 127.0557 }
```

**Response**

```jsonc
{
  "orderable": true,
  "combo": { /* 현재 가격·재고로 다시 계산한 Combo */ },
  "unavailableItems": []      // 품절·단종된 메뉴가 있으면 여기에
}
```

게시글의 조합은 **스냅샷**이므로 지금도 주문 가능한지는 알 수 없다.
이 API 가 현재 시점으로 다시 확인해 준다.

> **논의 필요** — 사용자 위치에 배달 불가한 매장이면 어떻게 하나?
> 같은 브랜드의 다른 지점을 대신 제안할 것인가?

---

## 공통 규칙 — 확정 부탁드립니다

전체 API 에 걸치는 항목이라 먼저 정하면 이후 작업이 빨라진다.

| 항목 | 제안 |
|---|---|
| **인증** | `Authorization: Bearer <token>`. 목록·상세는 비로그인 허용, 작성·좋아요·댓글은 로그인 필요 |
| **에러 형식** | `{ "code": "POST_NOT_FOUND", "message": "..." }` + 적절한 HTTP 상태코드 |
| **날짜** | ISO 8601 + 타임존 (`2026-07-07T12:30:00+09:00`) |
| **페이지네이션** | 커서 방식. 실시간 피드라 오프셋은 중복·누락이 생긴다 |
| **빈 값** | 배열은 `[]`, 객체는 `null`. **키 자체를 빼지 않기** (클라이언트가 터진다) |
| **이미지 URL** | 항상 절대 경로 |
| **enum** | 대문자 스네이크. `LATEST`, `POPULAR` |

---

## 미해결 항목

1. **"실시간 인기" 산정 기준** — 좋아요 누적? 최근 24h? 조회수 반영?
2. **주문 이력 없이도 공유 가능한가**
3. **찜 연동** — 회의록의 "조합된 메뉴는 요기요 찜에 저장" 을 이 API 에 포함할지,
   별도 찜 API 로 뺄지
4. **신고·차단** — 커뮤니티라 필요할 수 있으나 이번 범위에서는 제외 제안
5. **위치** — `orderableOnly` 와 `reorder` 가 좌표를 요구한다.
   앱에 위치 수집 기능을 추가하는 작업이 함께 필요하다
