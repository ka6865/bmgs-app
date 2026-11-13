import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';

/// 도감 탭. 무기·맵·아이템 정보를 게임하면서 바로 찾을 수 있게 묶는다.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(String path) => context.push(path);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const ScreenHeader(title: '도감'),
        const SizedBox(height: BgmsSpacing.xl),
        GroupedList(
          title: '무기',
          children: [
            GroupedRow(
              icon: Icons.track_changes,
              title: '무기 도감',
              subtitle: '총기별 피해·탄속·탄약과 두 무기 비교',
              onTap: () => open('/tools/weapons'),
            ),
            GroupedRow(
              icon: Icons.trending_up,
              title: '총기 메타',
              subtitle: '패치 전후 많이 쓰는 총과 성과',
              onTap: () => open('/meta'),
            ),
          ],
        ),
        const SizedBox(height: BgmsSpacing.xl),
        GroupedList(
          title: '맵',
          children: [
            GroupedRow(
              icon: Icons.local_fire_department_outlined,
              title: '핫드랍 지도',
              subtitle: '맵별로 많이 내리는 지점',
              onTap: () => open('/hotdrop'),
            ),
          ],
        ),
        const SizedBox(height: BgmsSpacing.xl),
        GroupedList(
          title: '아이템',
          children: [
            GroupedRow(
              icon: Icons.inventory_2_outlined,
              title: '상자깡 시뮬',
              subtitle: '공식 확률로 상자 열어 보기',
              onTap: () => open('/crates'),
            ),
          ],
        ),
      ],
    );
  }
}
