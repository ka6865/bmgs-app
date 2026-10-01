import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';

class WeaponMetaScreen extends StatefulWidget {
  const WeaponMetaScreen({super.key, this.client});
  final BgmsApiClient? client;
  @override
  State<WeaponMetaScreen> createState() => _WeaponMetaScreenState();
}

class _WeaponMetaScreenState extends State<WeaponMetaScreen> {
  late final _client =
      widget.client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);
  late Future<Map<String, dynamic>> _future;
  String _matchType = 'all';
  String? _patch;
  String _category = '전체';
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = _client.fetchWeaponMeta(matchType: _matchType, patch: _patch);
  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('총기 메타')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        final weapons =
            (data?['weapons'] is List ? data!['weapons'] as List : const [])
                .whereType<Map>()
                .toList();
        final patches =
            (data?['patches'] is List ? data!['patches'] as List : const [])
                .whereType<Map>()
                .map((row) => row['version']?.toString())
                .whereType<String>()
                .toSet();
        final patch = _patch ?? data?['patchVersion']?.toString();
        final categories = {
          '전체',
          ...weapons.map((w) => w['weapon_category']?.toString() ?? '기타'),
        };
        final filtered = weapons.where(
          (w) => _category == '전체' || w['weapon_category'] == _category,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('BGMS에서 수집한 분석 경기의 패치 전후 기록입니다. 전체 PUBG 사용자 통계가 아닙니다.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in const {
                  'all': '전체',
                  'official': '일반전',
                  'competitive': '경쟁전',
                }.entries)
                  ChoiceChip(
                    label: Text(choice.value),
                    selected: choice.key == _matchType,
                    onSelected: (value) {
                      if (value) {
                        setState(() {
                          _matchType = choice.key;
                          _category = '전체';
                          _load();
                        });
                      }
                    },
                  ),
              ],
            ),
            if (patches.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: patches.contains(patch) ? patch : null,
                key: ValueKey(patch),
                decoration: const InputDecoration(labelText: '패치'),
                items: [
                  for (final version in patches)
                    DropdownMenuItem(value: version, child: Text(version)),
                ],
                onChanged: (value) => setState(() {
                  _patch = value;
                  _load();
                }),
              ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (snapshot.hasError || data?['success'] == false) ...[
              Text(
                snapshot.hasError
                    ? ApiException.from(snapshot.error!).message
                    : data?['message']?.toString() ?? '집계가 준비되지 않았습니다.',
              ),
              TextButton(onPressed: _refresh, child: const Text('다시 불러오기')),
            ] else ...[
              if (data?['message'] != null) Text(data!['message'].toString()),
              if (weapons.isEmpty) const Text('표시할 총기 표본이 없습니다.'),
              if (categories.length > 1)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final category in categories)
                      FilterChip(
                        label: Text(category),
                        selected: category == _category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                  ],
                ),
              for (final weapon in filtered)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weapon['weapon_name']?.toString() ?? '총기',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(1.5),
                          },
                          children: [
                            const TableRow(
                              children: [
                                Text('지표'),
                                Text('패치 전'),
                                Text('패치 후'),
                              ],
                            ),
                            for (final metric in const {
                              'pick_share': '선택 비율',
                              'avg_damage': '평균 딜량',
                              'kill_efficiency': '처치 효율',
                              'sustained_hits': '연속 명중',
                            }.entries)
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(metric.value),
                                  ),
                                  Text(
                                    metaMetric(weapon['pre_patch'], metric.key),
                                  ),
                                  Text(
                                    metaMetric(
                                      weapon['post_patch'],
                                      metric.key,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '선택 비율 표본: 전 ${_sample(weapon['pre_patch'])} · 후 ${_sample(weapon['post_patch'])} 경기',
                        ),
                        const Text('연속 명중은 해당 구간 표본 20개 이상일 때 표시합니다.'),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

String _sample(Object? raw) =>
    raw is Map ? raw['match_count']?.toString() ?? '-' : '-';

String metaMetric(Object? raw, String key) {
  if (raw is! Map ||
      raw['match_count'] is! num ||
      (raw['match_count'] as num) <= 0) {
    return '-';
  }
  if (key == 'sustained_hits' && raw['burst_available'] != true) return '표본 부족';
  if (key != 'pick_share' &&
      raw['active_pick_count'] is num &&
      (raw['active_pick_count'] as num) <= 0) {
    return '-';
  }
  final value = raw[key];
  if (value is! num || !value.isFinite) return '-';
  return key == 'pick_share'
      ? '${value.toStringAsFixed(1)}%'
      : value.toStringAsFixed(
          key == 'sustained_hits' || key == 'kill_efficiency' ? 2 : 0,
        );
}
