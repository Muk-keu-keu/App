import 'package:flutter/material.dart';

import '../models/combo.dart';
import '../theme.dart';
import 'common.dart';

/// 주문한 조합을 보여주는 매장 카드 (시안 857:5184 · 902:1333).
///
/// 족보의 "주문한 메뉴" 시트와 주문내역 상세가 같은 모양을 쓴다. 두 화면이
/// 각자 그리면 한쪽만 시안이 바뀌었을 때 조용히 갈라진다 — 실제로 상세는
/// 평평한 목록, 시트는 카드로 서로 다르게 그려지고 있었다.
///
/// 배달이 매장 단위로 따로 가므로 카드도 매장 단위다. 목록을 한 줄로 이어
/// 붙이면 어디까지가 한 가게인지 읽히지 않는다.
class OrderedStoreCard extends StatelessWidget {
  const OrderedStoreCard({
    super.key,
    required this.storeName,
    required this.lines,
    this.logoUrl,
    this.logoAsset,
  });

  final String storeName;
  final List<CartLine> lines;

  /// 상호 왼쪽의 32 로고. 없으면 자리만 비운다.
  final String? logoUrl;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 로고가 없으면 자리를 비운다. 주문내역 상세의 `stores[]` 에는
                // 매장 이미지가 없어(id·이름·배달비뿐) 대신 아무 사진이나 넣으면
                // 다른 가게 로고가 붙는다.
                if (logoAsset != null) ...[
                  RemoteOrAssetImage(
                    imageUrl: logoUrl,
                    assetPath: logoAsset!,
                    size: 32,
                    radius: 4,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    storeName,
                    style: AppText.sub1().copyWith(letterSpacing: -0.36),
                  ),
                ),
              ],
            ),
            for (final line in lines) ...[
              const SizedBox(height: 16),
              const DsDividerLine(),
              const SizedBox(height: 16),
              OrderedMenuLine(line: line),
            ],
          ],
        ),
      );
}

/// 카드 안의 메뉴 한 줄. 썸네일 80 · 이름 · 옵션 · 오른쪽 아래 금액과 수량.
///
/// 금액과 수량은 크기·색이 달라 한 덩어리가 아니다 (시안 857:5413 / 857:5415).
class OrderedMenuLine extends StatelessWidget {
  const OrderedMenuLine({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteOrAssetImage(
            imageUrl: line.imageUrl,
            assetPath: line.imagePath,
            size: 80,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: AppText.sub2().copyWith(letterSpacing: -0.32),
                ),
                const SizedBox(height: 4),
                Text(
                  line.optionsText,
                  style: AppText.caption(color: AppColors.gray600),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${wonFormat(line.lineTotal)}원',
                      style: AppText.sub2(color: AppColors.gray800)
                          .copyWith(letterSpacing: -0.32),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${line.quantity}개',
                      style: AppText.body2(color: AppColors.gray600)
                          .copyWith(letterSpacing: -0.28),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}

/// 카드 안에서 쓰는 1px 구분선. `DsDivider` 는 `ds.dart` 에 있는데 이 파일이
/// 그쪽을 끌어오면 순환이 생겨 같은 모양을 여기 둔다.
class DsDividerLine extends StatelessWidget {
  const DsDividerLine({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, width: double.infinity, color: AppColors.gray300);
}
