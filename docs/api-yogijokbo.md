# 요기족보 API 명세 (초안)

**요기족보** — 사용자들이 자기 먹방 조합을 공유하고, 실시간 인기 조합을 보고,
마음에 들면 그대로 주문하는 커뮤니티 기능. (구 '먹슐랭')

작성: 윤수 (프론트엔드) · 상태: **초안, 논의용**
근거: Figma `수정됨` 섹션의 먹슐랭 플로우 4화면 + 3차 회의록

> 프론트에서 화면을 보고 역산한 초안이다. 실제 스키마·경로는 백엔드에서 확정해 주시면 맞추겠다.
> 노션 「API 명세서」 페이지의 데이터베이스 컬럼과 같은 형식으로 정리했다.
> (상태 / 우선순위 / 권한 / Method / 기능 / End Point / Request / Request Example / Response / 비고)

---

## 요약

| 우선순위 | Method | 기능 | End Point | 권한 |
|---|---|---|---|---|
| 높음 | `GET` | 요기족보 홈 — 조합 목록 | `/api/v1/posts` | 비로그인 허용 |
| 높음 | `GET` | 조합 상세 | `/api/v1/posts/{postId}` | 비로그인 허용 |
| 높음 | `POST` | 나도 주문하기 | `/api/v1/posts/{postId}/reorder` | 로그인 |
| 보통 | `POST` | 조합 공유 (작성) | `/api/v1/posts` | 로그인 |
| 보통 | `POST` | 이미지 업로드 | `/api/v1/uploads/images` | 로그인 |
| 보통 | `POST` | 좋아요 | `/api/v1/posts/{postId}/likes` | 로그인 |
| 보통 | `DELETE` | 좋아요 취소 | `/api/v1/posts/{postId}/likes` | 로그인 |
| 낮음 | `GET` | 댓글 목록 | `/api/v1/posts/{postId}/comments` | 비로그인 허용 |
| 낮음 | `POST` | 댓글 작성 | `/api/v1/posts/{postId}/comments` | 로그인 |

**우선순위 근거** — 높음 3개만 있어도 *"인기 조합 보고 → 그대로 주문"* 시연이 성립한다.

---

## 1. 요기족보 홈 — 조합 목록

| 컬럼 | 값 |
|---|---|
| **Method** | `GET` |
| **기능** | 요기족보 홈. 실시간 인기/최신 조합 목록 |
| **End Point** | `/api/v1/posts` |
| **권한** | 비로그인 허용 |
| **우선순위** | 높음 |

**Request** (Query)

| 파라미터 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `sort` | enum | | `LATEST` \| `POPULAR` (기본 `POPULAR`) |
| `orderableOnly` | bool | | "내 위치에서 가능한 조합만" 체크박스 |
| `lat` `lng` | number | 조건부 | `orderableOnly=true` 일 때 필수 |
| `cursor` | string | | 페이지네이션 커서 |
| `size` | int | | 기본 20 |

**Request Example**

```
GET /api/v1/posts?sort=POPULAR&orderableOnly=true&lat=37.5445&lng=127.0557&size=20
```

**Response**

```jsonc
{
  "items": [
    {
      "id": "post_01H8X",
      "title": "떵개 추천 두찜 로제 닭발",
      "thumbnailUrl": "https://cdn.../1.jpg",
      "storeName": "두찜-잠실새내점",
      "likeCount": 12,
      "commentCount": 4,
      "author": { "nickname": "배고픈 요기요", "profileImageUrl": "https://..." },
      "orderableHere": true,
      "createdAt": "2026-07-07T12:30:00+09:00"
    }
  ],
  "nextCursor": "eyJpZCI6..."
}
```

**비고**
목록 화면에는 제목·썸네일·좋아요 수만 보이므로 조합 전체(`combo`)는 내리지 않는다.
**"실시간 인기" 산정 기준 확정 필요** — 누적 좋아요 / 최근 24h / 조회수 반영 중 무엇인지.

---

## 2. 조합 상세

| 컬럼 | 값 |
|---|---|
| **Method** | `GET` |
| **기능** | 조합 게시글 상세 |
| **End Point** | `/api/v1/posts/{postId}` |
| **권한** | 비로그인 허용 |
| **우선순위** | 높음 |

**Request** — Path `postId`

**Request Example**

```
GET /api/v1/posts/post_01H8X
```

**Response**

```jsonc
{
  "id": "post_01H8X",
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "진짜 미쳤어요 꼭 드셔보세요",
  "imageUrls": ["https://cdn.../1.jpg"],
  "author": { "id": "user_01H", "nickname": "배고픈 요기요", "profileImageUrl": "https://..." },
  "combo": {
    "store": {
      "id": "store_123", "name": "두찜-잠실새내점",
      "imageUrl": "https://...", "rating": 4.2, "reviewCount": 312
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
    "payableTotal": 28500
  },
  "likeCount": 12,
  "likedByMe": false,
  "commentCount": 4,
  "createdAt": "2026-07-07T12:30:00+09:00"
}
```

**비고**
**`combo` 는 작성 시점 스냅샷으로 저장한다.** 매장이 가격을 올리거나 메뉴를 바꿔도
예전 게시글은 그때 모습 그대로 보여야 한다. 현재 주문 가능 여부는 9번에서 확인한다.
`payableTotal` 이 Figma 조합 상세의 "결제 금액"에 해당한다.

---

## 3. 조합 공유 (작성)

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 내 조합을 요기족보에 공유 |
| **End Point** | `/api/v1/posts` |
| **권한** | 로그인 |
| **우선순위** | 보통 |

**Request** (Body)

| 필드 | 타입 | 제약 |
|---|---|---|
| `title` | string | 최대 20자 (Figma `0/20`) |
| `body` | string | 최대 400자 (Figma `0/400`) |
| `imageUrls` | string[] | 4번으로 먼저 업로드한 URL |
| `orderId` | string | 주문 이력에서 조합을 가져올 때 |

**Request Example**

```jsonc
{
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "진짜 미쳤어요",
  "imageUrls": ["https://cdn.../1.jpg"],
  "orderId": "order_789"
}
```

**Response** — 생성된 Post 전체 (2번과 동일 구조)

**비고**
Figma 의 "주문한 메뉴" 영역이 주문 이력에서 고르는 UI 로 보여 `orderId` 로 잡았다.
서버가 주문 이력에서 조합 스냅샷을 만드는 쪽이 깔끔하다.
**주문 이력 없이도 공유 가능해야 하는지 확인 필요** — 필요하면 `combo` 객체를 직접 받는 형태도 추가.

---

## 4. 이미지 업로드

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 게시글 첨부 사진 업로드 |
| **End Point** | `/api/v1/uploads/images` |
| **권한** | 로그인 |
| **우선순위** | 보통 |

**Request** — `multipart/form-data`, 필드 `file` (또는 presigned URL 발급 방식)

**Request Example**

```
POST /api/v1/uploads/images
Content-Type: multipart/form-data

file: <binary>
```

**Response**

```jsonc
{ "url": "https://cdn.../abc.jpg" }
```

**비고**
프론트는 **최종 URL 문자열만** 필요하다. 멀티파트/presigned 중 서버 편한 쪽으로.
**장수 제한·용량 제한·허용 포맷 확정 필요.**

---

## 5. 좋아요

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 조합 좋아요 |
| **End Point** | `/api/v1/posts/{postId}/likes` |
| **권한** | 로그인 |
| **우선순위** | 보통 |

**Request** — Path `postId` (body 없음)

**Request Example**

```
POST /api/v1/posts/post_01H8X/likes
```

**Response**

```jsonc
{ "likeCount": 13, "likedByMe": true }
```

**비고**
낙관적 업데이트를 위해 **변경 후 카운트를 응답에 포함**해 주면 좋다.
이미 좋아요한 상태에서 다시 호출해도 에러 없이 현재 상태를 반환하는 편이 낫다(멱등).

---

## 6. 좋아요 취소

| 컬럼 | 값 |
|---|---|
| **Method** | `DELETE` |
| **기능** | 좋아요 취소 |
| **End Point** | `/api/v1/posts/{postId}/likes` |
| **권한** | 로그인 |
| **우선순위** | 보통 |

**Request** — Path `postId`

**Request Example**

```
DELETE /api/v1/posts/post_01H8X/likes
```

**Response**

```jsonc
{ "likeCount": 12, "likedByMe": false }
```

**비고** — 5번과 응답 형태 동일.

---

## 7. 댓글 목록

| 컬럼 | 값 |
|---|---|
| **Method** | `GET` |
| **기능** | 조합 댓글 목록 |
| **End Point** | `/api/v1/posts/{postId}/comments` |
| **권한** | 비로그인 허용 |
| **우선순위** | 낮음 |

**Request** — Path `postId` / Query `cursor`, `size`

**Request Example**

```
GET /api/v1/posts/post_01H8X/comments?size=20
```

**Response**

```jsonc
{
  "items": [
    {
      "id": "comment_01H",
      "author": { "id": "user_02", "nickname": "배고픈 요기요", "profileImageUrl": "https://..." },
      "body": "저도 시켜봤어요",
      "createdAt": "2026-07-07T12:35:00+09:00"
    }
  ],
  "nextCursor": null
}
```

**비고**
Figma 에는 1단계 댓글만 보인다. **대댓글·수정·삭제가 이번 범위에 포함되는지 확인 필요.**

---

## 8. 댓글 작성

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 댓글 작성 |
| **End Point** | `/api/v1/posts/{postId}/comments` |
| **권한** | 로그인 |
| **우선순위** | 낮음 |

**Request** — Path `postId` / Body `body`: string

**Request Example**

```jsonc
{ "body": "저도 시켜봤어요" }
```

**Response** — 생성된 Comment 1건 (7번 `items` 원소와 동일 구조)

**비고** — 글자수 제한 확정 필요.

---

## 9. 나도 주문하기

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 남의 조합을 내 장바구니로 복사 |
| **End Point** | `/api/v1/posts/{postId}/reorder` |
| **권한** | 로그인 |
| **우선순위** | 높음 |

**Request** — Path `postId` / Body `lat`, `lng`

**Request Example**

```jsonc
{ "lat": 37.5445, "lng": 127.0557 }
```

**Response**

```jsonc
{
  "orderable": true,
  "combo": { /* 현재 가격·재고로 다시 계산한 Combo. 2번의 combo 와 같은 구조 */ },
  "unavailableItems": [
    { "menuId": "menu_456", "name": "[사이드] 치즈볼", "reason": "SOLD_OUT" }
  ]
}
```

**비고**
게시글의 조합은 스냅샷이라 **지금도 주문 가능한지 알 수 없다.** 이 API 가 현재 시점으로 재확인한다.
`reason` enum 후보: `SOLD_OUT` / `DISCONTINUED` / `OUT_OF_DELIVERY_AREA`
**사용자 위치에 배달 불가한 매장이면 같은 브랜드 다른 지점을 제안할지 확인 필요.**

---

## 공통 규칙 — 확정 부탁드립니다

| 항목 | 제안 |
|---|---|
| **인증** | `Authorization: Bearer <token>`. 목록·상세·댓글목록은 비로그인 허용, 나머지는 로그인 필요 |
| **에러 형식** | `{ "code": "POST_NOT_FOUND", "message": "..." }` + 적절한 HTTP 상태코드 |
| **날짜** | ISO 8601 + 타임존 (`2026-07-07T12:30:00+09:00`) |
| **페이지네이션** | **커서 방식.** 실시간 피드라 오프셋은 중복·누락이 생긴다 |
| **빈 값** | 배열은 `[]`, 객체는 `null`. **키 자체를 빼지 않기** (클라이언트가 터진다) |
| **이미지 URL** | 항상 절대 경로 |
| **enum** | 대문자 스네이크. `LATEST`, `POPULAR`, `SOLD_OUT` |

---

## 미해결 항목

1. **"실시간 인기" 산정 기준** — 누적 좋아요 / 최근 24h / 조회수 반영
2. **주문 이력 없이도 조합 공유 가능한가** — 가능하다면 `combo` 직접 전달 형태 추가 필요
3. **찜 연동** — 3차 회의록의 *"조합된 메뉴는 요기요 찜에 저장"* 을 이 API 에 넣을지 별도 찜 API 로 뺄지
4. **신고·차단** — 커뮤니티라 필요할 수 있으나 이번 범위에서는 제외 제안
5. ~~**위치** — `orderableOnly`(1번)와 `reorder`(9번)가 좌표를 요구한다.
   앱에 위치 수집 기능이 아직 없어 별도 작업이 필요하다.~~
   → **앱 구현 완료.** 아래 "위치 수집" 참고. 서버 쪽 확인 1건 남았다.

---

## 위치 수집 — 앱이 하는 일과 서버에 부탁할 것

`geolocator` 로 좌표를 수집한다. 로그인 직후 1회 자동 수집하고, 좌표를 쓰는 화면에
도달했을 때 이미 준비돼 있게 한다.

앱이 보내는 형태 (`UserLocation.toJson`)

```jsonc
{ "lat": 37.5114, "lng": 127.0863 }              // GPS 로 얻은 경우
{ "lat": 0, "lng": 0, "address": "서울 송파구 잠실동 40-1" }  // 사용자가 직접 입력한 경우
```

**❓ 확인 부탁드립니다 — 주소 → 좌표 변환을 서버가 해 주실 수 있나요?**

권한을 거부하면 앱은 좌표를 알 수 없다. 이때 사용자에게 주소를 직접 입력받는데,
**앱은 그 주소를 좌표로 바꾸지 않고 문자열 그대로 보낸다.** 아무 좌표나 지어내면
엉뚱한 매장이 걸리기 때문이다. 그래서 이 경우 `lat`/`lng` 가 `0` 으로 온다.

- 서버가 `address` 로 좌표를 찾아 주시면 앱은 지금 구조 그대로 두면 된다.
- 서버가 못 하는 쪽이면 앱에 지오코딩을 붙여야 하니 알려 주세요.
- 반대 방향(좌표 → 주소)도 서버가 하는 것으로 가정했다. 그래서 GPS 로 얻은 위치에는
  `address` 키를 아예 싣지 않는다. 화면에 동네 이름을 보여줘야 하면 응답에 주소를
  담아 주시는 쪽이 좋겠다.

권한 거부는 정상 경로로 취급한다. 위치가 없어도 앱은 멈추지 않고,
`orderableOnly` 를 못 켜는 정도로만 기능이 줄어든다.
