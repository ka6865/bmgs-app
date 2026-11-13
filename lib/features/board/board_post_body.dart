import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/bgms_theme.dart';

/// 게시글 본문. HTML이 있으면 웹처럼 제목·목록·카드 구조를 살리고, 없으면 텍스트로 보여준다.
///
/// 이미지는 상세 화면 위쪽에 따로 모아 보여주므로 본문 안에서는 그리지 않는다.
class BoardPostBody extends StatelessWidget {
  const BoardPostBody({super.key, required this.html, required this.text});

  final String? html;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55);
    final content = html;
    if (content == null) {
      return Text(text.isEmpty ? '내용이 없습니다.' : text, style: style);
    }
    return HtmlWidget(
      content,
      textStyle: style,
      customStylesBuilder: _boardStyles,
      customWidgetBuilder: (element) =>
          element.localName == 'img' ? const SizedBox.shrink() : null,
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null || uri.scheme != 'https') return true;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      },
    );
  }
}

/// 웹 글은 Tailwind 클래스로 꾸며져 있어, 자주 쓰는 클래스만 앱 색으로 옮긴다.
// 타입 별칭으로 받아야 html 패키지(dom.Element)를 직접 의존하지 않는다.
// ignore: prefer_function_declarations_over_variables
final CustomStylesBuilder _boardStyles = (element) {
  final tag = element.localName;
  final classes = element.className;
  final css = <String, String>{};
  if (classes.contains('bg-[#F2A900]')) {
    css.addAll({
      'background-color': 'rgba(242,169,0,0.10)',
      'border-left': '3px solid #F2A900',
      'padding': '10px 12px',
      'margin': '0 0 12px 0',
    });
  } else if (classes.contains('bg-[#1a1a1a]')) {
    css.addAll({
      'background-color': _hex(BgmsColors.elevated),
      'padding': '12px',
      'margin': '0 0 10px 0',
    });
  }
  if (classes.contains('border-b')) {
    css.addAll({
      'border-bottom': '1px solid rgba(255,255,255,0.10)',
      'padding-bottom': '6px',
      'margin-bottom': '8px',
    });
  }
  if (classes.contains('text-[#F2A900]')) css['color'] = '#F2A900';
  if (classes.contains('font-black')) css['font-weight'] = '800';
  if (classes.contains('list-none')) {
    css.addAll({'list-style-type': 'none', 'margin-bottom': '6px'});
  }
  if (tag == 'ul') css.addAll({'padding-left': '0', 'margin': '0'});
  if (tag == 'h3' || tag == 'h2') css['margin'] = '0';
  if (tag == 'a') css['color'] = '#F2A900';
  // 체크 표시는 웹에서 absolute로 띄우므로 앱에서는 글자 앞 간격만 준다.
  if (classes.contains('absolute')) css['margin-right'] = '6px';
  return css.isEmpty ? null : css;
};

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
