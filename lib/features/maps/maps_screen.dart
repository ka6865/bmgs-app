import 'package:flutter/material.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  String _mapId = 'Erangel';
  final Set<String> _layers = {'Garage', 'SecretRoom'};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '지도',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _mapId,
          decoration: const InputDecoration(labelText: '맵 선택'),
          items: const [
            DropdownMenuItem(value: 'Erangel', child: Text('Erangel')),
            DropdownMenuItem(value: 'Miramar', child: Text('Miramar')),
            DropdownMenuItem(value: 'Taego', child: Text('Taego')),
            DropdownMenuItem(value: 'Rondo', child: Text('Rondo')),
            DropdownMenuItem(value: 'Vikendi', child: Text('Vikendi')),
            DropdownMenuItem(value: 'Deston', child: Text('Deston')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _mapId = value);
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('차량'),
              selected: _layers.contains('Garage'),
              onSelected: (_) => _toggleLayer('Garage'),
            ),
            FilterChip(
              label: const Text('비밀방'),
              selected: _layers.contains('SecretRoom'),
              onSelected: (_) => _toggleLayer('SecretRoom'),
            ),
            FilterChip(
              label: const Text('이스포츠'),
              selected: _layers.contains('Esports'),
              onSelected: (_) => _toggleLayer('Esports'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: AspectRatio(
            aspectRatio: 1,
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Center(child: Text('$_mapId 읽기 전용 지도')),
                    ),
                  ),
                  const Positioned(
                    left: 80,
                    top: 110,
                    child: _MapMarker(label: '차량'),
                  ),
                  const Positioned(
                    right: 76,
                    bottom: 96,
                    child: _MapMarker(label: '비밀방'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleLayer(String layer) {
    setState(() {
      if (_layers.contains(layer)) {
        _layers.remove(layer);
      } else {
        _layers.add(layer);
      }
    });
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.location_on, size: 16),
      label: Text(label),
    );
  }
}
