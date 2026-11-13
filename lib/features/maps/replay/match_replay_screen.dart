import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/bgms_api_client.dart';
import '../../../core/platform/orientation_policy.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../stats/weapon_mastery_models.dart';
import '../map_view_helpers.dart';
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
  int _speed = 30;
  Timer? _timer;
  bool _showPaths = true;
  bool _showEnemies = true;
  bool _showFeed = true;

  /// 세로 화면에서 사용자가 켠 전체화면. 가로 화면은 항상 전체화면이다.
  bool _fullscreen = false;
  bool? _immersiveApplied;

  /// 카메라가 따라가는 아군 이름. 지도를 직접 움직이면 해제한다.
  String? _follow;
  Size _viewport = Size.zero;
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
    OrientationPolicy.enterRotatable();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    OrientationPolicy.exitRotatable();
    if (_immersiveApplied == true) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _play(MatchReplay replay) {
    if (_timer != null) {
      setState(_stop);
      return;
    }
    final end = replay.durationMs;
    if (_time >= end) _time = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _time = (_time + 100.0 * _speed).clamp(0, end);
        if (_time >= end) _stop();
        _followCamera(replay);
      });
    });
    setState(() {});
  }

  void _seek(MatchReplay replay, double time) => setState(() {
    _stop();
    _time = time;
    _followCamera(replay);
  });

  void _toggleFollow(MatchReplay replay, String name) => setState(() {
    _follow = _follow == name ? null : name;
    if (_follow == null) {
      _controller.value = Matrix4.identity();
    } else {
      _followCamera(replay);
    }
  });

  /// 따라가는 선수가 지도 가운데 오도록 확대·이동한다. 지도 밖이 보이지 않게 가장자리에서 멈춘다.
  void _followCamera(MatchReplay replay) {
    final name = _follow;
    final side = _viewport.shortestSide;
    if (name == null || side <= 0) return;
    final member = replay.squad
        .where((track) => track.name == name)
        .firstOrNull;
    final position = member?.at(_time);
    if (position == null) return;
    final current = _controller.value.getMaxScaleOnViewport();
    final scale = current < 2.5 ? 3.0 : current;
    final dx = (side / 2 - position.x * side * scale).clamp(
      side - side * scale,
      0.0,
    );
    final dy = (side / 2 - position.y * side * scale).clamp(
      side - side * scale,
      0.0,
    );
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// 전체화면일 때 상태바·홈 표시줄을 숨긴다. 바뀔 때만 시스템에 알린다.
  void _applyImmersive(bool immersive) {
    if (_immersiveApplied == immersive) return;
    _immersiveApplied = immersive;
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final immersive = landscape || _fullscreen;
    _applyImmersive(immersive);

    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: immersive ? null : AppBar(title: const Text('경기 2D 리플레이')),
      body: FutureBuilder<MatchReplay>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (immersive) const BackButton(),
                  Text(
                    snapshot.error is FormatException
                        ? (snapshot.error as FormatException).message
                        : ApiException.from(
                            snapshot.error ?? '리플레이 없음',
                          ).message,
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
              ),
            );
          }
          final replay = snapshot.data!;
          return SafeArea(
            top: immersive,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 가로이거나 펼친 폴드·태블릿처럼 넓으면 지도 옆에 패널을 둔다.
                final side =
                    constraints.maxWidth >= constraints.maxHeight * 1.25;
                if (side) {
                  final mapSide = constraints.maxHeight;
                  return Row(
                    children: [
                      SizedBox.square(
                        dimension: mapSide,
                        child: _mapView(replay, immersive),
                      ),
                      Expanded(child: _panel(replay, immersive)),
                    ],
                  );
                }
                // 전체화면은 조작부만 남기고 나머지 높이를 모두 지도에 준다.
                if (immersive) {
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _mapView(replay, immersive),
                          ),
                        ),
                      ),
                      _panel(replay, immersive),
                    ],
                  );
                }
                // 세로·정사각형에 가까운 화면은 지도가 패널 자리를 다 먹지 않게 높이를 제한한다.
                final mapSide = constraints.maxWidth
                    .clamp(0.0, constraints.maxHeight * 0.62)
                    .toDouble();
                return Column(
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: mapSide,
                        child: _mapView(replay, immersive),
                      ),
                    ),
                    Expanded(child: _panel(replay, immersive)),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _mapView(MatchReplay replay, bool immersive) {
    final map = MapsRepository().resolveMap(replay.mapId);
    final zone = replay.zoneStatusAt(_time);
    // 실제 화면에서 약 3초 머물도록 배속에 맞춰 경기 시간 창을 넓힌다.
    final feedWindow = (_speed * 3000.0).clamp(8000.0, 180000.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 10,
                  onInteractionStart: (_) {
                    if (_follow != null) setState(() => _follow = null);
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MapTileMosaic(map: map, controller: _controller),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ReplayPainter(
                              replay,
                              _time,
                              showPaths: _showPaths,
                              showEnemies: _showEnemies,
                              controller: _controller,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _VehicleBadges(
                            replay: replay,
                            time: _time,
                            controller: _controller,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showFeed)
                Positioned(
                  top: 8,
                  right: 8,
                  width: constraints.maxWidth * 0.72,
                  child: IgnorePointer(
                    child: _KillFeed(
                      replay: replay,
                      time: _time,
                      window: feedWindow,
                    ),
                  ),
                ),
              if (immersive)
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton.filledTonal(
                    tooltip: '뒤로',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (zone != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _Badge(
                          text: [
                            if (zone.phase != null && zone.phase! > 0)
                              '${zone.phase}페이즈',
                            zone.shrinking
                                ? '자기장 이동 ${replayTime(zone.remainingMs)}'
                                : '수축까지 ${replayTime(zone.remainingMs)}',
                          ].join(' · '),
                          color: zone.shrinking ? Colors.lightBlueAccent : null,
                        ),
                      ),
                    _Badge(text: '${map.name} · ${replayTime(_time)}'),
                  ],
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: IconButton.filledTonal(
                  tooltip: immersive ? '전체화면 끝내기' : '전체화면',
                  onPressed:
                      MediaQuery.sizeOf(context).width >
                          MediaQuery.sizeOf(context).height
                      ? null
                      : () => setState(() => _fullscreen = !_fullscreen),
                  icon: Icon(
                    immersive ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 재생 막대·배속·표시 필터·팀원 따라가기. 전체화면에서는 이것만 남긴다.
  List<Widget> _controls(MatchReplay replay) {
    final theme = Theme.of(context);
    return [
      if (replay.durationMs > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: _timer == null ? '재생' : '일시정지',
                onPressed: () => _play(replay),
                icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _TimelineTicks(replay)),
                      ),
                    ),
                    Slider(
                      value: _time.clamp(0, replay.durationMs),
                      max: replay.durationMs,
                      onChanged: (value) => _seek(replay, value),
                    ),
                  ],
                ),
              ),
              Text(
                replayTime(replay.durationMs),
                style: BgmsText.number(15, color: BgmsColors.textMuted),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final speed in const [10, 30, 60])
                  ChoiceChip(
                    label: Text('$speed배속'),
                    selected: _speed == speed,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _speed = speed),
                  ),
                FilterChip(
                  label: const Text('동선'),
                  selected: _showPaths,
                  onSelected: (value) => setState(() => _showPaths = value),
                ),
                FilterChip(
                  label: const Text('적 위치'),
                  selected: _showEnemies,
                  onSelected: (value) => setState(() => _showEnemies = value),
                ),
                FilterChip(
                  label: const Text('킬로그'),
                  selected: _showFeed,
                  onSelected: (value) => setState(() => _showFeed = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '팀원을 누르면 카메라가 따라갑니다',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BgmsColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final member in replay.squad)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: replaySquadColor(replay, member.name),
                    ),
                    label: Text(
                      // 첫 기록 전(수송기 대기)은 탈락이 아니다.
                      member.at(_time) == null &&
                              _time > member.points.last.timeMs
                          ? '${member.name} (탈락)'
                          : member.name,
                    ),
                    selected: _follow == member.name,
                    showCheckmark: false,
                    onSelected: (_) => _toggleFollow(replay, member.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _panel(MatchReplay replay, bool immersive) {
    if (immersive) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _controls(replay),
        ),
      );
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: BgmsColors.textSecondary,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ..._controls(replay),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                '회색 점: 적 · 흰 원: 다음 안전 구역 · 파란 원: 현재 자기장 · 점선: 탈것 이동 · ✕ 처치 · ● 기절',
                style: muted,
              ),
              const SizedBox(height: 16),
              Text(
                '아군 교전',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (replay.fights.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('아군의 교전 기록이 없습니다.', style: muted),
                ),
            ],
          ),
        ),
        for (final fight in replay.fights)
          ListTile(
            dense: true,
            selected: fight.timeMs <= _time,
            leading: Icon(
              fight.type == 'kill'
                  ? Icons.close
                  : fight.type == 'groggy'
                  ? Icons.circle
                  : Icons.healing,
              size: 18,
              color: _fightColor(fight.type),
            ),
            title: Text('${fight.attacker} → ${fight.victim}'),
            subtitle: Text(
              '${replayTime(fight.timeMs)} · ${_fightLabel(fight.type)}'
              '${fight.weapon.isEmpty ? '' : ' · ${pubgWeaponName(fight.weapon)}'}',
            ),
            onTap: () => _seek(replay, fight.timeMs),
          ),
      ],
    );
  }
}

/// 재생 막대 뒤에 아군 기절·처치 시점을 눈금으로 그린다.
class _TimelineTicks extends CustomPainter {
  _TimelineTicks(this.replay);
  final MatchReplay replay;

  // Slider의 좌우 여백(오버레이 반지름)만큼 안쪽에서 그린다.
  static const _inset = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final duration = replay.durationMs;
    if (duration <= 0) return;
    final width = size.width - _inset * 2;
    for (final fight in replay.fights) {
      if (fight.type == 'revive') continue;
      final x = _inset + width * (fight.timeMs / duration).clamp(0, 1);
      canvas.drawLine(
        Offset(x, size.height / 2 - 9),
        Offset(x, size.height / 2 - 4),
        Paint()
          ..color = _fightColor(fight.type)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelineTicks old) => old.replay != replay;
}

String replayTime(double ms) {
  final seconds = (ms / 1000).floor();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _fightLabel(String type) => switch (type) {
  'kill' => '처치',
  'groggy' => '기절',
  _ => '부활',
};

// 웹 리플레이(lib/replay/squadColors.ts)와 같은 아군 색 순서.
const _squadColors = [
  Color(0xFFF2A900),
  Color(0xFF34A853),
  Color(0xFF3B82F6),
  Color(0xFFEF4444),
];

Color replaySquadColor(MatchReplay replay, String name) {
  final index = replay.squad.indexWhere(
    (member) => member.name.toLowerCase() == name.toLowerCase(),
  );
  return _squadColors[index.clamp(0, _squadColors.length - 1)];
}

/// 아군이면 팀 색, 아니면 null.
Color? _squadColorOrNull(MatchReplay replay, String name) {
  final isSquad = replay.squad.any(
    (member) => member.name.toLowerCase() == name.toLowerCase(),
  );
  return isSquad ? replaySquadColor(replay, name) : null;
}

Color _fightColor(String type) => switch (type) {
  'kill' => BgmsColors.danger,
  'groggy' => BgmsColors.knock,
  _ => BgmsColors.top10,
};

IconData _vehicleIcon(ReplayVehicleKind kind) => switch (kind) {
  ReplayVehicleKind.plane => Icons.flight,
  ReplayVehicleKind.glider => Icons.paragliding,
  ReplayVehicleKind.boat => Icons.directions_boat,
  ReplayVehicleKind.car => Icons.directions_car,
};

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BgmsRadius.sm,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        text,
        style: BgmsText.number(14, color: color ?? BgmsColors.textPrimary),
      ),
    ),
  );
}

/// 지도 위 킬 로그. 최근 처치·기절이 나타났다가 시간이 지나면 흐려지며 사라진다.
class _KillFeed extends StatelessWidget {
  const _KillFeed({
    required this.replay,
    required this.time,
    required this.window,
  });

  final MatchReplay replay;
  final double time;

  /// 로그를 보여줄 경기 시간 길이(ms).
  final double window;

  @override
  Widget build(BuildContext context) {
    final recent = replay.feed
        .where((fight) => fight.timeMs <= time && time - fight.timeMs < window)
        .toList();
    final visible = recent.length > 4
        ? recent.sublist(recent.length - 4)
        : recent;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: Colors.white, height: 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final fight in visible)
          Opacity(
            // 남은 시간의 마지막 40% 동안 서서히 사라진다.
            opacity: ((1 - (time - fight.timeMs) / window) / 0.4).clamp(0, 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BgmsRadius.sm,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: fight.attacker.isEmpty ? '자기장' : fight.attacker,
                          style: TextStyle(
                            color: _squadColorOrNull(replay, fight.attacker),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: fight.weapon.isEmpty
                              ? '  '
                              : '  ${pubgWeaponName(fight.weapon)}  ',
                          style: const TextStyle(color: BgmsColors.textMuted),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            fight.type == 'kill' ? Icons.close : Icons.circle,
                            size: fight.type == 'kill' ? 13 : 8,
                            color: _fightColor(fight.type),
                          ),
                        ),
                        TextSpan(
                          text: '  ${fight.victim}',
                          style: TextStyle(
                            color: _squadColorOrNull(replay, fight.victim),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 탈것에 탄 아군 위치에 탈것 아이콘을 띄운다. 걸어 다니면 점(페인터)만 그린다.
///
/// 지도를 확대해도 아이콘은 화면에서 같은 크기로 보이도록 확대 비율만큼 줄인다.
class _VehicleBadges extends StatelessWidget {
  const _VehicleBadges({
    required this.replay,
    required this.time,
    required this.controller,
  });

  final MatchReplay replay;
  final double time;
  final TransformationController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scale = controller.value.getMaxScaleOnViewport();
        return Stack(
          children: [
            for (final member in replay.squad)
              if (member.at(time) case final position?)
                if (replayVehicleKind(position.vehicle) case final kind?)
                  Positioned(
                    left: position.x * constraints.maxWidth,
                    top: position.y * constraints.maxHeight,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: Transform.scale(
                        scale: 1 / scale,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: replaySquadColor(replay, member.name),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Icon(
                            _vehicleIcon(kind),
                            size: 13,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        );
      },
    ),
  );
}

/// 지도 위 자기장·동선·선수 점. 확대해도 점과 선은 화면에서 같은 굵기로 보이게 그린다.
class _ReplayPainter extends CustomPainter {
  _ReplayPainter(
    this.replay,
    this.time, {
    required this.showPaths,
    required this.showEnemies,
    required this.controller,
  }) : super(repaint: controller);
  final MatchReplay replay;
  final double time;
  final bool showPaths;
  final bool showEnemies;
  final TransformationController controller;

  @override
  void paint(Canvas canvas, Size size) {
    // 화면 픽셀 기준 크기를 지도 좌표로 바꾸는 비율.
    final k = 1 / controller.value.getMaxScaleOnViewport();
    Offset at(double x, double y) => Offset(x * size.width, y * size.height);
    final zone = replay.zones.where((z) => z.timeMs <= time).lastOrNull;
    void drawZone(double? x, double? y, double? radius, Color color) {
      if (x == null || y == null || radius == null || radius <= 0) return;
      canvas.drawCircle(
        at(x, y),
        radius * size.width,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k,
      );
    }

    drawZone(zone?.whiteX, zone?.whiteY, zone?.whiteRadius, Colors.white);
    drawZone(
      zone?.blueX,
      zone?.blueY,
      zone?.blueRadius,
      Colors.lightBlueAccent,
    );

    if (showEnemies) {
      final enemyPaint = Paint()..color = BgmsColors.defeat;
      for (final enemy in replay.enemies) {
        final position = enemy.at(time);
        // 수송기 안의 적은 모두 한 점에 겹치므로 그리지 않는다.
        if (position == null ||
            replayVehicleKind(position.vehicle) == ReplayVehicleKind.plane) {
          continue;
        }
        canvas.drawCircle(at(position.x, position.y), 2.5 * k, enemyPaint);
      }
    }

    for (final fight in replay.fights) {
      final x = fight.x;
      final y = fight.y;
      if (fight.timeMs > time || x == null || y == null) continue;
      final center = at(x, y);
      final paint = Paint()
        ..color = _fightColor(fight.type)
        ..strokeWidth = 2 * k;
      final arm = Offset(4, 4) * k;
      final otherArm = Offset(4, -4) * k;
      if (fight.type == 'kill') {
        canvas.drawLine(center - arm, center + arm, paint);
        canvas.drawLine(center - otherArm, center + otherArm, paint);
      } else if (fight.type == 'groggy') {
        canvas.drawCircle(center, 3 * k, paint);
      }
    }

    for (final member in replay.squad) {
      final color = replaySquadColor(replay, member.name);
      if (showPaths) _drawPath(canvas, size, member, color, k);
      final position = member.at(time);
      // 탈것에 탄 경우 _VehicleBadges가 아이콘으로 그린다.
      if (position != null && position.vehicle == null) {
        final center = at(position.x, position.y);
        canvas.drawCircle(center, 6 * k, Paint()..color = Colors.black);
        canvas.drawCircle(center, 5 * k, Paint()..color = color);
      }
    }
  }

  /// 걷는 구간은 실선, 탈것 구간은 점선으로 그린다. 수송기 비행 경로는 생략한다.
  void _drawPath(
    Canvas canvas,
    Size size,
    ReplayTrack member,
    Color color,
    double k,
  ) {
    final foot = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * k;
    final ride = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2 * k;
    for (final segment in member.segmentsAt(time)) {
      for (var i = 1; i < segment.length; i++) {
        final from = segment[i - 1];
        final to = segment[i];
        final kind = replayVehicleKind(from.vehicle);
        if (kind == ReplayVehicleKind.plane) continue;
        final a = Offset(from.x * size.width, from.y * size.height);
        final b = Offset(to.x * size.width, to.y * size.height);
        if (kind == null) {
          canvas.drawLine(a, b, foot);
        } else {
          _dashed(canvas, a, b, ride, k);
        }
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, double k) {
    final distance = (b - a).distance;
    if (distance == 0) return;
    final step = (b - a) / distance;
    for (var d = 0.0; d < distance; d += 7 * k) {
      canvas.drawLine(
        a + step * d,
        a + step * (d + 4 * k > distance ? distance : d + 4 * k),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ReplayPainter old) =>
      old.time != time ||
      old.replay != replay ||
      old.showPaths != showPaths ||
      old.showEnemies != showEnemies;
}
