import 'package:flutter/material.dart';

import '../theme/bgms_theme.dart';

/// 검색 바 컨트롤 높이. 접근성 최소 터치 영역(48)을 만족시킨다.
const double _controlHeight = 48;

/// 플레이어 검색 한 줄 바.
///
/// 홈과 전적 탭이 같은 위젯을 공유해 검색 UI가 중복되지 않게 한다.
/// 입력, 플랫폼 토글, 실행 버튼이 한 행에 들어간다.
class PlayerSearchBar extends StatelessWidget {
  const PlayerSearchBar({
    super.key,
    required this.controller,
    required this.platform,
    required this.searching,
    required this.onPlatformChanged,
    required this.onSearch,
    required this.onTextChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String platform;
  final bool searching;
  final String? errorText;
  final ValueChanged<String> onPlatformChanged;
  final VoidCallback onSearch;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              return TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                enabled: !searching,
                onChanged: (_) => onTextChanged(),
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'PUBG 플레이어 검색',
                  hintText: 'KangHeeSung_',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: value.text.isEmpty || searching
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: '입력 지우기',
                          onPressed: () {
                            controller.clear();
                            onTextChanged();
                          },
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        _PlatformToggle(
          platform: platform,
          enabled: !searching,
          onChanged: onPlatformChanged,
        ),
        const SizedBox(width: 8),
        _SearchButton(searching: searching, onSearch: onSearch),
      ],
    );
  }
}

/// 스팀과 카카오를 번갈아 선택하는 소형 토글.
class _PlatformToggle extends StatelessWidget {
  const _PlatformToggle({
    required this.platform,
    required this.enabled,
    required this.onChanged,
  });

  final String platform;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _controlHeight,
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BgmsColors.border),
      ),
      child: Row(
        children: [
          _PlatformChip(
            label: 'Steam',
            value: 'steam',
            selected: platform == 'steam',
            enabled: enabled,
            onChanged: onChanged,
          ),
          _PlatformChip(
            label: 'Kakao',
            value: 'kakao',
            selected: platform == 'kakao',
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$label 플랫폼',
      child: InkWell(
        onTap: enabled ? () => onChanged(value) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: _controlHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? BgmsColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? BgmsColors.bgBase : BgmsColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 검색 실행 버튼. 아이콘만 노출하므로 툴팁으로 용도를 설명한다.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.searching, required this.onSearch});

  final bool searching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '전적 검색',
      child: SizedBox(
        width: _controlHeight,
        height: _controlHeight,
        child: FilledButton(
          key: const Key('player_search_submit'),
          onPressed: searching ? null : onSearch,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward, size: 20),
        ),
      ),
    );
  }
}
