import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';

/// 웹 주소(bgms.kr)를 시스템 공유 시트로 보낸다. 받는 사람은 앱이 없어도 웹으로 연다.
class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.title, required this.path});

  final String title;

  /// `/stats/steam/닉네임`처럼 웹 경로. 닉네임은 호출 쪽에서 인코딩한다.
  final String path;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '공유',
      icon: const Icon(Icons.ios_share),
      onPressed: () {
        // iPad는 공유 시트를 띄울 기준 위치가 필요하다.
        final box = context.findRenderObject() as RenderBox?;
        SharePlus.instance.share(
          ShareParams(
            text: '$title\n${AppConfig.local.normalizedBaseUrl}$path',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      },
    );
  }
}
