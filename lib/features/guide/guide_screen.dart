import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BGMS 도구')),
    body: ListView(
      children: [
        for (final item in const [
          (
            path: '/tools/weapons',
            title: '무기 도감·비교',
            body: '무기 DB의 기본 수치 확인',
            icon: Icons.track_changes,
          ),
          (
            path: '/tools/backpack',
            title: '가방 계산',
            body: '가방·조끼·차량의 용량과 수량 계산',
            icon: Icons.backpack_outlined,
          ),
          (
            path: '/meta',
            title: '총기 메타',
            body: '패치 전후 선택 비율과 성과 표본',
            icon: Icons.trending_up,
          ),
          (
            path: '/hotdrop',
            title: '핫드랍 지도',
            body: 'DB 착지 표본의 밀도 확인',
            icon: Icons.local_fire_department_outlined,
          ),
          (
            path: '/support',
            title: '고객센터',
            body: 'FAQ 검색과 내 문의·답변',
            icon: Icons.support_agent,
          ),
          (
            path: '/crates',
            title: '상자깡 시뮬',
            body: '웹 DB의 기본 드롭 그룹 추첨',
            icon: Icons.inventory_2_outlined,
          ),
        ])
          ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: Text(item.body),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(item.path),
          ),
      ],
    ),
  );
}
