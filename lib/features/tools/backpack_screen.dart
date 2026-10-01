import 'package:flutter/material.dart';

import '../../core/widgets/app_panels.dart';
import 'game_data.dart';

class BackpackScreen extends StatefulWidget {
  const BackpackScreen({
    super.key,
    this.repository = const GameDataRepository(),
  });
  final GameDataRepository repository;
  @override
  State<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends State<BackpackScreen> {
  late Future<BackpackData> _future = widget.repository.fetchBackpackData();
  bool _hasVest = true;
  int _level = 2;
  String? _vehicleId;
  bool _trunk = false;
  String _search = '';
  final Map<String, int> _backpack = {};
  final Map<String, int> _trunkItems = {};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('가방·트렁크 계산')),
    body: FutureBuilder<BackpackData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingCard(lines: 5, label: '아이템 무게를 불러오고 있습니다');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '공개 아이템 데이터를 확인할 수 없습니다. 연결 설정 또는 읽기 권한을 확인한 후 다시 시도하세요.',
              ),
              FilledButton(
                onPressed: () => setState(
                  () => _future = widget.repository.fetchBackpackData(),
                ),
                child: const Text('다시 시도'),
              ),
            ],
          );
        }
        final data = snapshot.data!;
        final vehicle = data.vehicles
            .where((vehicle) => vehicle.id == _vehicleId)
            .firstOrNull;
        final capacity = backpackCapacity(hasVest: _hasVest, level: _level);
        final bagWeight = inventoryWeight(data.items, _backpack);
        final trunkWeight = inventoryWeight(data.items, _trunkItems);
        final quantities = _trunk ? _trunkItems : _backpack;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('공개 아이템 무게로 계산합니다. 무게가 없는 항목은 제외됩니다.'),
            SwitchListTile(
              title: const Text('조끼 착용 (+50)'),
              value: _hasVest,
              onChanged: (value) => setState(() => _hasVest = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: '가방 레벨'),
              items: [
                for (var level = 0; level <= 3; level++)
                  DropdownMenuItem(
                    value: level,
                    child: Text(level == 0 ? '가방 없음' : '$level 레벨'),
                  ),
              ],
              onChanged: (value) => setState(() => _level = value ?? 0),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: '트렁크 차량'),
              items: [
                for (final vehicle in data.vehicles)
                  DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(vehicle.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _vehicleId = value),
            ),
            const SizedBox(height: 12),
            Text(
              '가방 ${bagWeight.toStringAsFixed(1)} / ${capacity.toStringAsFixed(0)}',
              style: TextStyle(
                color: bagWeight > capacity ? Colors.redAccent : null,
              ),
            ),
            Text(
              '트렁크 ${trunkWeight.toStringAsFixed(1)} / ${vehicle?.capacity.toStringAsFixed(0) ?? '-'}',
              style: TextStyle(
                color: vehicle != null && trunkWeight > vehicle.capacity
                    ? Colors.redAccent
                    : null,
              ),
            ),
            if (bagWeight > capacity ||
                (vehicle != null && trunkWeight > vehicle.capacity))
              const Text('용량을 초과했습니다. 수량을 줄이세요.'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('가방')),
                ButtonSegment(value: true, label: Text('트렁크')),
              ],
              selected: {_trunk},
              onSelectionChanged: (value) =>
                  setState(() => _trunk = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: '아이템 이름 검색'),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            for (final item in data.items.where(
              (item) => item.name.toLowerCase().contains(_search),
            ))
              ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '단위 무게 ${item.weight} · ${item.canBeInBackpack ? '가방·트렁크' : '트렁크 전용'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '${item.name} 수량 줄이기',
                      onPressed: (quantities[item.id] ?? 0) == 0
                          ? null
                          : () => setState(
                              () => quantities[item.id] =
                                  quantities[item.id]! - 1,
                            ),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${quantities[item.id] ?? 0}'),
                    IconButton(
                      tooltip: '${item.name} 수량 늘리기',
                      onPressed:
                          (!_trunk && !item.canBeInBackpack) ||
                              (_trunk && vehicle == null)
                          ? null
                          : () => setState(
                              () => quantities[item.id] =
                                  (quantities[item.id] ?? 0) + 1,
                            ),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () => setState(() {
                _backpack.clear();
                _trunkItems.clear();
              }),
              child: const Text('수량 초기화'),
            ),
          ],
        );
      },
    ),
  );
}
