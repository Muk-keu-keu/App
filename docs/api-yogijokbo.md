# 요기족보 API 명세

**요기족보** — 사용자들이 자기 먹방 조합을 공유하고, 실시간 인기 조합을 보고,
마음에 들면 그대로 주문하는 커뮤니티 기능. (구 '먹슐랭')

작성: 윤수 (프론트엔드) · 노션 「API 명세서 / 먹방요기」 표와 짝을 맞춘 문서다.

> **이번 개정에서 바뀐 것**
> 1. **Response 를 전부 실제 JSON 으로 바꿨다.** `- field : Type` 나열식은 배열·중첩
>    객체의 경계가 드러나지 않아 양쪽이 다르게 읽을 수 있다. 특히 `combo.items[]` 처럼
>    2단 중첩이 있는 곳에서 그렇다. JSON 으로 두면 그대로 붙여 목업·테스트에 쓸 수 있다.
> 2. 예시 값을 **앱 목업 데이터와 동일하게** 맞췄다(두찜-잠실새내점 로제 닭발 조합).
>    양쪽 예시가 같은 값이면 연동할 때 눈으로 바로 대조된다.
> 3. 엔드포인트 표기를 노션 표의 `v1/...` 에 맞췄다. **`/api` 접두사가 붙는지 확인 부탁드립니다.**
> 4. 앱 구현 과정에서 나온 확인 사항을 각 항목 비고에 넣었다. `❓` 표시된 곳만 봐 주시면 된다.

---

## 요약

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

**우선순위 근거** — 높음 3개만 있어도 *"인기 조합 보고 → 그대로 주문"* 시연이 성립한다.

---

## 1. 요기족보 홈 — 조합 목록

| 컬럼 | 값 |
|---|---|
| **Method** | `GET` |
| **기능** | 요기족보 홈. 실시간 인기/최신 조합 목록 |
| **End Point** | `v1/posts` |
| **권한** | ALL |
| **우선순위** | 높음 |

**Request** — Query Parameter

| 파라미터 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `sort` | Enum | | `LATEST` \| `POPULAR` (기본 `POPULAR`) |
| `orderableOnly` | Boolean | | "내 위치에서 가능한 조합만" 체크박스 |
| `lat` | Double | 조건부 | `orderableOnly=true` 일 때 필수 |
| `lng` | Double | 조건부 | `orderableOnly=true` 일 때 필수 |
| `cursor` | String | | 페이지네이션 커서 |
| `size` | Integer | | 기본 20 |

**Request Example**

```
GET v1/posts?sort=POPULAR&orderableOnly=true&lat=37.5445&lng=127.0557&size=20
```

**Response** — `200 OK`

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
  "nextCursor": "eyJpZCI6IjU1MGU4NDAwIn0="
}
```

**비고**

목록 화면에는 제목·썸네일·좋아요 수만 보이므로 조합 전체(`combo`)는 내리지 않는다.

**❓ `body` 와 `source` 를 목록에도 넣어 주실 수 있나요?** 노션 표의 목록 Response 에는
둘이 없는데, Figma 목록 화면에는 **본문 2줄 미리보기와 유튜브 출처 배지가 그려져 있다.**
없으면 목록에서 상세를 한 번 더 호출해야 해서 스크롤마다 요청이 늘어난다.

**❓ `author.id` 도 목록에 필요합니다.** 노션 표에는 `author.nickname` 과
`author.profileImageUrl` 만 있는데, 작성자 프로필로 이동하거나 내 글을 구분하려면 id 가 필요하다.

**"실시간 인기" 산정 기준 확정 필요** — 누적 좋아요 / 최근 24h / 조회수 반영 중 무엇인지.

`nextCursor` 는 다음 페이지가 없으면 `null` 로 주세요.

---

## 2. 조합 게시글 상세

| 컬럼 | 값 |
|---|---|
| **Method** | `GET` |
| **기능** | 조합 게시글 상세 |
| **End Point** | `v1/posts/{postId}` |
| **권한** | ALL |
| **우선순위** | 높음 |

**Request** — Path Variable `postId : UUID`

**Request Example**

```
GET v1/posts/550e8400-e29b-41d4-a716-446655440000
```

**Response** — `200 OK`

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

**`combo` 는 작성 시점 스냅샷으로 저장한다.** 매장이 가격을 올리거나 메뉴를 바꿔도
예전 게시글은 그때 모습 그대로 보여야 한다. 현재 주문 가능 여부는 9번에서 확인한다.
앱도 이 규칙에 맞춰 구현했다 — 주문 화면은 스냅샷의 **복사본**을 고치고 게시글은 건드리지 않는다.

`payableTotal` 이 Figma 조합 상세의 "결제 금액"에 해당한다.
위 예시 금액이 Figma 주문하기 화면의 값과 같다 — 주문 20,000 + 배달비 3,000 = 결제 23,000.

**❓ `source`(출처 영상) 필드 추가 부탁드립니다.** 노션 표의 Response 에 없는데
Figma 상세 화면에 **유튜브 배지가 있다.** 이 서비스는 "영상에서 본 조합"을 다루므로
출처 링크가 빠지면 화면을 그릴 수 없다. `platform` 은 `INSTAGRAM` \| `YOUTUBE` \| `OTHER`
대문자 enum 으로 제안한다(앱은 이미 이 값으로 다룬다).

`options` 는 값이 없어도 `[]` 로, `description` 은 `""` 로 주세요. 키를 빼면 클라이언트가 터진다.

`options` 는 **배열로 주시면 됩니다.** 앱 내부 모델은 화면에 한 줄로 보여주려고
`"순살, 보통맛, 치즈몽땅 추가"` 처럼 이어붙인 문자열로 들고 있는데, 그 이어붙이기는
앱이 한다. 서버가 미리 합쳐 보내면 앱이 다시 쪼갤 수 없어 손해다.

---

## 3. 내 조합을 요기족보에 공유

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 내 조합을 요기족보에 공유 |
| **End Point** | `v1/posts` |
| **권한** | USER |
| **우선순위** | 보통 |

**Request** — Body

| 필드 | 타입 | 제약 |
|---|---|---|
| `title` | String | 최대 20자 (Figma `0/20`) |
| `body` | String | 최대 400자 (Figma `0/400`) |
| `imageUrls` | String[] | 5번으로 먼저 업로드한 URL |
| `orderId` | UUID | 주문 이력에서 조합을 가져올 때 |

> 노션 표에 Request Body 블록이 **두 번 붙어** 있다. 같은 내용이라 한 번으로 정리했다.

**Request Example**

```json
{
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "진짜 미쳤어요 꼭 드셔보세요",
  "imageUrls": ["https://cdn.example.com/posts/1.jpg"],
  "orderId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response** — `201 CREATED` (2번과 동일 구조)

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

Figma 의 "주문한 메뉴" 영역이 주문 이력에서 고르는 UI 로 보여 `orderId` 로 잡았다.
서버가 주문 이력에서 조합 스냅샷을 만드는 쪽이 깔끔하다.

**❓ 주문 이력 없이도 공유 가능해야 하나요?** 앱은 지금 **분석 결과 화면에서 바로 공유**로
들어간다(주문 전 단계다). 이 경로에서는 `orderId` 가 없어서 조합을 직접 실어 보내야 한다.
`orderId` 와 `combo` 중 하나만 오면 되는 형태(둘 중 하나 필수)로 열어 주시면 좋겠다.

**❓ `source` 를 Request 에도 받아 주세요.** 어떤 영상에서 온 조합인지는 앱이 알고 있고
(분석할 때 쓴 링크를 그대로 들고 있다) 서버는 모른다. 요청에 실어 보내야 저장된다.

---

## 4. 게시글 첨부 사진 업로드

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 게시글 첨부 사진 업로드 |
| **End Point** | `v1/uploads/images` |
| **권한** | USER |
| **우선순위** | 보통 |

**Request** — `multipart/form-data`, 필드 `file : File`

**Request Example**

```
POST v1/uploads/images
Content-Type: multipart/form-data

file: <binary>
```

**Response** — `201 CREATED`

```json
{
  "url": "https://cdn.example.com/posts/abc.jpg"
}
```

**비고**

프론트는 **최종 URL 문자열만** 필요하다. 멀티파트/presigned 중 서버 편한 쪽으로.
**장수 제한·용량 제한·허용 포맷 확정 필요.**

---

## 5. 조합 좋아요

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 조합 좋아요 |
| **End Point** | `v1/posts/{postId}/likes` |
| **권한** | USER |
| **우선순위** | 보통 |

**Request** — Path Variable `postId : UUID` (body 없음)

**Request Example**

```
POST v1/posts/550e8400-e29b-41d4-a716-446655440000/likes
```

**Response** — `200 OK`

```json
{
  "likeCount": 13,
  "likedByMe": true
}
```

**비고**

**변경 후 카운트를 응답에 포함**해 주셔서 낙관적 업데이트를 쓸 수 있다.
앱은 탭 즉시 화면을 바꾸고, 응답이 오면 그 값으로 덮어쓴다.

이미 좋아요한 상태에서 다시 호출해도 에러 없이 현재 상태를 반환하는 편이 낫다(멱등).

---

## 6. 좋아요 취소

| 컬럼 | 값 |
|---|---|
| **Method** | `DELETE` |
| **기능** | 좋아요 취소 |
| **End Point** | `v1/posts/{postId}/likes` |
| **권한** | USER |
| **우선순위** | 보통 |

**Request** — Path Variable `postId : UUID`

**Request Example**

```
DELETE v1/posts/550e8400-e29b-41d4-a716-446655440000/likes
```

**Response** — `200 OK`

```json
{
  "likeCount": 12,
  "likedByMe": false
}
```

**비고** — 5번과 응답 형태 동일.

---

## 7. 조합 댓글 목록

| 컬럼 | 값 |
|---|---|
| **Method** | `GET` |
| **기능** | 조합 댓글 목록 |
| **End Point** | `v1/posts/{postId}/comments` |
| **권한** | ALL |
| **우선순위** | 낮음 |

**Request** — Path Variable `postId : UUID` / Query `cursor : String`, `size : Integer` (기본 20)

**Request Example**

```
GET v1/posts/550e8400-e29b-41d4-a716-446655440000/comments?size=20
```

**Response** — `200 OK`

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
  "nextCursor": null
}
```

**비고**

Figma 에는 1단계 댓글만 보인다. **대댓글·수정·삭제가 이번 범위에 포함되는지 확인 필요.**

`profileImageUrl` 이 없는 사용자는 `null` 로 주세요. 앱은 그 경우 닉네임 첫 글자를
원에 넣어 그린다.

---

## 8. 댓글 작성

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 댓글 작성 |
| **End Point** | `v1/posts/{postId}/comments` |
| **권한** | USER |
| **우선순위** | 낮음 |

**Request** — Path Variable `postId : UUID` / Body `body : String`

**Request Example**

```json
{
  "body": "저도 시켜봤어요"
}
```

**Response** — `201 CREATED` (7번 `items` 원소와 동일 구조)

```json
{
  "id": "f5a6b7c8-d9e0-41f2-8a3b-5c6d7e8f9012",
  "author": {
    "id": "8f14e45f-ceea-467a-9e5f-1c1b1a2b3c4d",
    "nickname": "배고픈 요기요",
    "profileImageUrl": "https://cdn.example.com/users/1.jpg"
  },
  "body": "저도 시켜봤어요",
  "createdAt": "2026-07-30T14:25:00+09:00"
}
```

**비고**

**❓ 변경 후 `commentCount` 도 함께 주실 수 있나요?** 좋아요(5번)처럼 응답에 있으면
목록을 다시 불러오지 않고 화면 숫자를 갱신할 수 있다. 없으면 앱이 로컬에서 세는데,
다른 사람이 동시에 쓴 댓글이 반영되지 않아 숫자가 어긋난다.

글자수 제한 확정 필요.

---

## 9. 남의 조합을 내 장바구니로 복사 (나도 주문하기)

| 컬럼 | 값 |
|---|---|
| **Method** | `POST` |
| **기능** | 남의 조합을 내 장바구니로 복사 |
| **End Point** | `v1/posts/{postId}/reorder` |
| **권한** | USER |
| **우선순위** | 높음 |

**Request** — Path Variable `postId : UUID` / Body

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `lat` | Double | ✓ | 사용자 위치 위도 |
| `lng` | Double | ✓ | 사용자 위치 경도 |
| `address` | String | | 좌표를 얻지 못한 경우에만. 아래 비고 참고 |

**Request Example**

```json
{
  "lat": 37.5445,
  "lng": 127.0557
}
```

**Response** — `200 OK`

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

주문할 수 없는 경우 (배달 권역 밖)

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

게시글의 조합은 스냅샷이라 **지금도 주문 가능한지 알 수 없다.** 이 API 가 현재 시점으로
재확인한다. `combo` 는 현재 가격·재고로 다시 계산한 값이며 2번과 같은 구조다.

`reason` enum — `SOLD_OUT` / `DISCONTINUED` / `OUT_OF_DELIVERY_AREA`

`unavailableItems` 는 없으면 `[]`, `orderable=false` 면 `combo` 는 `null` 로 주세요.
앱은 이 경우 결제 버튼을 잠그고 "지금 위치에서는 이 매장이 배달하지 않아요" 배너를 띄운다.

**사용자 위치에 배달 불가한 매장이면 같은 브랜드 다른 지점을 제안할지 확인 필요.**

---

## 위치 — 앱이 보내는 값

`orderableOnly`(1번)와 `reorder`(9번)가 좌표를 요구한다. **앱에 위치 수집을 구현 완료했다.**
`geolocator` 로 로그인 직후 1회 수집한다.

정상적으로 좌표를 얻은 경우

```json
{ "lat": 37.5445, "lng": 127.0557 }
```

위치 권한을 거부해 좌표를 모르는 경우 — 사용자에게 주소를 직접 입력받는다

```json
{ "lat": 0, "lng": 0, "address": "서울 송파구 잠실동 40-1" }
```

**❓ 주소 → 좌표 변환을 서버가 해 주실 수 있나요?**
**앱은 입력받은 주소를 좌표로 바꾸지 않고 문자열 그대로 보낸다.** 아무 좌표나 지어내면
엉뚱한 매장이 걸리기 때문이다. 그래서 이 경우 `lat`/`lng` 가 `0` 으로 온다.

- 서버가 `address` 로 좌표를 찾아 주시면 앱은 지금 구조 그대로 두면 된다.
- 못 하시는 쪽이면 앱에 지오코딩을 붙여야 하니 알려 주세요.

권한 거부는 정상 경로로 취급한다. 위치가 없어도 앱은 멈추지 않고 `orderableOnly` 를
못 켜는 정도로만 기능이 줄어든다.

> 참고 — 앱이 상단 바에 "송파구 잠실동" 처럼 동네 이름을 보여주는데, 이건 **앱이 화면
> 표시용으로만** OS 지오코더로 구한 값이고 서버로 보내지 않는다. 서버가 좌표로 주소를
> 만드는 몫과 겹치지 않는다.

---

## 공통 규칙 — 확정 부탁드립니다

| 항목 | 제안 |
|---|---|
| **인증** | `Authorization: Bearer <token>`. 권한 `ALL` 은 비로그인 허용, `USER` 는 로그인 필요 |
| **날짜** | ISO 8601 + 타임존 (`2026-07-07T12:30:00+09:00`) |
| **페이지네이션** | **커서 방식.** 실시간 피드라 오프셋은 중복·누락이 생긴다. 다음 페이지 없으면 `nextCursor: null` |
| **빈 값** | 배열은 `[]`, 객체·미지정은 `null`. **키 자체를 빼지 않기** (클라이언트가 터진다) |
| **이미지 URL** | 항상 절대 경로 |
| **enum** | 대문자 스네이크. `LATEST`, `POPULAR`, `SOLD_OUT`, `YOUTUBE` |
| **금액** | 원 단위 정수. 소수점 없음 |

**에러 형식**

```json
{
  "code": "POST_NOT_FOUND",
  "message": "게시글을 찾을 수 없습니다."
}
```

HTTP 상태코드와 함께 주세요. 앱은 `code` 로 분기하고 `message` 는 그대로 노출하지 않는다
(사용자 문구는 앱이 따로 관리한다).

---

## 미해결 항목

1. **"실시간 인기" 산정 기준** — 누적 좋아요 / 최근 24h / 조회수 반영
2. **`source` 필드** — 목록·상세 Response 와 작성 Request 에 추가 필요 (1·2·3번 비고)
3. **주문 이력 없이 공유** — 분석 결과에서 바로 공유하는 경로가 있어 `combo` 직접 전달 필요 (3번 비고)
4. **주소 → 좌표 변환 주체** — 서버/앱 중 어디서 할지 (위치 섹션)
5. **`commentCount` 를 댓글 작성 응답에 포함** (8번 비고)
6. **찜 연동** — 3차 회의록의 *"조합된 메뉴는 요기요 찜에 저장"* 을 이 API 에 넣을지 별도 찜 API 로 뺄지
7. **신고·차단** — 커뮤니티라 필요할 수 있으나 이번 범위에서는 제외 제안
8. **`/api` 접두사** — 엔드포인트가 `v1/posts` 인지 `/api/v1/posts` 인지
