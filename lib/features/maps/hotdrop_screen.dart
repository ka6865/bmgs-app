import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import '../stats/player_stats_models.dart' show seasonLabel;
import 'maps_repository.dart';
import 'maps_screen.dart';

class HotdropScreen extends StatefulWidget {
  const HotdropScreen({super.key, this.initialMapId, this.client});
  final String? initialMapId;
  final BgmsApiClient? client;
  @override
  State<HotdropScreen> createState() => _HotdropScreenState();
}

class _HotdropScreenState extends State<HotdropScreen> {
  final _repository = MapsRepository();
  late final _client =
      widget.client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);
  late String _mapId;
  late Future<Map<String, dynamic>> _future;
  final _controller = TransformationController();
  @override
  void initState() {
    super.initState();
    _mapId = _repository.resolveMap(widget.initialMapId).id;
    _load();
  }

  void _load() => _future = _client.fetchHotdrops(_mapId);

  @override
  void didUpdateWidget(covariant HotdropScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMapId == oldWidget.initialMapId ||
        widget.initialMapId == null) {
      return;
    }
    final mapId = _repository.resolveMap(widget.initialMapId).id;
    if (mapId == _mapId) return;
    _mapId = mapId;
    _controller.value = Matrix4.identity();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('핫드랍 지도')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('DB에 수집된 시즌별 착지 표본입니다. 전체 PUBG 경기의 착지 통계는 아닙니다.'),
        Wrap(
          spacing: 8,
          children: [
            for (final map in _repository.availableMaps)
              ChoiceChip(
                label: Text(map.name),
                selected: _mapId == map.id,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _mapId = map.id;
                      _controller.value = Matrix4.identity();
                      _load();
                    });
                  }
                },
              ),
          ],
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(ApiException.from(snapshot.error!).message),
                  TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('다시 불러오기'),
                  ),
                ],
              );
            }
            final data = snapshot.data ?? {};
            final points = hotdropPoints(data);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (points.isEmpty)
                  const Text('이 맵의 착지 표본이 없습니다.')
                else
                  Text(
                    '${seasonLabel(data['season']?.toString() ?? '-')} · 수집 지점 ${points.length}개',
                  ),
                AspectRatio(
                  aspectRatio: 1,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 1,
                    maxScale: 6,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: MapTileMosaic(
                            map: _repository.resolveMap(_mapId),
                            controller: _controller,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _HotdropPainter(points),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (points.isNotEmpty)
                  const Text('진한 붉은색일수록 이 표본에서 착지 빈도가 높습니다.'),
              ],
            );
          },
        ),
      ],
    ),
  );
}

List<({double x, double y, double intensity})> hotdropPoints(
  Map<String, dynamic> json,
) {
  final result = <({double x, double y, double intensity})>[];
  final points = json['points'];
  if (points is! List) return result;
  for (final point in points.whereType<Map>()) {
    final x = point['lng'];
    final y = point['lat'];
    final intensity = point['intensity'];
    if (x is! num ||
        y is! num ||
        intensity is! num ||
        !x.isFinite ||
        !y.isFinite ||
        !intensity.isFinite ||
        x < 0 ||
        x > 8192 ||
        y < 0 ||
        y > 8192 ||
        intensity <= 0 ||
        intensity > 1) {
      continue;
    }
    // API의 lat은 Leaflet용 북쪽 증가 좌표다. 캔버스는 아래쪽으로 증가한다.
    result.add((x: x / 8192, y: 1 - y / 8192, intensity: intensity.toDouble()));
  }
  return result;
}

class _HotdropPainter extends CustomPainter {
  _HotdropPainter(this.points);
  final List<({double x, double y, double intensity})> points;
  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        size.width / 70,
        Paint()
          ..color = Colors.red.withValues(alpha: 0.1 + point.intensity * 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_HotdropPainter old) => old.points != points;
}
