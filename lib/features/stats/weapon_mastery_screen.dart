import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/cached_image.dart';
import 'weapon_mastery_models.dart';
import 'weapon_mastery_repository.dart';

class WeaponMasteryScreen extends StatefulWidget {
  const WeaponMasteryScreen({
    super.key,
    required this.nickname,
    required this.platform,
    this.repository,
  });
  final String nickname;
  final String platform;
  final WeaponMasteryRepository? repository;
  @override
  State<WeaponMasteryScreen> createState() => _WeaponMasteryScreenState();
}

class _WeaponMasteryScreenState extends State<WeaponMasteryScreen> {
  late final WeaponMasteryRepository _repository;
  List<WeaponMasteryItem> _items = const [];
  DateTime? _savedAt;
  bool _loading = false;
  bool _loadingCache = true;
  String? _message;
  String _category = '전체';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WeaponMasteryRepository();
    _loadCache();
  }

  /// 기기에 저장한 마지막 결과를 먼저 보여준다. 서버·PUBG 호출은 갱신 버튼에서만 한다.
  Future<void> _loadCache() async {
    final snapshot = await _repository.cached(
      nickname: widget.nickname,
      platform: widget.platform,
    );
    if (!mounted) return;
    setState(() {
      _loadingCache = false;
      if (snapshot != null) {
        _items = snapshot.items;
        _savedAt = snapshot.savedAt;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final snapshot = await _repository.refresh(
        nickname: widget.nickname,
        platform: widget.platform,
      );
      if (mounted) {
        setState(() {
          _items = snapshot.items;
          _savedAt = snapshot.savedAt;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = ApiException.from(error).message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ['전체', ..._items.map((item) => item.category).toSet()];
    final visible = _items
        .where((item) => _category == '전체' || item.category == _category)
        .toList();
    final saved = _savedAt?.toLocal();

    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: AppBar(
        backgroundColor: BgmsColors.bgBase,
        title: const Text('무기 숙련도'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            tooltip: '무기 숙련도 갱신',
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            saved == null
                ? '오른쪽 위 새로고침을 누르면 PUBG에서 숙련도를 가져와 이 기기에 저장합니다.'
                : '${saved.month}월 ${saved.day}일 '
                      '${saved.hour.toString().padLeft(2, '0')}:'
                      '${saved.minute.toString().padLeft(2, '0')} 갱신 · '
                      '새로고침을 누를 때만 최신으로 바꿉니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BgmsColors.textMuted,
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                style: const TextStyle(color: BgmsColors.danger),
              ),
            ),
          if (_items.isEmpty && !_loading && !_loadingCache)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('무기 숙련도 불러오기'),
                ),
              ),
            ),
          if (_items.length > 1 && categories.length > 2) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    label: Text(category),
                    selected: category == _category,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final (index, item) in visible.indexed)
            _MasteryRow(item: item, top: index == 0 && _category == '전체'),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.item, required this.top});

  final WeaponMasteryItem item;

  /// 가장 많이 쓴 무기는 골드 테두리로 강조한다.
  final bool top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: BgmsColors.surface,
        shape: BgmsShape.panel(
          side: BorderSide(color: top ? BgmsColors.accent : BgmsColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 48,
                child: Image(
                  image: cachedImageProvider(item.imageUrl),
                  fit: BoxFit.contain,
                  semanticLabel: item.label,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.gps_fixed, color: BgmsColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${item.category} · ${item.totalKills}킬 · '
                      '${item.totalDamage.toStringAsFixed(0)} 딜',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: BgmsColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.level}',
                    style: BgmsText.number(
                      26,
                      color: top ? BgmsColors.accent : BgmsColors.textPrimary,
                    ),
                  ),
                  Text(
                    '레벨',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BgmsColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
