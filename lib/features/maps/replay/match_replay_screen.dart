import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/bgms_api_client.dart';
import '../../../core/theme/bgms_theme.dart';
import '../maps_repository.dart';
import '../maps_screen.dart';
import 'replay_models.dart';

class MatchReplayScreen extends StatefulWidget {
  const MatchReplayScreen({
    super.key,
    required this.matchId,
    required this.nickname,
    required this.platform,
    required this.mapId,
    this.client,
  });
  final String matchId, nickname, platform, mapId;
  final BgmsApiClient? client;
  @override
  State<MatchReplayScreen> createState() => _MatchReplayScreenState();
}

class _MatchReplayScreenState extends State<MatchReplayScreen> {
  late Future<MatchReplay> _future;
  double _time = 0;
  Timer? _timer;
  final _controller = TransformationController();
  Future<MatchReplay> _load() async => MatchReplay.fromJson(
    await (widget.client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl))
        .fetchTelemetry(
          matchId: widget.matchId,
          nickname: widget.nickname,
          platform: widget.platform,
          mapName: widget.mapId,
        ),
    widget.nickname,
  );
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _play(double end) {
    if (_timer != null) {
      setState(_stop);
      return;
    }
    if (_time >= end) _time = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {
        _time = (_time + 1000).clamp(0, end);
        if (_time >= end) _stop();
      });
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('경기 2D 리플레이')),
    body: FutureBuilder<MatchReplay>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                snapshot.error is FormatException
                    ? (snapshot.error as FormatException).message
                    : ApiException.from(snapshot.error ?? '리플레이 없음').message,
              ),
              const Text('보존 기간이 지났거나 경기 데이터가 없으면 재생할 수 없습니다.'),
              FilledButton(
                onPressed: () => setState(() {
                  _stop();
                  _time = 0;
                  _future = _load();
                }),
                child: const Text('다시 시도'),
              ),
            ],
          );
        }
        final replay = snapshot.data!;
        final map = MapsRepository().resolveMap(replay.mapId);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.nickname} · ${map.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text('기록된 이동 경로와 교전 시각을 표시합니다. 기록 사이의 움직임은 추정하지 않습니다.'),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MapTileMosaic(map: map, controller: _controller),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ReplayPainter(replay, _time),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (replay.positions.isEmpty) const Text('플레이어의 이동 좌표 기록이 없습니다.'),
            if (replay.durationMs > 0)
              Row(
                children: [
                  IconButton(
                    tooltip: _timer == null ? '재생' : '일시정지',
                    onPressed: () => _play(replay.durationMs),
                    icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause),
                  ),
                  Expanded(
                    child: Slider(
                      value: _time.clamp(0, replay.durationMs),
                      max: replay.durationMs,
                      onChanged: (value) => setState(() {
                        _stop();
                        _time = value;
                      }),
                    ),
                  ),
                  Text(replayTime(_time)),
                ],
              ),
            const Text('초록: 내 이동 · 흰색: 다음 안전 구역 · 파랑: 현재 자기장'),
            const SizedBox(height: 16),
            for (final fight in replay.fights)
              ListTile(
                leading: const Icon(Icons.my_location),
                title: Text('${fight.attacker} → ${fight.victim}'),
                subtitle: Text(
                  '${replayTime(fight.timeMs)} · ${fight.type == 'kill'
                      ? '처치'
                      : fight.type == 'groggy'
                      ? '기절'
                      : '부활'} · ${fight.weapon}',
                ),
                onTap: () => setState(() {
                  _stop();
                  _time = fight.timeMs;
                }),
              ),
            if (replay.fights.isEmpty) const Text('해당 플레이어의 교전 기록이 없습니다.'),
          ],
        );
      },
    ),
  );
}

String replayTime(double ms) {
  final seconds = (ms / 1000).floor();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _ReplayPainter extends CustomPainter {
  _ReplayPainter(this.replay, this.time);
  final MatchReplay replay;
  final double time;
  @override
  void paint(Canvas canvas, Size size) {
    final zone = replay.zones.where((z) => z.timeMs <= time).lastOrNull;
    void drawZone(double? x, double? y, double? radius, Color color) {
      if (x == null || y == null || radius == null) return;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius * size.width,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    drawZone(zone?.whiteX, zone?.whiteY, zone?.whiteRadius, Colors.white);
    drawZone(
      zone?.blueX,
      zone?.blueY,
      zone?.blueRadius,
      Colors.lightBlueAccent,
    );
    final segments = replay.pathSegmentsAt(time);
    if (segments.isEmpty) return;
    final path = Path();
    for (final segment in segments) {
      path.moveTo(segment.first.x * size.width, segment.first.y * size.height);
      for (final point in segment.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = BgmsColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(
        segments.last.last.x * size.width,
        segments.last.last.y * size.height,
      ),
      5,
      Paint()..color = BgmsColors.accent,
    );
  }

  @override
  bool shouldRepaint(_ReplayPainter old) =>
      old.time != time || old.replay != replay;
}
