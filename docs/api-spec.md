# 먹방요기 API 명세 (확정)

노션 `API 명세서 (수정완료)` 를 옮긴 것. 프론트 모델·파싱의 기준 문서다.
필드를 고치면 이 문서와 `lib/models/` 를 함께 고친다.

수록 범위: 먹방요기(분석), Restaurants, Orders, Users, 그리고 DB 스키마 중
프론트가 알아야 하는 enum. 요기족보(posts)는 `api-yogijokbo.md` 를 본다.

## 공통

| 항목 | 값 |
| --- | --- |
| Base | `{API_BASE_URL}/` — `.env` 의 `API_BASE_URL` |
| 인증 헤더 | `Authorization: Bearer {accessToken}` |
| enum | 대문자 스네이크 |
| 페이지네이션 | cursor 방식. `{ items \| orders, nextCursor }`, 다음 없으면 `nextCursor: null` |
| 금액 | 전부 정수(원) |

초안에는 인증 헤더가 `User-Id` 와 `X-User-Id` 로 섞여 있었으나, 서버가 토큰 인증으로
구현되어 `Authorization: Bearer` 로 확정했다. 헤더를 만드는 자리는
`ApiClient._headers` 하나다.

회원가입 · 로그인 · 토큰 재발급은 인증 없이 부른다. 나머지 엔드포인트는 토큰이 없으면
`401 AUTHENTICATION_REQUIRED` 를 돌려준다.

**없는 경로도 401 을 준다.** 보안 필터가 라우팅보다 먼저 돌아서 오타 난 경로와 권한
없는 경로가 구분되지 않는다. 404 로 바꿔 달라고 요청해 둘 것 — 이것 때문에 로그인
경로를 잘못 알고 있던 동안 "서버가 막아 놨다" 로 오진한 적이 있다.

## 배포 상태 (2026-08-08 확인)

실제 서버에 요청해 확인한 결과다. 명세와 다른 곳은 각 절에 적어 둔다.

| 엔드포인트 | 상태 |
| --- | --- |
| `POST v1/users/signup` · `login` · `reissue-token` | 배포됨 |
| `GET v1/users/me` | 배포됨 |
| `POST v1/analyses` | 배포됨. 문서와 일치 (2026-08-08 명세 갱신 반영) |
| `GET v1/restaurants/{id}/menus` | 배포됨. **`restaurant` 블록이 빠져 있다** (2번 절) |
| `GET v1/orders` · `GET v1/orders/{id}` · `POST v1/orders` | 배포됨. 명세와 일치 |
| `v1/posts` (요기족보) | **미배포.** 2026-08-10 예정 |

## 공용 오브젝트

### restaurant

분석 응답과 메뉴 조회 응답이 같은 모양을 쓴다.

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `restaurantId` | Long | |
| `name` | String | `엽기떡볶이 성수점` — 지점까지 붙은 원본 상호명 |
| `foodCategory` | Enum | 9개 중 하나 |
| `area` | String | 동 단위. `성수동` |
| `rating` | Double | `4.7` |
| `etaMin` | Integer | 이동시간 + 조리시간. 실제로 몇 분 걸리는지 |
| `deliveryFee` | Integer | 가게별 배달비. 주문 시 가게마다 한 번 부과 |
| `minOrderPrice` | Integer | 음식값이 이 값보다 낮으면 "N원 더 담아주세요" |
| `distanceKm` | Double | |
| `imageUrl` | String | 대표 이미지 1장 |

`reviewCount` 는 응답에 없다. DB `restaurant.review_count` 는 있지만 API 로
내려오지 않아, 평점 옆 리뷰 수는 값이 있을 때만 그린다.

### items[] — 한 줄이 장바구니 한 칸

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `menuId` | Long | 주문 시 서버로 돌려보낼 유일한 값 |
| `name` | String | |
| `menuType` | Enum | `MAIN` \| `SIDE` \| `DRINK` |
| `price` | Integer | 메뉴 정가 |
| `imageUrl` | String | |
| `quantity` | Integer | |
| `spiceLevel` | Enum | `NONE` \| `MEDIUM` \| `HOT`. MEDIUM/HOT 이면 고추 뱃지 |
| `spiceAdjustable` | Boolean | true 면 순한맛/기본/매운맛 3버튼을 그린다 |
| `selectedSpice` | Enum, nullable | 백엔드가 골라둔 맵기 |
| `options` | List | 켜진 옵션만 온다. **빈 배열이어도 '옵션 변경' 버튼을 숨기지 않는다** |
| `optionsPrice` | Integer | 체크된 옵션 합계 |
| `lineTotal` | Integer | `(price + optionsPrice) × quantity` |

### options[]

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `group` | String, nullable | 묶어 그릴 라벨. 없으면 null (키 자체를 빼지 않는다) |
| `name` | String | |
| `price` | Integer | |
| `selected` | Boolean | 이미 체크된 상태로 내려간다 |

`selected` 는 분석·메뉴 조회 응답에만 있다. 주문 요청의 `selectedOptions` 는
고른 것만 담으므로 `{group, name, price}` 세 개다.

### 금액 계산

```
price          메뉴 정가
optionsPrice   체크된 옵션 합계
lineTotal      (price + optionsPrice) × quantity     ← 메뉴 한 줄
itemsTotal     그 가게 lineTotal 합
subtotal       itemsTotal + deliveryFee              ← 그 가게 결제액
totalPrice     subtotal 합                           ← 결제 예상액
```

주문 시점 서버 재계산은 아직 없다. `POST v1/orders` 는 프론트가 보낸 금액을 그대로
저장하고 한 매장인지 검증도 하지 않는다(해커톤 범위 결정). 프론트가 보낸 값이 곧 기록이다.

## 1. POST v1/analyses — 영상 링크 분석

영상 속 매장·메뉴 매칭 + 유사 조합 추천.

### Request

```
POST v1/analyses
Authorization: Bearer {accessToken}
```

| 필드 | 타입 | 비고 |
| --- | --- | --- |
| `source.platform` | Enum | `INSTAGRAM` \| `YOUTUBE` |
| `source.url` | String | 원본 링크. 디버깅용 |
| `source.rawText` | String | 캡션 원문. 결과가 이상할 때 재파싱 |
| `extracted.dishes[].name` | String | 필수 |
| `extracted.dishes[].brandName` | String, nullable | 지점명 없이 `교촌치킨`. 영상에 가게가 안 나오면 생략 |
| `extracted.dishes[].restaurantName` | String, nullable | 화면 표시용 |
| `extracted.dishes[].foodCategory` | Enum, nullable | 9개 중 하나 |
| `extracted.dishes[].description` | String | 맛·식감만 한 줄 30~50자. 홍보 문구 금지 |
| `extracted.dishes[].options` | List\<String\> | 영상에서 들린 말 그대로. 정규화하지 않음 |
| `extracted.keywords` | List\<String\> | 검색 보조. 당분간 미사용 |
| `preferences.maxSpiceLevel` | Enum, nullable | `NONE` \| `MEDIUM` \| `HOT` |
| `preferences.maxDeliveryMin` | Integer, nullable | |
| `preferences.excludeMeat` | Boolean | 기본 false |

**브랜드는 영상 전체가 아니라 메뉴마다 붙는다.** 엽떡 떡볶이 + 명랑핫도그처럼 두
가게가 나오는 영상이 있기 때문. 전부 같은 브랜드면 같은 값이 반복될 뿐이다.

```json
{
  "source": {
    "platform": "INSTAGRAM",
    "url": "https://www.instagram.com/p/xxxxx/",
    "rawText": "엽떡에 분모자 넣고 명랑핫도그까지 #성수맛집"
  },
  "extracted": {
    "dishes": [
      {
        "name": "오리지널 떡볶이",
        "brandName": "엽기떡볶이",
        "restaurantName": "엽기떡볶이 강남점",
        "foodCategory": "SNACK",
        "description": "쫄깃한 밀떡에 매운 양념을 넉넉히 버무린 떡볶이",
        "options": ["분모자 넣어서"]
      },
      {
        "name": "핫도그",
        "brandName": "명랑핫도그",
        "restaurantName": "명랑핫도그 강남점",
        "foodCategory": "SNACK",
        "description": "바삭한 반죽에 소시지를 감싸 튀긴 핫도그",
        "options": []
      }
    ],
    "keywords": ["떡볶이", "핫도그", "분모자"]
  },
  "preferences": {
    "maxSpiceLevel": "MEDIUM",
    "maxDeliveryMin": 35,
    "excludeMeat": false
  }
}
```

### Response `200 OK`

설명용 필드는 담지 않는다. 화면에 그릴 값만 보낸다.

```
exactMatches : List   영상에 나온 브랜드. 브랜드 수만큼. 없으면 []
  brandName  : String        어느 브랜드 결과인지
  restaurant : Object
  items      : List          그 브랜드에 속한 메뉴만
  totalPrice : Integer       lineTotal 합. **배달비 미포함**

dishResults : List    요리 하나당 하나. 요리별 후보 가게 목록
  dishName   : String        요청의 dishes[].name 그대로
  candidates : List          score 내림차순, 최대 5곳. 없으면 []
    restaurant : Object
    item       : Object      그 가게에서 이 요리에 가장 가까운 메뉴 하나
    score      : Double      유사도 × 0.9 + 옵션 일치 비율 × 0.1
```

`brandName` 이 있어야 `exactMatches` 에 실린다. null 이면 그 요리는 `dishResults`
로만 나간다. 브랜드가 반경 안에 여러 지점이면 가장 가까운 지점 하나만 실리고,
`exactMatches` 에 실린 **지점**은 `candidates` 에서 빠진다(같은 브랜드의 다른
지점은 남는다).

### 가게 단위로 묶어 주지 않는다 — 묶는 건 앱의 몫이다

떡볶이와 치킨을 한 집에서 파는 가게가 거의 없어서, 서버가 "한 집에서 조합 전체"
로 묶으면 대부분 빈 결과가 된다. 결제도 어차피 가게별로 쪼개져 `checkoutId` 로
묶이므로 이 구조가 제품과 맞다.

**한 집에서 다 시킬 수 있는지는 프론트가 판단한다.** 같은 `restaurantId` 가 여러
요리의 `candidates` 에 모두 나오면 그 집에서 다 된다는 뜻이고, 그러면 배달비가 한
번만 든다. 앱은 `AnalysisResult.combos` 에서 후보를 가게 단위로 묶고, 많이 커버하는
집을 앞에 놓는다(같은 개수면 점수 평균 순).

### 금액

```
price          메뉴 정가
optionsPrice   켜진 옵션 합계
lineTotal      (price + optionsPrice) × quantity
totalPrice     lineTotal 합            ← 배달비는 안 들어간다
```

배달비는 `restaurant.deliveryFee` 에 따로 있고 결제 화면에서 프론트가 더해 그린다.

**주문 시점 서버 재계산은 아직 없다.** `POST v1/orders` 는 프론트가 보낸 금액을
그대로 저장하고, 한 매장인지 검증도 하지 않는다(해커톤 범위 결정). 그래서 "프론트
금액은 믿지 않는다" 는 더 이상 사실이 아니다 — 지금은 프론트가 보낸 값이 곧 기록이다.

### item 의 options

**빈 배열이어도 "옵션 변경" 버튼을 숨기면 안 된다.** 그 메뉴에 옵션이 없다는 뜻이
아니라 영상에서 언급된 것이 없다는 뜻이다. 전체 선택지는
`GET v1/restaurants/{restaurantId}/menus` 로 받는다.

### 못 찾았을 때

- 못 찾은 메뉴는 `items` 에서 그냥 빠진다. 별도 안내 필드 없음
- 유사도·매칭근거는 순위 계산에만 쓰고 응답에 안 담는다
- 결과가 0개면 에러가 아니라 `200` 으로 빈 배열: `{ "exactMatches": [], "dishResults": [] }`

## 2. GET v1/restaurants/{restaurantId}/menus — 식당 전체 메뉴

분석 결과 화면에서 '메뉴 수정하기' 를 눌렀을 때 쓴다. 읽기 전용, 본문 없음.

```
GET v1/restaurants/101/menus
Authorization: Bearer {accessToken}
```

### Response `200 OK`

```
restaurant : Object      (공용 오브젝트와 동일)
menus : List
  menuId          : Long
  name            : String
  menuType        : Enum (MAIN | SIDE | DRINK)
  description     : String   맛·식감 한 줄
  price           : Integer
  imageUrl        : String
  spiceLevel      : Enum (NONE | MEDIUM | HOT)
  spiceAdjustable : Boolean
  options         : List ({group, name, price})
```

분석 응답의 `items` 와 다른 점:

1. `quantity` · `selectedSpice` · `selected` 가 없다 — 사용자가 직접 고르는
   화면이므로 전부 프론트에서 채운다
2. `description` 이 있다 — 처음 보는 메뉴를 고르는 화면이라 "이게 뭐지" 를 알려줘야 한다
3. 정렬되어 나간다 — `MAIN → SIDE → DRINK`, 같은 타입 안에서는 `menuId` 순.
   프론트는 이 순서대로 섹션을 나눠 그리면 된다

메뉴는 SIDE·DRINK 도 자기 행을 가진다. 사이드를 옵션으로 넣지 않은 이유가 이
화면이다 — 여기서 따로 골라 담으면 된다.

`404` 는 그 `restaurantId` 가 없을 때만 낸다. 배달권역 밖이라도 `200`.

### 실제 응답에 `restaurant` 가 없다 (2026-08-08 확인) — 백엔드 확인 중

```
문서 : { restaurant: {...위 공용 오브젝트 10개 필드}, menus[] }
서버 : { restaurantId, restaurantName, menus[] }
```

`menus[]` 항목은 문서와 정확히 일치한다. 빠진 것은 매장 블록뿐이다.
`RestaurantMenus.fromJson` 이 `json['restaurant']` 를 읽으므로 빈 객체가 되고,
평점 · 배달비 · 최소 주문 금액이 전부 0 으로 보인다. "다시 주문" 이 매장 정보를
다시 채우는 경로(`AppFlow.reorderFromHistory`)도 같은 값을 쓴다.

## 3. GET v1/orders — 내 결제 목록

```
GET v1/orders?size=20
Authorization: Bearer {accessToken}
```

Query: `cursor` String (선택), `size` Integer (기본 20)

### Response `200 OK`

```json
{
  "orders": [
    {
      "checkoutId": 7002,
      "orderedAt": "2026-08-04T19:22:10+09:00",
      "source": {
        "platform": "INSTAGRAM",
        "url": "https://www.instagram.com/p/xxxxx/",
        "thumbnailUrl": "https://.../og-image.jpg",
        "title": "엽떡에 교촌 말아먹기"
      },
      "restaurantNames": ["엽기떡볶이 성수점", "교촌치킨 성수점"],
      "totalPrice": 50000
    },
    {
      "checkoutId": 7001,
      "orderedAt": "2026-08-02T12:10:03+09:00",
      "source": {
        "platform": "YOUTUBE",
        "url": "https://www.youtube.com/watch?v=yyyyy",
        "thumbnailUrl": "https://.../yt-thumb.jpg",
        "title": "신전떡볶이 순한맛 먹방"
      },
      "restaurantNames": ["신전떡볶이 성수점"],
      "totalPrice": 12500
    }
  ],
  "nextCursor": null
}
```

카드 하나 = 결제 하나 = 영상 하나. 서버가 `checkout_id` 로 묶어서 내려준다.
프론트는 받은 대로 그린다. `stores` 구조는 결제 요청과 같은 모양이라 변환할 것이 없다.

## 4. GET v1/orders/{checkoutId} — 결제 내역 상세

```
GET v1/orders/7002
Authorization: Bearer {accessToken}
```

### Response `200 OK`

```
checkoutId : Long
orderedAt  : DateTime
source     : { platform, url, thumbnailUrl, title }
stores : List
  restaurantId   : Long
  restaurantName : String
  deliveryFee    : Integer
  items : List
    menuId          : Long
    menuName        : String
    unitPrice       : Integer
    quantity        : Integer
    selectedSpice   : Enum, nullable
    selectedOptions : List ({group, name, price})
    optionsPrice    : Integer
    lineTotal       : Integer
  itemsTotal : Integer
  subtotal   : Integer
totalPrice : Integer
```

주문 상세의 `items` 는 분석 응답과 필드명이 다르다 — `name` → `menuName`,
`price` → `unitPrice`, `imageUrl` → `menuImageUrl`. 주문 요청과 같은 모양이고,
`menuImageUrl` 만 응답에 더 붙는다(요청에는 없다).

## 5. POST v1/orders — 결제하기 (장바구니 → 주문 생성)

프론트가 장바구니에서 결제로 보낸다. **가게가 여러 곳이어도 요청은 한 번이다.**

```
POST v1/orders
Authorization: Bearer {accessToken}
```

### Request Body

```
source.platform     : Enum (INSTAGRAM | YOUTUBE)
source.url          : String   영상 링크
source.thumbnailUrl : String   사진
source.title        : String   영상 제목

stores : List (가게가 여러 곳이면 여러 개)
  restaurantId   : Long
  restaurantName : String
  deliveryFee    : Integer      그 가게 배달비
  items : List
    menuId          : Long
    menuName        : String
    unitPrice       : Integer
    quantity        : Integer
    selectedSpice   : Enum (nullable)
    selectedOptions : List ({group, name, price})
    optionsPrice    : Integer
    lineTotal       : Integer
  itemsTotal : Integer          그 가게 메뉴 + 옵션 합
  subtotal   : Integer          itemsTotal + deliveryFee = 그 주문의 결제액
```

`selectedOptions` 규칙:

- 고른 것만 담는다. 안 고른 옵션은 보내지 않는다
- `group` 은 없으면 `null`. 키 자체를 빼지 않는다
- `menu.options` 와 같은 모양이라 프론트가 변환할 것이 없다

**전체 합계는 보내지 않는다.** 주문이 가게 단위로 쪼개져 저장되므로 전체 합계를
넣어둘 자리가 없다. 장바구니 화면 총액은 프론트가 `subtotal` 을 더해 그린다.

실제 결제(PG)는 붙이지 않는다. 주문 기록만 남기는 상황.

### Response `201 CREATED`

가게 이름만 돌려준다.

```json
{ "restaurantNames": ["엽기떡볶이 성수점", "교촌치킨 성수점"] }
```

- 요청 내용을 되돌려주지 않는다. 프론트가 방금 보낸 값이라 쓸 데가 없다
- 건수를 따로 주지 않는다. `restaurantNames.length` 가 곳 건수다
- `orderId` 도 주지 않는다. 완료 화면에서 "주문 내역 보기" 로 목록에 가는 흐름이면
  필요가 없다. 주문이 2건이면 특정 상세로 바로 갈 수도 없다

완료 화면은 이렇게 그린다.

```
주문이 접수되었습니다
2건 · 엽기떡볶이 성수점, 교촌치킨 성수점
```

엽떡 + 명랑핫도그를 한 번에 결제하면 행이 2개 생기고 두 행의 `checkout_id` 가
같다. 배달은 따로 가지만 "한 영상 보고 한 번에 시킨 것" 이라는 사실이 남는다.

API 에 나가는 `orderId` 는 `checkout_id` 다. DB 의 `order_id` 는 내부 저장용이라
밖으로 노출되지 않는다.

## 6. Users

| 권한 | Method | 기능 | End Point |
| --- | --- | --- | --- |
| ALL | POST | 로그인 | `v1/users/login` |
| ALL | POST | 회원가입 | `v1/users/signup` |
| ALL | POST | 토큰 재발급 | `v1/users/reissue-token` |
| USER | POST | 로그아웃 | `v1/users/logout` |
| USER | GET | 내 정보 조회 | `v1/users/me` |
| USER | PATCH | 내 정보 수정 | `v1/users/me` |
| USER | GET | 내가 쓴 요기족보 글 목록 | `v1/users/me/posts` |
| USER | GET | 내 주문 내역 조회 | `v1/users/me/orders` |

### POST v1/users/login

Request `{ "email": "...", "password": "..." }`

Response `accessToken`, `refreshToken`, `user.userId`(UUID), `user.nickname`,
`user.profileImageUrl`. 실패는 `401 U001`.

### POST v1/users/signup

Request `{ email, password, nickName }` → `accessToken`, `refreshToken`.
`409 U002` 이메일 중복. 시연에서는 노출하지 않는다.

### POST v1/users/reissue-token

Request `{ refreshToken }` → `accessToken`.
`accessToken` 만료 24h 로 두고 미구현 가능.

### POST v1/users/logout

`204 No Content`. 클라이언트 토큰 삭제로 대체 가능.

### GET / PATCH v1/users/me

- GET → `userId`(UUID), `email`, `nickname`, `profileImageUrl`, `createdAt`
- PATCH ← `{ nickname, profileImageUrl }`

### GET v1/users/me/posts

`?cursor={cursor}&size=10` → `{ items[] (v1/posts 응답의 items[] 와 동일 구조), nextCursor }`

### GET v1/users/me/orders

`?cursor={cursor}&size=10`

```
items[].orderId         : UUID
items[].storeName       : String
items[].thumbnailUrl    : String
items[].sourceVideoTitle: String
items[].totalPrice      : Integer
items[].menuSummary     : String
items[].orderedAt       : DateTime
items[].isPostedToJokbo : Boolean
nextCursor              : String (다음 페이지 없으면 null)
```

요기족보 인증글 작성 진입점.

## 7. DB 스키마 중 프론트가 아는 것

### food_category — 이 9개만

`CHICKEN` `SNACK` `KOREAN` `CHINESE` `JAPANESE` `WESTERN` `PIZZA` `ASIAN` `CAFE_DESSERT`

다른 값은 `INSERT` 가 거절된다. 프론트도 이 9개 밖의 값을 만들지 않는다.

### menu_type

`MAIN` `SIDE` `DRINK` — 기본값 `MAIN`.

### spice_level

`NONE` `MEDIUM` `HOT` — `NULL` 을 허용하지 않는다. 맵지 않은 메뉴도 `NONE`.
가상 컬럼 `spice_rank` 가 `NONE=0, MEDIUM=1, HOT=2` 로 자동 계산된다.

`spice_adjustable` 은 `Y`/`N` — 주문 시 맵기 조절 가능 여부.

### restaurant 테이블

`restaurant_id`(PK) `name` `brand_code`(대문자) `brand_name`(지점명 제외)
`branch_name` `food_category` `area` `sigungu` `address` `lat` `lng` `rating`
`review_count` `min_order_price` `delivery_fee` `delivery_min` `prep_min` `image_url`

`brand_name` 이 영상 매칭용 정제 브랜드명이다 — 앱이 `extracted.dishes[].brandName`
에 지점명을 붙이면 매칭이 깨진다.

`etaMin` = 이동시간 + `prep_min`, `delivery_min` 은 배달 시간 필터용.

### menu 테이블

`menu_id`(PK) `restaurant_id`(FK) `name` `menu_type` `aliases` `description`
`price` `spice_level` `spice_adjustable` `spice_rank`(가상) `is_healthy`
`has_meat` `taste_tags` `image_url` `options`(JSON 배열) `embed_text`(자동)
`embedding`(VECTOR(1536), 자동)

`aliases` 는 줄임말·별칭(`황올,고바사`). 먹방·숏폼이 정식 메뉴명 대신 별칭을 쓰기
때문에 매칭률을 올리는 데 쓴다. `options` 는 사리·토핑·소스만 저장하며 없으면 `NULL`.

## 확인 필요 항목

| 항목 | 내용 |
| --- | --- |
| 주문 목록이 두 벌 | `GET v1/orders` (checkoutId · restaurantNames) 와 `GET v1/users/me/orders` (orderId · storeName 단일)가 서로 다른 모양이다. 다중 매장을 담는 건 앞쪽뿐이라 앱은 `GET v1/orders` 를 쓴다. 뒤쪽은 폐기인지 확인 필요 |
| `isPostedToJokbo` | `v1/users/me/orders` 에만 있다. `GET v1/orders` 에는 없어 "이미 족보에 공유했는지" 를 결제 목록에서 알 수 없다 |
| `reviewCount` | 응답에 없다. 시안은 평점 옆에 리뷰 수를 보여준다 |
| 요기족보 다중 매장 | `api-yogijokbo.md` 는 아직 단일 매장(`combo.store`)이다. `stores[]` 로 바뀌는지, 그 모양이 주문 상세와 같은지 확인 필요 |
| 결제 완료 후 이동 | `orderId` 를 주지 않으므로 완료 화면은 목록으로만 갈 수 있다. 상세로 보내려면 `orderIds` 추가 필요 |
| **`GET v1/orders` 에 `menuSummary` 추가** | 시안 857:4509 가 카드에 `[지점명] 메뉴, 메뉴` 와 "N개 매장 · 총 N개 메뉴" 를 그린다. 목록 응답에는 `restaurantNames` 와 `totalPrice` 뿐이라 메뉴 이름을 알 수 없고, 카드마다 상세를 더 부르는 건 "목록에는 조합 전체를 내리지 않는다" 는 명세와 충돌한다. 필요한 모양: `menuSummary: [{ storeName, menuNames[] }]`. 앱 모델(`OrderSummary.menuSummary`)은 이미 이 키를 읽고, 없으면 그 줄을 그리지 않는다 |
| `INSTAGRAM`/`YOUTUBE` 외 링크 | `source.platform` 이 두 값뿐이다. 앱은 그 밖의 링크를 분석 전에 막는다 |
