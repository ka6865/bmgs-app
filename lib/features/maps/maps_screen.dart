

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'map_fullscreen_view.dart';
import 'map_models.dart';
import 'map_view_helpers.dart';
import 'maps_repository.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key, this.initialMapId, this.repository});

  final String? initialMapId;
  final MapsRepository? repository;

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late final MapsRepository _repository;
  late BgmsMap _selectedMap;
  final Set<String> _layers = {'Garage', 'SecretRoom', 'HotDrop'};
  late Future<MapMarkerLayer> _markerFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MapsRepository();
    _selectedMap = _repository.resolveMap(widget.initialMapId);
    _markerFuture = _loadMarkers();
  }

  Future<MapMarkerLayer> _loadMarkers() {
    final future = _repository.fetchMarkers(
      mapId: _selectedMap.id,
      layers: const [], // 전체 마커 데이터 로드
    );

    future.then((layer) {
      if (mounted) {
        setState(() {
          if (layer.markers.isNotEmpty) {
            final available = layer.markers.map((m) => m.layer).toSet();
            _layers.clear();
            _layers.addAll(available);
          } else {
            _layers.clear();
            _layers.addAll(const ['Garage', 'SecretRoom', 'Esports', 'HotDrop']);
          }
        });
      }
    });

    return future;
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MapMarkerLayer>(
      future: _markerFuture,
      builder: (context, snapshot) {
        final layer = snapshot.data ??
            MapMarkerLayer.unavailable(
              mapId: _selectedMap.id,
              message: '지도 마커를 준비하는 중입니다.',
            );
        final loading = snapshot.connectionState == ConnectionState.waiting;

        // 마커 목록에서 레이어 목록을 동적으로 구성 (중복제거 및 정렬)
        final availableLayers =
            layer.markers.map((m) => m.layer).toSet().toList()..sort();

        final layersToShow = availableLayers.isNotEmpty
            ? availableLayers
            : const ['Garage', 'SecretRoom', 'Esports', 'HotDrop'];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const BgmsBrandHeader(
              title: '지도',
              subtitle: '맵별 주요 마커와 레이어를 읽기 전용으로 확인합니다.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedMap.id,
              decoration: const InputDecoration(labelText: '맵 선택'),
              items: _repository.availableMaps
                  .map(
                    (map) => DropdownMenuItem(value: map.id, child: Text(map.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedMap = _repository.resolveMap(value);
                  _markerFuture = _loadMarkers();
                });
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: layersToShow.map((layerName) {
                return _LayerChip(
                  label: getCategoryLabel(layerName),
                  layer: layerName,
                  selected: _layers.contains(layerName),
                  onSelected: _toggleLayer,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _MapPanel(
              map: _selectedMap,
              layer: layer,
              activeLayers: _layers,
              loading: loading,
            ),
          ],
        );
      },
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({
    required this.label,
    required this.layer,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String layer;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(layer),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.map,
    required this.layer,
    required this.activeLayers,
    required this.loading,
  });

  final BgmsMap map;
  final MapMarkerLayer layer;
  final Set<String> activeLayers;
  final bool loading;

  void _showMarkerDetails(BuildContext context, MapMarker marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161b26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final label = getCategoryLabel(marker.layer);
        final color = getMarkerColor(marker.layer);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color, width: 0.5),
                      ),
                      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  marker.label,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '위치 좌표: (X: ${(marker.x * 100).toStringAsFixed(1)}%, Y: ${(marker.y * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  '${marker.label}은(는) ${getCategoryLabel(marker.layer)} 분류 지점입니다. 게임 플레이 전술 수립 시 참고하십시오.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleMarkers = layer.markers
        .where((marker) => activeLayers.contains(marker.layer))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${map.name} 읽기 전용 지도',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text(layer.source.name)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${layer.message} 지도 배경은 웹 BGMS 타일(/tiles) 기준입니다.'),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(),
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: BgmsColors.elevated,
                                    border: Border.all(color: BgmsColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: MapTileMosaic(map: map),
                                  ),
                                ),
                              ),
                              ...visibleMarkers.map(
                                (marker) => Align(
                                  alignment: FractionalOffset(marker.x, marker.y),
                                  child: MapMarkerWidget(
                                    marker: marker,
                                    onTap: () => _showMarkerDetails(context, marker),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton.small(
                      heroTag: 'map_fullscreen',
                      backgroundColor: Colors.black.withValues(alpha: 0.62),
                      foregroundColor: BgmsColors.accent,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapFullscreenView(
                              map: map,
                              markers: layer.markers,
                              activeLayers: activeLayers,
                              onMarkerTap: (m) => _showMarkerDetails(context, m),
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.fullscreen),
                    ),
                  ),
                ],
              ),
            ),
            if (!loading && visibleMarkers.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('표시할 마커가 없습니다. 위 API 메시지를 확인해 주세요.'),
            ],
          ],
        ),
      ),
    );
  }
}

class MapTileMosaic extends StatelessWidget {
  const MapTileMosaic({super.key, required this.map});

  static const int _zoom = 2;
  static const int _tileCount = 4;

  final BgmsMap map;

  @override
  Widget build(BuildContext context) {
    final baseUrl = AppConfig.local.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');

    return Stack(
      fit: StackFit.expand,
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _tileCount,
          ),
          itemCount: _tileCount * _tileCount,
          itemBuilder: (context, index) {
            final x = index % _tileCount;
            final row = index ~/ _tileCount;
            final y = -(_tileCount - row);
            final url = '$baseUrl/tiles/${map.tilePath}/$_zoom/$x/$y.jpg';

            return Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: BgmsColors.bgBase,
                    border: Border.all(color: BgmsColors.border),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            );
          },
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BgmsColors.border),
            ),
            child: const Text(
              'tile z2',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }
}

class MapMarkerWidget extends StatelessWidget {
  const MapMarkerWidget({super.key, required this.marker, required this.onTap});

  final MapMarker marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = getMarkerIcon(marker.layer);
    final color = getMarkerColor(marker.layer);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
