import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'map_fullscreen_view.dart';
import 'map_models.dart';
import 'map_marker_overlay.dart';
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
  final Set<String> _layers = {};
  bool _showFilters = false;
  int _loadGeneration = 0;
  late Future<MapMarkerLayer> _markerFuture;
  Map<String, List<String>> _adminSettings = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MapsRepository();
    _selectedMap = _repository.resolveMap(widget.initialMapId);
    _markerFuture = _loadMarkers();
  }

  Future<MapMarkerLayer> _loadMarkers() async {
    final generation = ++_loadGeneration;
    final mapId = _selectedMap.id;
    Map<String, List<String>> settings;
    try {
      settings = await _repository.fetchMapCategorySettings();
    } catch (_) {
      settings = {};
    }
    final allowed = settings.entries
        .where((entry) => entry.key.toLowerCase() == mapId.toLowerCase())
        .expand((entry) => entry.value)
        .toList();
    final layer = allowed.isEmpty
        ? MapMarkerLayer.unavailable(
            mapId: mapId,
            message: '웹 DB의 지도 설정이 없거나 불러오지 못했습니다. 새로고침해 주세요.',
          )
        : await _repository.fetchMarkers(mapId: mapId, layers: allowed);
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _adminSettings = settings;
        _layers.retainAll(
          _repository.filterActiveLayers(
            mapId,
            layer.markers.map((marker) => marker.layer).toSet().toList(),
            settings,
          ),
        );
      });
    }
    return layer;
  }

  /// 당겨서 새로고침. 새 future를 직접 기다려 인디케이터 시점을 맞춘다.
  Future<void> _refresh() async {
    final future = _loadMarkers();
    setState(() {
      _markerFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // 실패는 FutureBuilder가 fallback 레이어로 표시한다.
    }
  }

  void _toggleCategoryLabel(String labelName, List<String> availableLayers) {
    final relatedLayers = availableLayers
        .where((l) => getCategoryLabel(l) == labelName)
        .toList();
    final isAnyActive = relatedLayers.any((l) => _layers.contains(l));

    setState(() {
      if (isAnyActive) {
        _layers.removeAll(relatedLayers);
      } else {
        _layers.addAll(relatedLayers);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MapMarkerLayer>(
      future: _markerFuture,
      builder: (context, snapshot) {
        final layer =
            (snapshot.data?.mapId == _selectedMap.id ? snapshot.data : null) ??
            MapMarkerLayer.unavailable(
              mapId: _selectedMap.id,
              message: '지도 마커를 준비하는 중입니다.',
            );
        final loading = snapshot.connectionState == ConnectionState.waiting;

        // 마커 목록에서 레이어 목록을 동적으로 구성 (중복제거 및 정렬)
        final availableLayers =
            layer.markers.map((m) => m.layer).toSet().toList()..sort();

        final allowedLayers = _repository.filterActiveLayers(
          _selectedMap.id,
          availableLayers,
          _adminSettings,
        );

        // 한글 라벨명 기준 중복 제거 및 정렬
        final uniqueKoreanLabels =
            allowedLayers.map((l) => getCategoryLabel(l)).toSet().toList()
              ..sort();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const ScreenHeader(title: '전술 지도'),
              const SizedBox(height: BgmsSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final map in _repository.availableMaps)
                      Padding(
                        padding: const EdgeInsets.only(right: BgmsSpacing.sm),
                        child: ChoiceChip(
                          label: Text(map.name),
                          selected: map.id == _selectedMap.id,
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (!selected || map.id == _selectedMap.id) return;
                            setState(() {
                              _selectedMap = _repository.resolveMap(map.id);
                              _layers.clear();
                              _adminSettings = {};
                              _showFilters = false;
                              _markerFuture = _loadMarkers();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: BgmsSpacing.lg),
              if (uniqueKoreanLabels.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                    icon: Icon(_showFilters ? Icons.expand_less : Icons.tune),
                    label: Text(_showFilters ? '필터 접기' : '마커 필터'),
                  ),
                ),
              if (_showFilters)
                Wrap(
                  spacing: BgmsSpacing.sm,
                  runSpacing: BgmsSpacing.sm,
                  children: uniqueKoreanLabels.map((koreanLabel) {
                    final relatedLayers = allowedLayers
                        .where((l) => getCategoryLabel(l) == koreanLabel)
                        .toList();
                    final isSelected = relatedLayers.any(
                      (l) => _layers.contains(l),
                    );

                    return FilterChip(
                      label: Text(koreanLabel),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) =>
                          _toggleCategoryLabel(koreanLabel, allowedLayers),
                    );
                  }).toList(),
                ),
              const SizedBox(height: BgmsSpacing.lg),
              _MapPanel(
                key: ValueKey(_selectedMap.id),
                map: _selectedMap,
                layer: layer,
                activeLayers: _layers,
                loading: loading,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapPanel extends StatefulWidget {
  const _MapPanel({
    super.key,
    required this.map,
    required this.layer,
    required this.activeLayers,
    required this.loading,
  });

  final BgmsMap map;
  final MapMarkerLayer layer;
  final Set<String> activeLayers;
  final bool loading;

  @override
  State<_MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<_MapPanel> {
  final TransformationController _transformationController =
      TransformationController();
  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleZoomChange);
  }

  void _handleZoomChange() {
    final zoomMatrix = _transformationController.value;
    final currentScale = zoomMatrix.getMaxScaleOnViewport();
    if (_zoomScaleNotifier.value != currentScale) {
      _zoomScaleNotifier.value = currentScale;
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleZoomChange);
    _transformationController.dispose();
    _zoomScaleNotifier.dispose();
    super.dispose();
  }

  void _showMarkerDetails(BuildContext context, MapMarker marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BgmsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        final label = getCategoryLabel(marker.layer);
        final color = getMarkerColor(marker.layer);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(BgmsSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BgmsSpacing.sm,
                        vertical: BgmsSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color, width: 0.5),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      icon: const Icon(
                        Icons.close,
                        color: BgmsColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: BgmsSpacing.md),
                Text(
                  marker.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: BgmsSpacing.sm),
                Text(
                  '위치 좌표: (X: ${(marker.x * 100).toStringAsFixed(1)}%, Y: ${(marker.y * 100).toStringAsFixed(1)}%)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BgmsColors.textMuted),
                ),
                const SizedBox(height: BgmsSpacing.md),
                Text(
                  '${marker.label}은(는) ${getCategoryLabel(marker.layer)} 분류 지점입니다. 게임 플레이 전술 수립 시 참고하십시오.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BgmsColors.textSecondary,
                    height: 1.4,
                  ),
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
    final visibleMarkers = widget.layer.markers
        .where((marker) => widget.activeLayers.contains(marker.layer))
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
                    '${widget.map.name} 전술 지도',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(label: Text(widget.layer.displaySourceLabel)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.layer.source == MapMarkerSource.api &&
                            widget.activeLayers.isEmpty
                        ? '마커 필터에서 원하는 항목을 켜 주세요.'
                        : widget.layer.displayMessage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.loading) const LinearProgressIndicator(),
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
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
                                    border: Border.all(
                                      color: BgmsColors.border,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: MapTileMosaic(
                                      map: widget.map,
                                      controller: _transformationController,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _zoomScaleNotifier,
                                  builder: (context, scale, child) =>
                                      MapMarkerOverlay(
                                        markers: visibleMarkers,
                                        scale: scale,
                                        onMarkerTap: (marker) =>
                                            _showMarkerDetails(context, marker),
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
                      tooltip: '지도 전체 화면',
                      backgroundColor: Colors.black.withValues(alpha: 0.62),
                      foregroundColor: BgmsColors.accent,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapFullscreenView(
                              map: widget.map,
                              markers: widget.layer.markers,
                              activeLayers: widget.activeLayers,
                              onMarkerTap: (m) =>
                                  _showMarkerDetails(context, m),
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
            if (!widget.loading && visibleMarkers.isEmpty) ...[
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: BgmsColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text('마커 필터를 켜면 선택한 항목만 지도에 표시됩니다.')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MapTileMosaic extends StatelessWidget {
  const MapTileMosaic({super.key, required this.map, this.controller});

  static const int _zoom = 2;
  static const int _tileCount = 4;

  /// 타일 디코딩 폭 상한.
  ///
  /// 4x4 격자를 화면 폭에 맞춰 그리므로 원본 해상도가 필요하지 않다.
  /// 폭을 제한하면 16장 합계 메모리와 디코딩 시간이 함께 줄어든다.
  static const int _tileCacheWidth = 512;

  final BgmsMap map;
  final TransformationController? controller;

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.local;
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
            final url = config.mapTileUrl(
              mapId: map.tilePath,
              zoom: _zoom,
              column: x,
              row: row,
            );

            return Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              // 타일 원본이 화면 표시 크기보다 크므로 디코딩 폭을 제한해
              // 메모리와 디코딩 비용을 줄인다.
              cacheWidth: _tileCacheWidth,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                // 로딩 중 빈 화면 대신 배경을 채워 깜빡임을 줄인다.
                return const ColoredBox(color: BgmsColors.surface);
              },
              errorBuilder: (context, error, stackTrace) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: BgmsColors.bgBase,
                    border: Border.all(color: BgmsColors.border),
                  ),
                  child: const Center(child: Icon(Icons.broken_image_outlined,
                    size: 18, color: BgmsColors.textMuted, semanticLabel: '지도 타일을 불러오지 못했습니다')),
                );
              },
            );
          },
        ),
        if (controller != null)
          LayoutBuilder(
            builder: (context, constraints) => ValueListenableBuilder<Matrix4>(
              valueListenable: controller!,
              builder: (context, matrix, child) {
                final scale = matrix.getMaxScaleOnViewport();
                final zoom = scale >= 4
                    ? 4
                    : scale >= 2
                    ? 3
                    : 2;
                if (zoom == 2) return const SizedBox.shrink();
                final count = 1 << zoom;
                final size = constraints.biggest;
                final tileWidth = size.width / count;
                final tileHeight = size.height / count;
                final start = controller!.toScene(Offset.zero);
                final end = controller!.toScene(
                  Offset(size.width, size.height),
                );
                final firstX = (start.dx / tileWidth).floor().clamp(
                  0,
                  count - 1,
                );
                final lastX = (end.dx / tileWidth).floor().clamp(0, count - 1);
                final firstY = (start.dy / tileHeight).floor().clamp(
                  0,
                  count - 1,
                );
                final lastY = (end.dy / tileHeight).floor().clamp(0, count - 1);
                return Stack(
                  children: [
                    for (var y = firstY; y <= lastY; y++)
                      for (var x = firstX; x <= lastX; x++)
                        Positioned(
                          left: x * tileWidth,
                          top: y * tileHeight,
                          width: tileWidth,
                          height: tileHeight,
                          child: Image.network(
                            config.mapTileUrl(
                              mapId: map.tilePath,
                              zoom: zoom,
                              column: x,
                              row: y,
                            ),
                            key: ValueKey('${map.id}/$zoom/$x/$y'),
                            fit: BoxFit.cover,
                            cacheWidth: _tileCacheWidth,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : const SizedBox.shrink(),
                          ),
                        ),
                  ],
                );
              },
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

    return Semantics(
      button: true,
      label: '${marker.label}, ${getCategoryLabel(marker.layer)}',
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
