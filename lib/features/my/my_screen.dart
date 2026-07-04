import 'package:flutter/material.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '마이',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('로그인 준비 상태'),
                SizedBox(height: 8),
                Text('Supabase URL과 anon key가 설정되면 Auth를 연결합니다.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대표 닉네임'),
                SizedBox(height: 8),
                Text('최근 검색과 즐겨찾기 저장소를 이 화면에서 관리합니다.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
