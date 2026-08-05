# 요기족보 API 명세

> **2026-08-04 회의 이후 재확인이 필요한 문서다.** 아래 내용은 매장 하나를
> 기준으로 쓰여 있는데, 회의에서 족보 등록·주문·리뷰를 **묶음 조합 단위**로
> 바꿨다. 앱은 `YogijokboPost.stores` (매장 목록)로 이미 고쳐 두었고, 주문 상세
> (`docs/api-spec.md` 4번)와 같은 모양을 가정한다. 서버 응답 필드명이 확정되면
> 이 문서의 2번·3번을 고친다.
>
> 함께 바뀐 것: 찜하기 기능 제거, 맵기 3단계 확정.

출처: Notion `[요기요 x 오라클 해커톤] / API 명세서 (수정완료) / 요기족보`

## 공통

| 항목 | 값 |
| --- | --- |
| Base | `/api/` |
| 인증 헤더 | `User-Id: Long` |
| 페이지네이션 | cursor 기반. `cursor`, `size` (기본 20) |
| 시간 | `DateTime` |

`likedByMe` 는 인증 헤더가 없으면 `false`.

## 엔드포인트

| # | 권한 | Method | End Point | 기능 |
| --- | --- | --- | --- | --- |
| 1 | ALL | GET | `v1/posts` | 요기족보 홈. 실시간 인기/최신 조합 목록 |
| 2 | ALL | GET | `v1/posts/{postId}` | 요기족보 게시물 상세 |
| 3 | USER | POST | `v1/posts` | 내 조합을 요기족보에 공유 |
| 4 | USER | POST | `v1/posts/{postId}/likes` | 조합 좋아요 |
| 5 | USER | DELETE | `v1/posts/{postId}/likes` | 좋아요 취소 |
| 6 | ALL | GET | `v1/posts/{postId}/comments` | 조합 댓글 목록 |
| 7 | USER | POST | `v1/posts/{postId}/comments` | 댓글 작성 |

---

## 1. 요기족보 홈 — 조합 목록

```
GET v1/posts
```

### Request

Header

```
User-Id: Long
```

Query Parameter

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `sort` | Enum | `LATEST` \| `POPULAR` |
| `orderableOnly` | Boolean | |
| `lat` | Double | `orderableOnly=true` 시 필수 |
| `lng` | Double | `orderableOnly=true` 시 필수 |
| `cursor` | String | |
| `size` | Integer | 기본 20 |

### Request example

```
GET v1/posts?sort=POPULAR&orderableOnly=true&lat=37.5445&lng=127.0557&size=20
```

### Response

`200 OK`

```json
{
  "items": [
    {
      "id": 9001,
      "title": "떵개 추천 두찜 로제 닭발",
      "thumbnailUrl": "https://cdn.example.com/orders/5001/source.jpg",
      "storeName": "두찜-잠실새내점",
      "likeCount": 12,
      "commentCount": 4,
      "author": {
        "nickname": "배고픈 요기요",
        "profileImageUrl": "https://cdn.example.com/users/1/profile.jpg"
      },
      "orderableHere": true,
      "createdAt": "2026-07-07T19:12:00"
    }
  ],
  "nextCursor": "eyJpZCI6OTAwMX0="
}
```

### 비고

정렬

- `LATEST` → `created_at DESC` (인덱스 `ix_post_latest`)
- `POPULAR` → `like_count DESC, created_at DESC` (`ix_post_popular`)

`thumbnailUrl` 은 영상 썸네일. `orders.source_thumbnail` 이 비어 있으면(프론트에서 og:image 를 못 긁은 경우) `post_image` 첫 장을, 그마저 없으면 첫 메뉴 사진을 대신 내려준다. 카드에 빈 칸이 생기지 않게 한다.

목록에는 조합 전체를 내리지 않는다. 메뉴·옵션·금액은 상세에서 받는다.

`orderableHere` 는 그 조합을 지금 내 위치에서 시킬 수 있는지. `lat`/`lng` 기준 반경 5km 안에 그 가게가 있으면 `true`. `orderableOnly=true` 면 `false` 인 것은 목록에서 아예 빠진다.

`like_count` / `comment_count` 는 `post` 테이블의 비정규화 캐시다. 목록에서 글마다 COUNT 를 돌리면 느리므로, 좋아요·댓글이 달릴 때 같이 증감시킨다.

"실시간 인기" 산정 기준은 누적 좋아요. 최근 24h 가중치나 조회수 반영은 데이터가 쌓인 뒤에 정한다.

---

## 2. 조합 게시글 상세

```
GET v1/posts/{postId}
```

### Request

Header

```
User-Id: Long
```

Path Variable

| 이름 | 타입 |
| --- | --- |
| `postId` | Long |

### Request example

```
GET v1/posts/9001
```

### Response

`200 OK`

```json
{
  "id": 9001,
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "분모자랑 치즈 꼭 추가하고 드세요\n맵찔이는 치즈 추가해서 먹어야 딱 적당히 매워서 너무 맛있어요",
  "imageUrls": [
    "https://cdn.example.com/posts/9001/1.jpg",
    "https://cdn.example.com/posts/9001/2.jpg"
  ],
  "author": {
    "id": 1,
    "nickname": "배고픈 요기요",
    "profileImageUrl": "https://cdn.example.com/users/1/profile.jpg"
  },
  "source": {
    "platform": "YOUTUBE",
    "url": "https://www.youtube.com/watch?v=abc123",
    "thumbnailUrl": "https://cdn.example.com/orders/5001/source.jpg",
    "title": "Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가 / 닭발 먹방 asmr 리얼사운드"
  },
  "combo": {
    "store": {
      "id": 3001,
      "name": "두찜-잠실새내점",
      "imageUrl": "https://cdn.example.com/stores/3001.jpg",
      "rating": 4.2,
      "reviewCount": 312
    },
    "items": [
      {
        "menuId": 7001,
        "name": "[원조 K 로제] 로제 닭발",
        "description": "순살, 보통맛, 분모자로 변경, 치즈몽땅 추가, [리뷰 이벤트] 납작당면 추가",
        "imageUrl": "https://cdn.example.com/menus/7001.jpg",
        "unitPrice": 20000,
        "quantity": 1,
        "selectedSpice": "MEDIUM",
        "selectedOptions": [
          { "name": "치즈몽땅 추가", "price": 2000 },
          { "name": "납작당면 추가", "price": 1000 }
        ],
        "optionsPrice": 3000,
        "lineTotal": 23000
      }
    ],
    "itemsTotal": 23000,
    "deliveryFee": 1500,
    "payableTotal": 24500
  },
  "likeCount": 12,
  "likedByMe": false,
  "commentCount": 4,
  "createdAt": "2026-07-07T19:12:00"
}
```

### 필드

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `imageUrls` | List\<String\> | 사용자가 올린 사진 (`post_image`) |
| `source.platform` | Enum | `INSTAGRAM` \| `YOUTUBE` |
| `source.url` | String | 영상 연결 화면으로 가는 링크 |
| `source.thumbnailUrl` | String | 영상 썸네일 (`orders.source_thumbnail`) |
| `combo.items[].description` | String | 주문 시점 스냅샷 |
| `combo.items[].selectedSpice` | Enum, nullable | `NONE` \| `MEDIUM` \| `HOT` |
| `combo.items[].selectedOptions` | List | `{ name: String, price: Integer }` |
| `likedByMe` | Boolean | 인증 헤더가 없으면 `false` |

### 비고

댓글은 여기 안 담긴다. `GET v1/posts/{postId}/comments` 로 따로 받는다 — 댓글은 페이지네이션이 필요하고 글보다 자주 바뀌기 때문이다.

영상 사진과 사용자 사진은 다른 것이다.

- `source.thumbnailUrl` : 영상 썸네일 (`orders.source_thumbnail`)
- `imageUrls[]` : 사용자가 올린 사진 (`post_image`)

목록 카드에는 영상 썸네일을 쓴다.

---

## 3. 내 조합을 요기족보에 공유

```
POST v1/posts
```

사진을 이 요청에 같이 보낸다. 업로드 API 를 따로 치지 않는다.

### Request

Header

```
User-Id: Long
Content-Type: multipart/form-data
```

Part 1 — `data` (`application/json`)

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `orderId` | Long | |
| `title` | String | 최대 20자 |
| `body` | String | 최대 400자 |

Part 2 — `images` (file)

| 항목 | 값 |
| --- | --- |
| 장수 | 0~5장 |
| 형식 | jpg, png |
| 크기 | 장당 최대 5MB |

- 사용자가 직접 찍은 사진. 없으면 생략해도 된다.
- 서버가 오브젝트 스토리지에 올리고 `post_image` 에 url 을 써넣는다.
- 보낸 순서가 그대로 표시 순서(`sort_order`)가 된다.

### 받지 않는 것

`restaurantId` 를 받지 않는다. 주문 1건이 곧 가게 1곳이라 `orderId` 하나면 가게가 정해진다.

조합 내용을 보내지 않는다. `orderId` 만 보내면 서버가 `orders` 와 `order_item` 에서 읽어 붙인다. 메뉴·옵션·맵기·금액은 이미 주문 시점 스냅샷으로 저장되어 있다. 영상 링크·썸네일도 `orders` 에서 가져온다.

`userId` 를 받지 않는다. 인증에서 꺼낸다. 본문으로 받으면 남의 이름으로 글을 쓸 수 있다.

엽떡 + 교촌을 한 번에 결제했으면 주문이 2건이니 글도 2건이다. 주문 내역에서 각각 `[족보 작성]` 을 누른다. 같은 `orderId` 로 두 번 쓰면 `409 CONFLICT`.

### Request example

```
POST v1/posts
User-Id: 1
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="data"
Content-Type: application/json

{
  "orderId": 5001,
  "title": "분모자 넣은 엽떡 진짜 맛있음",
  "body": "영상 보고 그대로 시켰는데 분모자가 신의 한 수였음. 오리지널로 시켜도 충분히 매운데 분모자랑 같이 먹으니 덜 자극적이고 좋았어요."
}
------X
Content-Disposition: form-data; name="images"; filename="1.jpg"
Content-Type: image/jpeg

(binary)
------X
Content-Disposition: form-data; name="images"; filename="2.jpg"
Content-Type: image/jpeg

(binary)
------X--
```

`boundary` 는 한 본문 안에서 파트를 나누는 구분선이다. HTTP 클라이언트가 랜덤으로 만들어 붙이므로 직접 쓸 일이 없다. 오히려 프론트에서 `Content-Type` 을 손으로 지정하면 `boundary` 가 빠져 `400` 이 난다. FormData 만 넘기고 헤더는 건드리지 않는다.

```js
const fd = new FormData();
fd.append("data", new Blob([JSON.stringify(body)], { type: "application/json" }));
files.forEach(f => fd.append("images", f));
axios.post("/api/v1/posts", fd);
```

스프링 쪽은 이렇게 받는다.

```java
@PostMapping(consumes = MULTIPART_FORM_DATA_VALUE)
@ResponseStatus(CREATED)
PostCreateResponse create(
    @AuthenticationPrincipal Long userId,
    @Valid @RequestPart("data") PostCreateRequest data,
    @RequestPart(value = "images", required = false) List<MultipartFile> images)
```

`images` 는 `required = false` 다. 사진 없이 글만 쓰는 경우가 있다. 5장 제한은 `@Size` 가 `List<MultipartFile>` 에 잘 걸리지 않으니 서비스 진입부에서 직접 센다.

### Response

`201 CREATED`

```
Location: /api/v1/posts/9012
```

```json
{ "postId": 9012 }
```

글 전체를 되돌려주지 않는다. 작성 직후 프론트는 상세 화면으로 이동하고, 그 화면은 이미 `GET v1/posts/{postId}` 를 쓰고 있다. 생성 응답에 상세와 똑같은 본문을 실으면 같은 모양을 두 군데서 만들게 되고, 한쪽만 고쳐져 어긋난다. 올린 사진 url 도 상세에서 받으면 된다.

### 실패

| 코드 | 조건 |
| --- | --- |
| `400` | `title`/`body` 가 비었거나 길이 초과, 사진 5장 초과 |
| `404` | 그 `orderId` 가 없거나 내 주문이 아님 |
| `409` | 같은 `orderId` 로 이미 쓴 글이 있음 |

`404` 를 쓴다. `403` 이 아니다 — 남의 주문 번호가 존재한다는 사실이 새면 안 된다.

### 흐름

```
주문내역 [족보 작성] 누름
  → GET v1/orders/{orderId} 로 영상 썸네일·링크·주문한 메뉴를 미리 보여줌
  → 사용자는 제목·후기·사진만 입력
  → POST v1/posts (multipart) 로 data(JSON) + images(파일) 를 한 번에 보냄
  → 201 의 postId 로 상세 화면 이동
```

사진 업로드 API 를 따로 두지 않는다. 따로 빼면 글을 안 쓰고 나간 사진이 스토리지에 고아로 남고, 사진만 올라가고 글은 실패하는 상태가 생긴다. 한 요청 한 트랜잭션이면 그런 상태가 없다.

### 테이블

```
post(post_id, user_id, checkout_id, title, body, like_count, comment_count, created_at)
post_image(post_image_id, post_id, image_url, sort_order)
UNIQUE (checkout_id) — 한 결제로 글을 두 번 못 쓴다
```

FK 를 걸 수 없다. `checkout_id` 가 `orders` 안에서 유일하지 않아 참조 대상이 될 수 없다. "그 결제가 내 것으로 존재하나" 는 서버가 직접 검사한다. 없으면 `403` 이 아니라 `404`.

조합 내용을 `post` 에 복사하지 않는 이유: `order_item` 이 이미 주문 시점 스냅샷이라 또 복사하면 같은 걸 두 군데 두는 것이다. 메뉴 가격이 바뀌어도 `order_item` 은 안 변하므로 글의 조합도 안 변한다.

---

## 4. 조합 좋아요

```
POST v1/posts/{postId}/likes
```

### Request

Header

```
User-Id: Long
```

Path Variable

| 이름 | 타입 |
| --- | --- |
| `postId` | Long |

### Request example

```
POST v1/posts/9001/likes
```

### Response

`200 OK`

```json
{
  "likeCount": 13,
  "likedByMe": true
}
```

이미 누른 상태에서 또 눌러도 `200` 을 낸다 (멱등성). 중복 삽입은 PK `(post_id, user_id)` 가 막아준다.

### 테이블

```
post_like(post_id, user_id, liked_at), PK (post_id, user_id)
```

좋아요가 늘 때 `post.like_count` 를 같이 `+1` 한다. 목록에서 글마다 COUNT 를 돌리지 않기 위한 비정규화 캐시다.

---

## 5. 좋아요 취소

```
DELETE v1/posts/{postId}/likes
```

### Request

Header

```
User-Id: Long
```

Path Variable

| 이름 | 타입 |
| --- | --- |
| `postId` | Long |

### Request example

```
DELETE v1/posts/9001/likes
```

### Response

`200 OK`

```json
{
  "likeCount": 12,
  "likedByMe": false
}
```

`likedByMe` 는 항상 `false`.

안 누른 상태에서 취소해도 `200` 을 낸다 (멱등성). `post.like_count` 를 같이 `-1` 하되, 0 미만으로 내려가지 않게 한다.

4번과 응답 형태 동일.

---

## 6. 조합 댓글 목록

```
GET v1/posts/{postId}/comments
```

### Request

Path Variable

| 이름 | 타입 |
| --- | --- |
| `postId` | Long |

Query Parameter

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `cursor` | String | |
| `size` | Integer | 기본 20 |

### Request example

```
GET v1/posts/9001/comments?size=20
```

### Response

`200 OK`

```json
{
  "items": [
    {
      "id": 4101,
      "author": {
        "id": 2,
        "nickname": "배고픈 요기요",
        "profileImageUrl": "https://cdn.example.com/users/2/profile.jpg"
      },
      "body": "ㅇㅈ 진짜 맛있어요 근데 전 순한맛도 살짝 매웠어서 본인이 진짜 맵찔이면 가게에 덜맵게 요청하는 거 추천",
      "createdAt": "2026-07-07T20:03:00"
    }
  ],
  "nextCursor": null
}
```

`nextCursor` 는 nullable.

### 비고

정렬은 `created_at` 오름차순 (오래된 댓글이 위). 인덱스 `ix_pcmt_post (post_id, created_at)` 가 받친다.

글 상세 응답에는 댓글을 담지 않는다. 페이지네이션이 필요하고 글보다 자주 바뀌기 때문이다.

Figma 엔 1단계 댓글만. 대댓글·수정·삭제 필요 여부 확인.

---

## 7. 댓글 작성

```
POST v1/posts/{postId}/comments
```

### Request

Header

```
User-Id: Long
```

Path Variable

| 이름 | 타입 |
| --- | --- |
| `postId` | Long |

Request Body

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `body` | String | 최대 500자 |

### Request example

```
POST v1/posts/9001/comments
```

```json
{ "body": "진짜 맛있겠다 근데 매우십니까?" }
```

### Response

`201 CREATED`

### 테이블

```
post_comment(comment_id, post_id, user_id, body, created_at)
```

---

## 나도 주문하기 흐름

전용 API 가 없다. 상세 응답의 조합을 프론트가 그대로 장바구니에 담는다.

```
GET v1/posts/{postId}   글 상세. stores 가 이미 장바구니 모양
  ↓
프론트가 그 stores 를 앱 메모리 장바구니에 복사 (AppFlow.cart)
  ↓
장바구니 화면 (CartScreen — 분석 결과에서 오는 것과 같은 화면)
  ↓
POST v1/orders          보낸 그대로 저장
```

**localStorage 가 아니다.** 원문에 그렇게 적혀 있었지만 Flutter 에는
localStorage 가 없다. 장바구니는 `AppFlow` 가 메모리로 들고 있고, 앱을 껐다
켜면 사라진다 — "백엔드는 저장하지 않고 프론트가 주문 시점에 통째로 POST" 라는
결정의 범위 그대로다. 영속이 필요해지면 `shared_preferences` 를 붙인다.

복사본이라 장바구니에서 수량을 바꿔도 게시글 스냅샷은 그대로다.

---

## 확인 필요 항목

| 항목 | 내용 |
| --- | --- |
| 인증 헤더 이름 | Request 는 `User-Id`, 2번 응답 설명은 `X-User-Id`. 어느 쪽인지 확정 필요 |
| 목록의 본문 | 1번 응답에 `body`(또는 미리보기)가 없다. Figma 목록 카드는 본문 2줄을 보여준다 |
| 상세의 `orderableHere` | 1번에만 있고 2번에는 없다. 상세에서 "나도 주문하기" 가능 여부를 판단할 근거가 없다 |
| ~~`selectedSpice` 3단계~~ | **닫힘.** 회의(2026-08-04)에서 맵기를 3단계(`NONE`/`MEDIUM`/`HOT`)로 통일했다. 시안의 "매운맛 5단계" 옵션 그룹은 없애고, `spiceAdjustable` 이 true 인 메뉴에만 3버튼을 그린다 |
| 묶음 조합 응답 모양 | 게시글의 `stores[]` 필드명·구조 확정 필요. 앱은 주문 상세와 같은 모양을 가정한다 |
| 대댓글·수정·삭제 | 6번 비고 — 필요 여부 확정 필요 |
