# 요기족보 API 명세

> **2026-08-09 에 배포된 서버로 직접 확인한 계약이다.** 노션 명세와 다른 곳이
> 있으면 이 문서가 기준이다. 확인한 것은 `test/yogijokbo_api_test.dart` 가 잠근다.

출처: Notion `[요기요 x 오라클 해커톤] / API 명세서 (수정완료) / 요기족보`
+ 2026-08-09 실서버 확인

## 노션 명세와 다른 곳

| 항목 | 노션 명세 | 실제 서버 |
| --- | --- | --- |
| 인증 헤더 | `X-User-Id` | `Authorization: Bearer {accessToken}` |
| 목록 응답 키 | `items` | `posts` |
| 게시글 id | `id` | `postId` (Long, 숫자) |
| 작성자 | `author` 오브젝트 | `authorNickName` 문자열 (대문자 N) |
| 좋아요 여부 | `likedByMe` | `liked` |
| 상세의 조합 | `combo` (매장 하나) | `order` (주문 상세와 같은 모양, 매장 목록) |
| 댓글 페이지네이션 | `cursor`/`size` | 없다. 한 번에 다 준다 |
| 댓글 작성 응답 | 본문 없음 | 갱신된 댓글 목록 전체 |
| 작성 요청 | `data`(JSON) 파트 + `orderId` | 평평한 multipart 필드 + `checkoutId` |
| 목록의 위치 필터 | `orderableOnly`/`lat`/`lng` | 폐기 (기능 자체가 없어졌다) |

## 공통

| 항목 | 값 |
| --- | --- |
| Base | `{API_BASE_URL}/` — `.env` 의 `API_BASE_URL` |
| 인증 헤더 | `Authorization: Bearer {accessToken}` |
| 페이지네이션 | 목록만 cursor 기반. `cursor`, `size` (기본 20) |
| 시간 | ISO-8601 + `+09:00` |

`liked` 는 **토큰 기준**이다. 인증 헤더가 없으면 전부 `false` 로 온다.

목록과 상세는 인증이 없어도 `200` 이다. 좋아요는 무인증이면 `401` 이다.

회의(2026-08-04)에서 족보 등록·주문·리뷰를 **묶음 조합 단위**로 바꿨다. 상세의 `order` 블록이 매장 목록(`stores[]`)을 담아 그 결정과 맞는다. 함께 바뀐 것: 찜하기 기능 제거, 맵기 3단계 확정.

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
| 8 | ALL | PATCH | `v1/posts/{postId}` | 요기족보 게시물 수정 |
| 9 | USER | DELETE | `v1/posts/{postId}` | 게시물 삭제 |
| 10 | USER | DELETE | `v1/posts/{postId}/comments/{commentId}` | 댓글 삭제 |

8번은 2026-08-10 에 명세가 들어왔다. 9·10 은 아직 표에 없고 서버에만 있다 —
아래 "명세에 없지만 서버에 있는 것" 참고.

---

## 1. 요기족보 홈 — 조합 목록

```
GET v1/posts
```

### Request

Header

```
Authorization: Bearer {accessToken}
```

Query Parameter

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `sort` | Enum | `LATEST` \| `POPULAR` |
| `cursor` | String | |
| `size` | Integer | 기본 20 |

좌표를 받지 않는다. `orderableOnly` / `lat` / `lng` 는 "내 위치에서 가능한 조합만" 기능과 함께 폐기됐다 (2026-08-09 디자이너·백엔드 확인).

### Request example

```
GET v1/posts?sort=POPULAR&size=20
```

### Response

`200 OK`

```json
{
  "posts": [
    {
      "postId": 9001,
      "title": "떵개 추천 두찜 로제 닭발",
      "thumbnailUrl": "https://cdn.example.com/orders/5001/source.jpg",
      "authorNickName": "배고픈 요기요",
      "createdAt": "2026-07-07T19:12:00+09:00",
      "likeCount": 12,
      "commentCount": 4,
      "liked": false
    }
  ],
  "nextCursor": "eyJpZCI6OTAwMX0="
}
```

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `postId` | Long | **숫자다.** 앱 모델은 문자열 id 로 담는다 |
| `thumbnailUrl` | String, nullable | 서버가 골라 준다. 앱은 다시 고르지 않는다 |
| `authorNickName` | String | 대문자 `N`. id·프로필 사진은 안 온다 |
| `liked` | Boolean | 토큰 기준. 무인증이면 `false` |
| `nextCursor` | String, nullable | 없으면 마지막 페이지 |

### 비고

정렬

- `LATEST` → `created_at DESC` (인덱스 `ix_post_latest`)
- `POPULAR` → `like_count DESC, created_at DESC` (`ix_post_popular`)

`thumbnailUrl` 은 영상 썸네일. `orders.source_thumbnail` 이 비어 있으면(프론트에서 og:image 를 못 긁은 경우) `post_image` 첫 장을, 그마저 없으면 첫 메뉴 사진을 대신 내려준다. 카드에 빈 칸이 생기지 않게 한다.

목록에는 조합 전체를 내리지 않는다. 메뉴·옵션·금액은 상세에서 받는다.

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
Authorization: Bearer {accessToken}
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
  "postId": 9001,
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "분모자랑 치즈 꼭 추가하고 드세요\n맵찔이는 치즈 추가해서 먹어야 딱 적당히 매워서 너무 맛있어요",
  "imageUrls": [
    "https://cdn.example.com/posts/9001/1.jpg",
    "https://cdn.example.com/posts/9001/2.jpg"
  ],
  "eatedAt": "2026-07-07T19:12:00+09:00",
  "likeCount": 12,
  "commentCount": 4,
  "liked": false,
  "mine": true,
  "order": {
    "checkoutId": 5001,
    "orderedAt": "2026-07-07T18:00:00+09:00",
    "source": {
      "platform": "YOUTUBE",
      "url": "https://www.youtube.com/watch?v=abc123",
      "thumbnailUrl": "https://cdn.example.com/orders/5001/source.jpg",
      "title": "Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가"
    },
    "totalPrice": 23000,
    "stores": [
      {
        "restaurantId": 201,
        "restaurantName": "두찜-잠실새내점",
        "deliveryFee": 3000,
        "itemsTotal": 20000,
        "subtotal": 23000,
        "items": [
          {
            "menuId": 201001,
            "menuName": "[원조 K 로제] 로제 닭발",
            "menuImageUrl": "https://cdn.example.com/menus/201001.jpg",
            "unitPrice": 16000,
            "quantity": 1,
            "selectedOptions": [
              { "group": "토핑 추가", "name": "치즈몽땅", "price": 0 }
            ],
            "optionsPrice": 0,
            "lineTotal": 16000
          }
        ]
      }
    ]
  }
}
```

### 필드

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `imageUrls` | List\<String\> | 사용자가 올린 사진 (`post_image`) |
| `eatedAt` | DateTime | **먹은 날.** 작성일(`createdAt`)은 오지 않는다 |
| `liked` | Boolean | 토큰 기준 |
| `mine` | Boolean | 내 글인지. 수정·삭제 노출을 이 값으로 가른다 |
| `order` | Object | **주문 상세(`GET v1/orders/{checkoutId}`)와 같은 모양** |
| `order.stores[].items[].selectedSpice` | Enum, nullable | `NONE` \| `MEDIUM` \| `HOT` |
| `order.stores[].items[].selectedOptions` | List | `{ group, name, price }` — 고른 것만 |

작성자가 오지 않는다. 화면의 작성자 줄은 값이 들어올 때까지 비어 있다 (확인 필요 항목).

`order` 가 주문 상세와 같은 모양이라 앱은 `OrderDetail` 파싱을 그대로 다시 쓰고, 같은 변환으로 "나도 주문하기" 장바구니를 만든다. 파싱을 두 벌 두지 않는다.

### 비고

댓글은 여기 안 담긴다. `GET v1/posts/{postId}/comments` 로 따로 받는다 — 글보다 자주 바뀌기 때문이다.

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
Authorization: Bearer {accessToken}
Content-Type: multipart/form-data
```

필드 (JSON 파트가 아니라 **평평한 form 필드**다)

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `checkoutId` | Long | 명세의 `orderId` 가 아니다 |
| `title` | String | 최대 20자 |
| `body` | String | 최대 400자 |

`images` (file)

| 항목 | 값 |
| --- | --- |
| 장수 | 0~5장 |
| 형식 | jpg, jpeg, png, webp |
| 크기 | 장당 최대 5MB |

- 사용자가 직접 찍은 사진. 없으면 생략해도 된다.
- 서버가 오브젝트 스토리지에 올리고 `post_image` 에 url 을 써넣는다.
- 보낸 순서가 그대로 표시 순서(`sort_order`)가 된다.

### 받지 않는 것

`restaurantId` 를 받지 않는다. `checkoutId` 하나로 조합이 전부 정해진다.

조합 내용을 보내지 않는다. `checkoutId` 만 보내면 서버가 결제 스냅샷에서 읽어 붙인다. 메뉴·옵션·맵기·금액은 이미 주문 시점 스냅샷으로 저장되어 있다. 영상 링크·썸네일도 그쪽에서 가져온다.

`userId` 를 받지 않는다. 인증에서 꺼낸다. 본문으로 받으면 남의 이름으로 글을 쓸 수 있다.

한 결제로 글을 두 번 쓸 수 없다 — `UNIQUE (checkout_id)`. 가게가 여러 곳인 결제였으면 글 하나가 묶음 조합을 담는다.

### Request example

```
POST v1/posts
Authorization: Bearer {accessToken}
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="checkoutId"

5001
------X
Content-Disposition: form-data; name="title"

분모자 넣은 엽떡 진짜 맛있음
------X
Content-Disposition: form-data; name="body"

영상 보고 그대로 시켰는데 분모자가 신의 한 수였음.
------X
Content-Disposition: form-data; name="images"; filename="1.jpg"
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

`images` 는 없어도 된다. 사진 없이 글만 쓰는 경우가 있다.

앱에서는 `ApiClient.multipart` 가 이 요청을 만든다. 헤더에 `Content-Type` 을 넣지 않는 것이 이 메서드가 [get]/[post] 와 따로 있는 이유다.

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
| `404` | 그 `checkoutId` 가 없거나 내 결제가 아님 |
| `409` | 같은 `checkoutId` 로 이미 쓴 글이 있음 |

`404` 를 쓴다. `403` 이 아니다 — 남의 결제 번호가 존재한다는 사실이 새면 안 된다.

### 흐름

```
주문내역 [족보 작성] 누름
  → GET v1/orders/{checkoutId} 로 영상 썸네일·링크·주문한 메뉴를 미리 보여줌
  → 사용자는 제목·후기·사진만 입력
  → POST v1/posts (multipart) 로 필드 + images(파일) 를 한 번에 보냄
  → 201 의 postId 를 들고 주문내역으로 돌아가고, 토스트의 "보러가기" 로 그 글을 연다
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
Authorization: Bearer {accessToken}
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
  "liked": true
}
```

무인증으로 부르면 `401` 이다 (목록·상세와 다르다).

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
Authorization: Bearer {accessToken}
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
  "liked": false
}
```

`liked` 는 항상 `false`.

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

쿼리 파라미터가 없다. 한 글의 댓글을 한 번에 다 준다 (2026-08-09 확인). 앱도 이어 받는 커서를 두지 않는다.

### Request example

```
GET v1/posts/9001/comments
```

### Response

`200 OK`

```json
{
  "comments": [
    {
      "commentId": 4101,
      "authorId": 2,
      "authorNickName": "배고픈 요기요",
      "body": "ㅇㅈ 진짜 맛있어요 근데 전 순한맛도 살짝 매웠어서 가게에 덜맵게 요청하는 거 추천",
      "createdAt": "2026-07-07T20:03:00+09:00",
      "mine": false
    }
  ]
}
```

### 비고

정렬은 `created_at` 오름차순 (오래된 댓글이 위). 인덱스 `ix_pcmt_post (post_id, created_at)` 가 받친다.

글 상세 응답에는 댓글을 담지 않는다. 글보다 자주 바뀌기 때문이다.

Figma 엔 1단계 댓글만. 대댓글·수정·삭제 필요 여부 확인.

---

## 7. 댓글 작성

```
POST v1/posts/{postId}/comments
```

### Request

Header

```
Authorization: Bearer {accessToken}
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

`201 CREATED` — **갱신된 댓글 목록 전체**를 6번과 같은 모양으로 준다.

```json
{ "comments": [ { "commentId": 4101, "...": "..." } ] }
```

서버가 매긴 id·작성시각이 이 응답에 들어 있어 목록을 다시 받지 않는다.

`mine` 은 내가 쓴 댓글인지. 삭제 아이콘을 이 값으로 가른다.

### 테이블

```
post_comment(comment_id, post_id, user_id, body, created_at)
```

---

## 8. 요기족보 게시물 수정

```
PATCH v1/posts/{postId}
```

**multipart/form-data 다.** 작성(3번)과 같은 모양이고 `checkoutId` 만 없다 — 조합은 결제 스냅샷이라 글쓴이가 바꿀 수 있는 값이 아니다.

명세 표의 권한이 `ALL` 로 적혀 있지만 `Authorization` 헤더를 요구한다. 실제로는 `USER` 이고, 남의 글이면 `403` 이다. 앱은 상세의 `mine` 이 true 일 때만 수정 화면을 열어 준다.

### Request

Header

```
Authorization: Bearer {accessToken}
Content-Type: multipart/form-data
```

Path Variable

| 이름 | 타입 |
| --- | --- |
| `postId` | Long |

필드

| 이름 | 타입 | 비고 |
| --- | --- | --- |
| `title` | String | 최대 20자 |
| `body` | String | 최대 400자 |
| `images` | file | 0~5장, jpg/jpeg/png/webp, 장당 최대 5MB |

### images 는 부분 수정이 아니다

**수정 후 남을 사진 전부를 보낸다. 기존 사진도 예외가 아니다.** 보낸 순서가 그대로 새 표시 순서(`sort_order`)가 된다.

즉 이 목록이 사진 전체를 대체한다. 제목만 고칠 때 `images` 를 비워 보내면 **사진이 전부 지워진다.**

앱은 URL 로만 아는 기존 사진을 지키기 위해 이렇게 한다.

```
수정 저장
  → 지금 붙어 있는 imageUrls 를 순서대로 다시 받아 온다 (CDN, 인증 헤더 없음)
  → 받아 온 바이트 + 새로 고른 파일을 한 목록으로 만들어 PATCH 로 보낸다
  → 한 장이라도 못 받으면 요청을 보내지 않고 저장을 실패시킨다
```

마지막 줄이 중요하다. 못 받은 채로 보내면 사용자가 건드리지도 않은 사진이 사라진다. 저장 실패가 사진 유실보다 낫다 (`PostImagesUnavailableException` → 수정 화면에 남고 토스트로 알린다).

파트의 `Content-Type` 은 파일 이름의 확장자로 정한다. http 패키지는 이 값을 추측하지 않고 `application/octet-stream` 을 넣어서, 그대로 두면 서버의 형식 검증에 걸린다.

### Request example

```
PATCH v1/posts/9001
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="title"

엽떡+교촌 조합 인정 (수정)
------X
Content-Disposition: form-data; name="body"

다시 시켜보고 적음. 분모자 사리는 진짜 필수.
------X
Content-Disposition: form-data; name="images"; filename="old_0.jpg"
Content-Type: image/jpeg

(binary)   ← 기존 사진도 파일로 다시 보낸다
------X
Content-Disposition: form-data; name="images"; filename="new.jpg"
Content-Type: image/jpeg

(binary)
------X--
```

### Response

`200 OK`

### 서버 동작

예전 이미지는 `post_image` 행만 지우고 버킷 파일은 남긴다. 지우다 실패하면 화면에 없는 사진 때문에 수정 전체가 롤백된다. 저장 공간보다 글을 고칠 수 있는 쪽이 중요하다.

업로드를 먼저 하고 행을 지운다. 업로드가 실패하면 예외가 나가 트랜잭션이 통째로 되돌아가므로, 기존 사진이 지워진 채 새 사진도 없는 상태가 생기지 않는다.

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

## 명세에 없지만 서버에 있는 것

시안 922:2734 의 삭제 화면에 필요한 두 경로가 명세 표에는 없고 서버에만 있다. 남의 글로 불러 `403` 을 받는 것으로 존재를 확인했다 (2026-08-09).

| 경로 | 확인한 응답 | 상태 |
| --- | --- | --- |
| `DELETE v1/posts/{postId}` | `403` (남의 글이라 거부 = 존재) | 쓸 수 있다 |
| `DELETE v1/posts/{postId}/comments/{commentId}` | `403` (같음) | 쓸 수 있다 |

수정도 처음엔 여기 있었다. `415` 만 받던 상태에서 2026-08-10 에 형식이 들어와 8번으로 옮겼다.

수정·삭제는 내 것에만 열어 준다. 상세의 `mine`, 댓글의 `mine` 으로 가른다 — 남의 것에 버튼을 두면 반드시 실패하는 버튼이 된다.

`GET v1/users/me/posts` 는 아직 미구현이다 (`404`). 내가 쓴 글 목록 화면은 그 경로가 열린 뒤에 붙인다.

---

## 확인 필요 항목

| 항목 | 내용 |
| --- | --- |
| 목록의 본문 | 1번 응답에 `body`(또는 미리보기)가 없다. Figma 목록 카드는 본문 2줄을 보여준다. 앱은 키가 붙는 즉시 읽도록 해 뒀다 |
| 상세의 작성자·작성일 | 2번 응답에 작성자(`authorNickName`)와 작성일이 없다. 화면은 작성자 줄과 날짜를 보여주는데, 지금은 날짜를 `eatedAt`(먹은 날)으로 대신 쓰고 작성자 줄은 비워 둔다 |
| ~~`PATCH v1/posts/{id}` 형식~~ | **닫힘.** multipart 이고 사진도 교체된다 (2026-08-10 명세). 8번 참고 |
| 수정의 사진 되보내기 | 앱이 기존 사진을 CDN 에서 다시 받아 되올린다. 사진이 많으면 왕복이 그만큼 늘어난다. 남길 사진을 URL·id 로 지정하는 방식(예: `keepImageIds`)이 있으면 그쪽이 낫다 |
| `GET v1/users/me/posts` | 미구현(`404`). 내가 쓴 글 목록 |
| ~~상세의 `orderableHere`~~ | **닫힘.** "내 위치에서 가능한 조합만" 기능이 폐기됐다 (2026-08-09). 필드·쿼리·필터를 앱에서 모두 지웠다 |
| ~~`selectedSpice` 3단계~~ | **닫힘.** 회의(2026-08-04)에서 맵기를 3단계(`NONE`/`MEDIUM`/`HOT`)로 통일했다. 시안의 "매운맛 5단계" 옵션 그룹은 없애고, `spiceAdjustable` 이 true 인 메뉴에만 3버튼을 그린다 |
| ~~묶음 조합 응답 모양~~ | **닫힘.** 상세의 `order` 블록이 주문 상세와 같은 모양이다 (2026-08-09 확인) |
| ~~게시물 수정·삭제, 댓글 삭제~~ | **경로 확인됨.** 위 "명세에 없지만 서버에 있는 것" 참고. 수정 형식만 남았다 |
| 대댓글 | 시안에 1단계 댓글만 있다. 필요 여부 확정 필요 |
