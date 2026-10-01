import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/bgms_theme.dart';

/// 검색 입력 아래에 뜨는 닉네임 후보 목록.
///
/// 후보를 누르면 저장된 플랫폼까지 함께 전달해 잘못된 플랫폼으로
/// 검색하는 실수를 막는다.
class PlayerSuggestionList extends StatelessWidget {
  const PlayerSuggestionList({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.loading = false,
  });

  final List<PlayerSuggestion> suggestions;
  final void Function(PlayerSuggestion suggestion) onSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BgmsColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < suggestions.length; index++)
              _SuggestionRow(
                suggestion: suggestions[index],
                isLast: index == suggestions.length - 1,
                onTap: () => onSelected(suggestions[index]),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.isLast,
    required this.onTap,
  });

  final PlayerSuggestion suggestion;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: BgmsColors.border)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_search,
              size: 18,
              color: BgmsColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                suggestion.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BgmsColors.elevated,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: BgmsColors.border),
              ),
              child: Text(
                suggestion.platform,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BgmsColors.textMuted,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
