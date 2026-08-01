# 요기족보 API 명세

**요기족보** — 사용자가 자기 먹방 조합을 공유하고, 실시간 인기 조합을 보고,
마음에 들면 그대로 주문하는 커뮤니티 기능.

---

## 공통 규칙

Users 명세와 동일한 규칙을 따른다.

| 항목 | 규칙 |
|---|---|
| **Base Path** | `v1/...` |
| **인증** | `Authorization: Bearer <accessToken>` |
| **권한** | `ALL` 비로그인 허용 · `USER` 로그인 필요 |
| **날짜** | ISO 8601 + 타임존 (`2026-07-07T12:30:00+09:00`) |
| **페이지네이션** | `page`, `size` 쿼리 · 응답에 `page`, `size`, `totalElements`, `hasNext` |
| **빈 값** | 배열 `[]`, 객체·미지정 `null`. 키를 생략하지 않는다 |
| **이미지 URL** | 절대 경로. OCI Object Storage |
| **enum** | 대문자 스네이크 (`LATEST`, `POPULAR`, `SOLD_OUT`, `YOUTUBE`) |
| **금액** | 원 단위 정수 |
| **본문 없는 응답** | `204 No Content` |

**에러 응답** — 코드는 도메인 약어 + 3자리 (Users 명세의 `U001`, `A002` 형식)

```json
{
  "code": "P001",
  "message": "게시글을 찾을 수 없습니다."
}
```

| 코드 | 상태 | 상황 |
|---|---|---|
| `P001` | 404 | 게시글 없음 |
| `P002` | 400 | `orderId` 와 `combo` 가 모두 없음 |
| `P003` | 403 | 본인 글이 아님 |
| `C001` | 404 | 댓글 없음 |

---

## 엔드포인트 요약

| 우선순위 | Method | 기능 | End Point | 권한 |
|---|---|---|---|---|
| 높음 | `GET` | 요기족보 홈 — 조합 목록 | `v1/posts` | ALL |
| 높음 | `GET` | 조합 게시글 상세 | `v1/posts/{postId}` | ALL |
| 높음 | `POST` | 남의 조합을 내 장바구니로 복사 | `v1/posts/{postId}/reorder` | USER |
| 보통 | `POST` | 내 조합을 요기족보에 공유 | `v1/posts` | USER |
| 보통 | `POST` | 게시글 첨부 사진 업로드 | `v1/uploads/images` | USER |
| 보통 | `POST` | 조합 좋아요 | `v1/posts/{postId}/likes` | USER |
| 보통 | `DELETE` | 좋아요 취소 | `v1/posts/{postId}/likes` | USER |
| 낮음 | `GET` | 조합 댓글 목록 | `v1/posts/{postId}/comments` | ALL |
| 낮음 | `POST` | 댓글 작성 | `v1/posts/{postId}/comments` | USER |

높음 3개(1·2·9번)만으로 *"인기 조합 보고 → 그대로 주문"* 플로우가 성립한다.

---

## 1. 요기족보 홈 — 조합 목록

`GET v1/posts` · 권한 `ALL` · 우선순위 높음

**Query Parameter**

| 파라미터 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `sort` | Enum | | `LATEST` \| `POPULAR` (기본 `POPULAR`) |
| `orderableOnly` | Boolean | | "내 위치에서 가능한 조합만" |
| `lat` | Double | 조건부 | `orderableOnly=true` 일 때 필수 |
| `lng` | Double | 조건부 | `orderableOnly=true` 일 때 필수 |
| `page` | Integer | | 0부터 시작. 기본 0 |
| `size` | Integer | | 기본 20 |

**Request**

```
GET v1/posts?sort=POPULAR&orderableOnly=true&lat=37.5445&lng=127.0557&page=0&size=20
```

**Response** `200 OK`

```json
{
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "떵개 추천 두찜 로제 닭발",
      "body": "분모자랑 치즈 꼭 추가하고 드세요\n맵찔이는 치즈 추가해서 먹어야 딱 적당히 매워요",
      "thumbnailUrl": "https://cdn.example.com/posts/1.jpg",
      "storeName": "두찜-잠실새내점",
      "author": {
        "id": "8f14e45f-ceea-467a-9e5f-1c1b1a2b3c4d",
        "nickname": "배고픈 요기요",
        "profileImageUrl": "https://cdn.example.com/users/1.jpg"
      },
      "source": {
        "platform": "YOUTUBE",
        "videoTitle": "Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가",
        "videoUrl": "https://www.youtube.com/watch?v=xxxx"
      },
      "likeCount": 12,
      "commentCount": 4,
      "orderableHere": true,
      "createdAt": "2026-07-07T12:30:00+09:00"
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 37,
  "hasNext": true
}
```

**비고**

- `v1/users/me/posts` 의 `posts[]` 원소와 동일 구조를 사용한다.
- 조합 전체(`combo`)는 목록에 내리지 않는다. 상세(2번)에서 받는다.
- `body` 는 목록 카드의 2줄 미리보기에 쓴다.
- `source` 는 목록 카드의 출처 영상 배지에 쓴다.
- `orderableHere` 는 `orderableOnly` 를 끈 상태에서도 채워 주면 카드에 표시할 수 있다.
- `profileImageUrl` 이 없으면 `null`.

---

## 2. 조합 게시글 상세

`GET v1/posts/{postId}` · 권한 `ALL` · 우선순위 높음

**Path Variable** — `postId : UUID`

**Request**

```
GET v1/posts/550e8400-e29b-41d4-a716-446655440000
```

**Response** `200 OK`

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "분모자랑 치즈 꼭 추가하고 드세요\n맵찔이는 치즈 추가해서 먹어야 딱 적당히 매워서 너무 맛있어요\n집에 있는 재료로 주먹밥 만들어서 같이 먹는 거 추천",
  "imageUrls": [
    "https://cdn.example.com/posts/1.jpg",
    "https://cdn.example.com/posts/2.jpg"
  ],
  "author": {
    "id": "8f14e45f-ceea-467a-9e5f-1c1b1a2b3c4d",
    "nickname": "배고픈 요기요",
    "profileImageUrl": "https://cdn.example.com/users/1.jpg"
  },
  "source": {
    "platform": "YOUTUBE",
    "videoTitle": "Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가",
    "videoUrl": "https://www.youtube.com/watch?v=xxxx"
  },
  "combo": {
    "store": {
      "id": "b1c2d3e4-f5a6-47b8-9c0d-1e2f3a4b5c6d",
      "name": "두찜-잠실새내점",
      "imageUrl": "https://cdn.example.com/stores/dujjim.jpg",
      "rating": 4.2,
      "reviewCount": 312
    },
    "items": [
      {
        "menuId": "c2d3e4f5-a6b7-48c9-8d0e-2f3a4b5c6d7e",
        "name": "[원조 K 로제] 로제 닭발",
        "options": ["순살", "보통맛", "분모자로 변경", "치즈몽땅 추가", "[리뷰 이벤트] 납작당면 추가"],
        "description": "",
        "unitPrice": 16000,
        "quantity": 1,
        "imageUrl": "https://cdn.example.com/menus/rose-dakbal.jpg"
      },
      {
        "menuId": "d3e4f5a6-b7c8-49d0-8e1f-3a4b5c6d7e8f",
        "name": "[사이드] 치즈볼",
        "options": [],
        "description": "모짜렐라 치즈 가득한 쫀득 치즈볼",
        "unitPrice": 2000,
        "quantity": 2,
        "imageUrl": "https://cdn.example.com/menus/cheese-ball.jpg"
      }
    ],
    "itemsTotal": 20000,
    "deliveryFee": 3000,
    "payableTotal": 23000
  },
  "likeCount": 12,
  "likedByMe": false,
  "commentCount": 4,
  "createdAt": "2026-07-07T12:30:00+09:00"
}
```

**비고**

- `combo` 는 **작성 시점 스냅샷**이다. 매장이 가격·메뉴를 바꿔도 예전 게시글은 그때 값 그대로
  보여야 한다. 현재 주문 가능 여부는 9번에서 확인한다.
- 금액 관계: `itemsTotal`(20,000) + `deliveryFee`(3,000) = `payableTotal`(23,000).
  `payableTotal` 이 화면의 "결제 금액"이다.
- `options` 는 배열로 유지한다. 화면 표시용 문자열 결합은 클라이언트가 한다.
- `options` 가 없으면 `[]`, `description` 이 없으면 `""`.
- `source.platform` — `INSTAGRAM` \| `YOUTUBE` \| `OTHER`

---

## 3. 내 조합을 요기족보에 공유

`POST v1/posts` · 권한 `USER` · 우선순위 보통

**Request Body**

| 필드 | 타입 | 제약 |
|---|---|---|
| `title` | String | 최대 20자 |
| `body` | String | 최대 400자 |
| `imageUrls` | String[] | 5번으로 먼저 업로드한 URL |
| `source` | Object | 출처 영상. 없으면 `null` |
| `orderId` | UUID | 주문 이력에서 조합을 가져올 때 |
| `combo` | Object | 주문 이력 없이 공유할 때. 2번 `combo` 와 동일 구조 |

`orderId` 와 `combo` 중 하나는 반드시 있어야 한다.

**Request**

```json
{
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "진짜 미쳤어요 꼭 드셔보세요",
  "imageUrls": ["https://cdn.example.com/posts/1.jpg"],
  "source": {
    "platform": "YOUTUBE",
    "videoTitle": "Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가",
    "videoUrl": "https://www.youtube.com/watch?v=xxxx"
  },
  "orderId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response** `201 CREATED` — 2번과 동일 구조

```json
{
  "id": "9b2f4c1a-3d5e-4f60-8a71-b2c3d4e5f6a7",
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "진짜 미쳤어요 꼭 드셔보세요",
  "imageUrls": ["https://cdn.example.com/posts/1.jpg"],
  "author": {
    "id": "8f14e45f-ceea-467a-9e5f-1c1b1a2b3c4d",
    "nickname": "배고픈 요기요",
    "profileImageUrl": "https://cdn.example.com/users/1.jpg"
  },
  "source": {
    "platform": "YOUTUBE",
    "videoTitle": "Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가",
    "videoUrl": "https://www.youtube.com/watch?v=xxxx"
  },
  "combo": {
    "store": {
      "id": "b1c2d3e4-f5a6-47b8-9c0d-1e2f3a4b5c6d",
      "name": "두찜-잠실새내점",
      "imageUrl": "https://cdn.example.com/stores/dujjim.jpg",
      "rating": 4.2,
      "reviewCount": 312
    },
    "items": [
      {
        "menuId": "c2d3e4f5-a6b7-48c9-8d0e-2f3a4b5c6d7e",
        "name": "[원조 K 로제] 로제 닭발",
        "options": ["순살", "보통맛", "치즈몽땅 추가"],
        "description": "",
        "unitPrice": 16000,
        "quantity": 1,
        "imageUrl": "https://cdn.example.com/menus/rose-dakbal.jpg"
      }
    ],
    "itemsTotal": 16000,
    "deliveryFee": 3000,
    "payableTotal": 19000
  },
  "likeCount": 0,
  "likedByMe": false,
  "commentCount": 0,
  "createdAt": "2026-07-30T14:20:00+09:00"
}
```

**비고**

- 클라이언트는 주문 전 단계(조합 분석 결과)에서도 공유에 진입한다. 이 경로에는 `orderId` 가
  없으므로 `combo` 를 직접 싣는다.
- `source` 는 클라이언트가 알고 서버는 모르는 값이라 요청에 포함한다.

---

## 4. 게시글 첨부 사진 업로드

`POST v1/uploads/images` · 권한 `USER` · 우선순위 보통

**Request** — `multipart/form-data`

```
POST v1/uploads/images
Content-Type: multipart/form-data

file: <binary>
```

**Response** `201 CREATED`

```json
{
  "url": "https://cdn.example.com/posts/abc.jpg"
}
```

**비고**

- 클라이언트는 최종 URL 문자열만 사용한다. 멀티파트 / presigned URL 중 서버 편한 방식으로.
- 장수·용량·허용 포맷 제한 확정 필요.

---

## 5. 조합 좋아요

`POST v1/posts/{postId}/likes` · 권한 `USER` · 우선순위 보통

**Path Variable** — `postId : UUID` (Body 없음)

**Request**

```
POST v1/posts/550e8400-e29b-41d4-a716-446655440000/likes
```

**Response** `200 OK`

```json
{
  "likeCount": 13,
  "likedByMe": true
}
```

**비고**

- 변경 후 카운트를 응답에 포함한다. 클라이언트가 낙관적 업데이트 후 응답 값으로 덮어쓴다.
- 이미 좋아요한 상태에서 재호출해도 에러 없이 현재 상태를 반환한다(멱등).

---

## 6. 좋아요 취소

`DELETE v1/posts/{postId}/likes` · 권한 `USER` · 우선순위 보통

**Path Variable** — `postId : UUID`

**Request**

```
DELETE v1/posts/550e8400-e29b-41d4-a716-446655440000/likes
```

**Response** `200 OK`

```json
{
  "likeCount": 12,
  "likedByMe": false
}
```

**비고** — 5번과 응답 형태 동일. 멱등.

---

## 7. 조합 댓글 목록

`GET v1/posts/{postId}/comments` · 권한 `ALL` · 우선순위 낮음

**Path Variable** — `postId : UUID`

**Query Parameter** — `page : Integer` (기본 0), `size : Integer` (기본 20)

**Request**

```
GET v1/posts/550e8400-e29b-41d4-a716-446655440000/comments?page=0&size=20
```

**Response** `200 OK`

```json
{
  "items": [
    {
      "id": "e4f5a6b7-c8d9-40e1-9f2a-4b5c6d7e8f90",
      "author": {
        "id": "1a2b3c4d-5e6f-4708-9a1b-2c3d4e5f6a7b",
        "nickname": "닭발러버",
        "profileImageUrl": "https://cdn.example.com/users/3.jpg"
      },
      "body": "분모자 진짜 필수인가요? 중국당면이 더 맛있을 것 같은데",
      "createdAt": "2026-07-07T13:02:00+09:00"
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 4,
  "hasNext": false
}
```

**비고**

- 1단계 댓글만 다룬다. 대댓글·수정·삭제 범위 포함 여부 확정 필요.
- `profileImageUrl` 이 없으면 `null`.

---

## 8. 댓글 작성

`POST v1/posts/{postId}/comments` · 권한 `USER` · 우선순위 낮음

**Path Variable** — `postId : UUID`

**Request Body**

```json
{
  "body": "저도 시켜봤어요"
}
```

**Response** `201 CREATED`

```json
{
  "id": "f5a6b7c8-d9e0-41f2-8a3b-5c6d7e8f9012",
  "author": {
    "id": "8f14e45f-ceea-467a-9e5f-1c1b1a2b3c4d",
    "nickname": "배고픈 요기요",
    "profileImageUrl": "https://cdn.example.com/users/1.jpg"
  },
  "body": "저도 시켜봤어요",
  "createdAt": "2026-07-30T14:25:00+09:00",
  "commentCount": 5
}
```

**비고**

- 7번 `items` 원소와 같은 구조 + `commentCount`.
- `commentCount` 는 변경 후 게시글의 댓글 총수. 없으면 클라이언트가 로컬로 세게 되어
  동시에 작성된 댓글이 반영되지 않는다.
- 본문 글자수 제한 확정 필요.

---

## 9. 남의 조합을 내 장바구니로 복사 (나도 주문하기)

`POST v1/posts/{postId}/reorder` · 권한 `USER` · 우선순위 높음

**Path Variable** — `postId : UUID`

**Request Body**

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `lat` | Double | ✓ | 사용자 위치 위도 |
| `lng` | Double | ✓ | 사용자 위치 경도 |
| `addressId` | Long | | 등록 주소를 선택한 경우. `v1/users/me/addresses` 의 id |

**Request**

```json
{
  "lat": 37.5445,
  "lng": 127.0557
}
```

**Response** `200 OK` — 주문 가능

```json
{
  "orderable": true,
  "combo": {
    "store": {
      "id": "b1c2d3e4-f5a6-47b8-9c0d-1e2f3a4b5c6d",
      "name": "두찜-잠실새내점",
      "imageUrl": "https://cdn.example.com/stores/dujjim.jpg",
      "rating": 4.2,
      "reviewCount": 312
    },
    "items": [
      {
        "menuId": "c2d3e4f5-a6b7-48c9-8d0e-2f3a4b5c6d7e",
        "name": "[원조 K 로제] 로제 닭발",
        "options": ["순살", "보통맛", "치즈몽땅 추가"],
        "description": "",
        "unitPrice": 16000,
        "quantity": 1,
        "imageUrl": "https://cdn.example.com/menus/rose-dakbal.jpg"
      }
    ],
    "itemsTotal": 16000,
    "deliveryFee": 3000,
    "payableTotal": 19000
  },
  "unavailableItems": [
    {
      "menuId": "d3e4f5a6-b7c8-49d0-8e1f-3a4b5c6d7e8f",
      "name": "[사이드] 치즈볼",
      "reason": "SOLD_OUT"
    }
  ]
}
```

**Response** `200 OK` — 주문 불가 (배달 권역 밖)

```json
{
  "orderable": false,
  "combo": null,
  "unavailableItems": [
    {
      "menuId": "c2d3e4f5-a6b7-48c9-8d0e-2f3a4b5c6d7e",
      "name": "[원조 K 로제] 로제 닭발",
      "reason": "OUT_OF_DELIVERY_AREA"
    }
  ]
}
```

**비고**

- 게시글의 `combo` 는 스냅샷이므로 현재 주문 가능 여부를 알 수 없다. 이 API 가 현재 시점
  가격·재고로 재계산한다. 응답 `combo` 는 2번과 동일 구조.
- `reason` — `SOLD_OUT` \| `DISCONTINUED` \| `OUT_OF_DELIVERY_AREA`
- `unavailableItems` 가 없으면 `[]`. `orderable: false` 면 `combo` 는 `null`.
- 배달 불가 시 같은 브랜드 다른 지점 제안 여부 확정 필요.

---

## 위치 — 좌표 확보 경로

1번의 `orderableOnly` 와 9번의 `reorder` 가 좌표를 요구한다. 좌표는 두 경로로 얻는다.

**A. GPS** — 로그인 직후 1회 수집

```json
{
  "lat": 37.5445,
  "lng": 127.0557
}
```

**B. 등록 주소** — 위치 권한을 거부했거나 다른 주소로 주문할 때

`v1/users/me/addresses` 에 등록된 주소의 `latitude` / `longitude` 를 그대로 쓴다.
좌표는 주소 등록 시 카카오 주소 검색이 채워 준다.

```json
{
  "lat": 37.5125,
  "lng": 127.1025,
  "addressId": 3
}
```

**비고**

- 클라이언트는 주소 문자열을 좌표로 변환하지 않는다. 임의 좌표를 채우면 잘못된 매장이
  매칭된다. 좌표가 필요한 요청은 GPS 또는 등록 주소 중 하나에서 좌표를 확보한 뒤 보낸다.
- 위치 권한 거부는 정상 경로다. 등록 주소가 하나도 없고 GPS 도 없으면 `orderableOnly`
  필터만 사용할 수 없다.

---

## 연관 API (Users 명세)

요기족보 화면이 함께 호출하는 엔드포인트.

| End Point | 용도 |
|---|---|
| `GET v1/users/me/posts` | 마이페이지 — 내가 쓴 요기족보 글. `posts[]` 는 1번 `items[]` 와 동일 구조 |
| `GET v1/users/me/orders` | 족보 작성 진입점. `isPostedToJokbo` 로 이미 공유한 주문을 구분한다 |
| `GET v1/users/me/addresses` | 좌표 확보 경로 B |
| `GET v1/users/me/preferences` | 조건 선택 시트 기본값 |
| `POST v1/uploads/images` | 게시글 첨부 사진 (본 문서 4번) |

---

## 확정 필요 항목

### Users 명세와 맞춰야 하는 것

| # | 항목 | 관련 |
|---|---|---|
| 1 | **`spicyLevel` 값 범위 불일치.** `v1/users/me/preferences` 는 `MILD` / `MEDIUM` / `HOT` 3단계, 조합 분석 추출 스키마는 `NONE` / `MILD` / `MEDIUM` / `HOT` / `EXTREME` 5단계. 3단계로 통일하거나 매핑 규칙 확정 | preferences |
| 2 | **`healthyPleasureDefault` 필드명.** 해당 모드 명칭이 '헬시플레저' → '비건모드' 로 변경됨(3차 회의). 필드명을 `veganModeDefault` 로 바꿀지 유지할지 | preferences |
| 3 | **`sourceVideoTitle` 위치.** `v1/users/me/orders` 는 주문에 `sourceVideoTitle` 을 갖는다. 요기족보 게시글도 같은 정보가 필요하므로 `source` 객체로 통일할지, 주문에서 승계할지 | orders · 1·2·3번 |
| 4 | **게시글 식별자 타입.** 본 문서는 `postId : UUID`, Users 명세의 주소는 `addressId : Long`. 도메인별로 달라도 되는지 | 전체 |

### 요기족보 자체 항목

| # | 항목 | 관련 |
|---|---|---|
| 5 | "실시간 인기" 산정 기준 — 누적 좋아요 / 최근 24h / 조회수 반영 | 1번 |
| 6 | `source` 필드 추가 가능 여부 (목록·상세 응답, 작성 요청) | 1·2·3번 |
| 7 | 목록 응답에 `body`, `author.id` 포함 가능 여부 | 1번 |
| 8 | 주문 이력 없이 공유 — `combo` 직접 전달 허용 여부. 조합 분석 결과에서 바로 공유하는 경로가 있다 | 3번 |
| 9 | 댓글 작성 응답에 `commentCount` 포함 가능 여부 | 8번 |
| 10 | 이미지 업로드 제한 — 장수·용량·허용 포맷 | 4번 |
| 11 | 댓글 대댓글·수정·삭제 범위 포함 여부 | 7번 |
| 12 | 배달 불가 시 같은 브랜드 다른 지점 제안 여부 | 9번 |
| 13 | 찜 연동 — `v1/users/me/bookmarks` 가 P2 로드맵으로 이관됨. 요기족보 조합 찜을 이번 범위에 포함할지 | bookmarks |
