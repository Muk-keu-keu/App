import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/user_location.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 위치 권한을 거부했을 때 주소를 직접 입력받는 시트.
///
/// 전체 화면(AppStage)이 아니라 시트로 만든 이유 — 위치는 흐름을 막는 단계가 아니라
/// 보조 입력이다. 기존 필터·메뉴수정 시트와 같은 방식이라 코드도 그 패턴을 따른다.
///
/// 좌표 → 주소 변환은 서버가 하는 것으로 가정하므로, 여기서 받은 문자열은 그대로
/// 서버에 넘어간다. 앱은 주소를 좌표로 바꾸지 않는다.
class AddressInputSheet extends StatefulWidget {
  const AddressInputSheet({super.key});

  /// 어디서든 같은 모양으로 띄우기 위한 헬퍼.
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddressInputSheet(),
      );

  @override
  State<AddressInputSheet> createState() => _AddressInputSheetState();
}

class _AddressInputSheetState extends State<AddressInputSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 이미 입력한 주소가 있으면 고쳐 쓸 수 있게 채워 둔다.
    final current = context.read<AppFlow>().location;
    if (current != null && current.hasAddress) _controller.text = current.address;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    context.read<AppFlow>().setManualAddress(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Padding(
      // 키보드가 올라올 때 입력창이 가려지지 않게 한다.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('주소를 입력해 주세요', style: AppText.semiBold(20, spacing: -0.5)),
              const SizedBox(height: 8),
              Text(
                _guideText(flow),
                style: AppText.regular(14, spacing: -0.35, color: AppColors.gray700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: AppText.regular(16, spacing: -0.4),
                decoration: InputDecoration(
                  hintText: '예) 서울 송파구 잠실동 40-1',
                  hintStyle: AppText.regular(16, spacing: -0.4, color: AppColors.gray500),
                  filled: true,
                  fillColor: AppColors.gray200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              // 영구 거부가 아니라면 다시 시도해 볼 여지가 있다.
              if (!flow.needsAddressInput || flow.locationFailure == null)
                _retryButton(context, flow)
              else
                const SizedBox.shrink(),
              if (kDebugMode) _debugPresets(context),
              const SizedBox(height: 12),
              PrimaryButton(label: '이 주소로 할게요', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  String _guideText(AppFlow flow) => switch (flow.locationFailure) {
        LocationFailure.serviceDisabled =>
          '기기의 위치 서비스가 꺼져 있어요. 주소를 입력하면 그 주변으로 찾아드려요.',
        LocationFailure.deniedForever =>
          '위치 권한이 꺼져 있어요. 설정에서 바꿀 수도 있고, 주소를 직접 입력해도 돼요.',
        _ => '위치를 쓰지 않아도 괜찮아요. 배달받을 주소를 알려주시면 그 주변으로 찾아드려요.',
      };

  Widget _retryButton(BuildContext context, AppFlow flow) => GestureDetector(
        onTap: flow.isLocating ? null : () => context.read<AppFlow>().refreshLocation(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gray200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            flow.isLocating ? '위치 확인 중…' : '현재 위치 다시 시도',
            style: AppText.semiBold(14, spacing: -0.35, color: AppColors.gray800),
          ),
        ),
      );

  /// 디버그 빌드 전용 좌표 override.
  ///
  /// 시연 더미 데이터가 강남·용산 기준인데 리허설을 다른 곳에서 하면 화면이 비어
  /// 보인다. 재빌드 없이 즉시 바꿀 수 있어야 해서 UI 로 뒀다.
  /// `kDebugMode` 가 컴파일 타임 상수라 릴리즈 빌드에서는 이 위젯 자체가 빠진다.
  Widget _debugPresets(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEBUG · 위치 지정 (릴리즈 빌드에는 없음)',
                style: AppText.semiBold(12, spacing: -0.3, color: AppColors.gray600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in UserLocation.debugPresets.entries)
                    GestureDetector(
                      onTap: () {
                        context.read<AppFlow>().applyDebugLocation(entry.value);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gray400),
                        ),
                        child: Text(
                          entry.key,
                          style: AppText.medium(13, spacing: -0.3, color: AppColors.gray800),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}
