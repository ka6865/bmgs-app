import '../map_models.dart';

class ReplayPosition {
  const ReplayPosition(this.timeMs, this.x, this.y, {this.vehicle});
  final double timeMs;
  final double x;
  final double y;

  /// 탑승 중인 탈것 클래스 이름(예: `BP_Blanc_C`). 걸어 다니면 null.
  final String? vehicle;
}

enum ReplayVehicleKind { plane, glider, boat, car }

/// 탈것 클래스 이름을 아이콘 종류로 나눈다. 모르는 탈것은 차량으로 본다.
ReplayVehicleKind? replayVehicleKind(String? vehicle) {
  if (vehicle == null || vehicle.isEmpty) return null;
  final lower = vehicle.toLowerCase();
  if (lower.contains('transportaircraft')) return ReplayVehicleKind.plane;
  if (lower.contains('glider')) return ReplayVehicleKind.glider;
  if (lower.contains('boat') || lower.contains('aquarail')) {
    return ReplayVehicleKind.boat;
  }
  return ReplayVehicleKind.car;
}

/// 한 선수의 시각순 좌표. 서버는 약 10초 간격으로 기록한다.
class ReplayTrack {
  const ReplayTrack({
    required this.name,
    required this.teamId,
    required this.isTeam,
    required this.points,
  });

  final String name;
  final int teamId;
  final bool isTeam;
  final List<ReplayPosition> points;

  /// 기록 간격이 이보다 길면 선을 잇지 않고, 마지막 기록 뒤로는 사라진 것으로 본다.
  static const gapMs = 30000.0;

  /// [timeMs] 시점의 위치. 기록 사이는 직선 보간하고, 기록 밖이면 null.
  ReplayPosition? at(double timeMs) {
    if (points.isEmpty || timeMs < points.first.timeMs) return null;
    var low = 0;
    var high = points.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (points[mid].timeMs <= timeMs) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    final prev = points[low];
    if (low + 1 < points.length) {
      final next = points[low + 1];
      final span = next.timeMs - prev.timeMs;
      if (span > gapMs) return timeMs - prev.timeMs > gapMs ? null : prev;
      final t = span <= 0 ? 0.0 : (timeMs - prev.timeMs) / span;
      return ReplayPosition(
        timeMs,
        prev.x + (next.x - prev.x) * t,
        prev.y + (next.y - prev.y) * t,
        vehicle: prev.vehicle,
      );
    }
    return timeMs - prev.timeMs > gapMs ? null : prev;
  }

  /// [timeMs]까지 지나온 경로. 긴 기록 공백에서 끊는다.
  List<List<ReplayPosition>> segmentsAt(double timeMs) {
    final segments = <List<ReplayPosition>>[];
    for (final position in points) {
      if (position.timeMs > timeMs) break;
      if (segments.isEmpty ||
          position.timeMs - segments.last.last.timeMs > gapMs) {
        segments.add([]);
      }
      segments.last.add(position);
    }
    return segments;
  }
}

class ReplayFight {
  const ReplayFight(
    this.timeMs,
    this.type,
    this.attacker,
    this.victim,
    this.weapon, {
    this.x,
    this.y,
  });
  final double timeMs;
  final String type;
  final String attacker;
  final String victim;
  final String weapon;

  /// 피해자 위치(0~1). 없으면 지도에 표시하지 않는다.
  final double? x;
  final double? y;
}

class ReplayZone {
  const ReplayZone(
    this.timeMs,
    this.whiteX,
    this.whiteY,
    this.whiteRadius,
    this.blueX,
    this.blueY,
    this.blueRadius, {
    this.phase,
  });
  final double timeMs;
  final double? whiteX, whiteY, whiteRadius, blueX, blueY, blueRadius;
  final int? phase;
}

/// 지금 자기장이 기다리는 중인지 줄어드는 중인지와 그 남은 시간.
typedef ReplayZoneStatus = ({int? phase, bool shrinking, double remainingMs});

class MatchReplay {
  const MatchReplay({
    required this.mapId,
    required this.focusName,
    required this.tracks,
    required this.fights,
    required this.zones,
    this.teamNames = const [],
    this.feed = const [],
  });

  final String mapId;

  /// 조회한 플레이어 닉네임(소문자).
  final String focusName;
  final List<ReplayTrack> tracks;

  /// 아군이 가해자나 피해자인 처치·기절·부활만 담는다.
  final List<ReplayFight> fights;
  final List<ReplayZone> zones;

  /// 서버가 준 아군 순서(소문자). 색 순서를 정한다.
  final List<String> teamNames;

  /// 지도 위 킬 로그. 아군과 관계없이 모든 처치·기절이다.
  final List<ReplayFight> feed;

  ReplayTrack? get focus => tracks
      .where((track) => track.name.toLowerCase() == focusName)
      .firstOrNull;

  List<ReplayTrack> get squad {
    final members = tracks
        .where((track) => track.isTeam || track.name.toLowerCase() == focusName)
        .toList();
    members.sort((a, b) => squadIndex(a.name).compareTo(squadIndex(b.name)));
    return members;
  }

  List<ReplayTrack> get enemies =>
      tracks.where((track) => !squad.contains(track)).toList();

  /// 아군 색 순서. teamNames에 없으면 조회 플레이어를 맨 앞으로 둔다.
  int squadIndex(String name) {
    final lower = name.toLowerCase();
    final index = teamNames.indexOf(lower);
    if (index >= 0) return index;
    return lower == focusName ? -1 : teamNames.length;
  }

  List<ReplayPosition> get positions => focus?.points ?? const [];

  /// [timeMs] 시점 자기장 상태. 기록은 10초 간격이라 남은 시간도 그만큼 오차가 있다.
  ReplayZoneStatus? zoneStatusAt(double timeMs) {
    final index = zones.lastIndexWhere((zone) => zone.timeMs <= timeMs);
    if (index < 0) return null;
    final current = zones[index];
    final radius = current.blueRadius;
    if (radius == null) return null;
    const epsilon = 0.0005;
    final next = index + 1 < zones.length ? zones[index + 1] : null;
    final shrinking =
        next?.blueRadius != null && next!.blueRadius! < radius - epsilon;
    for (var i = index + 1; i < zones.length; i++) {
      final zone = zones[i];
      final blue = zone.blueRadius;
      if (blue == null) continue;
      final previous = zones[i - 1].blueRadius ?? blue;
      final done = shrinking
          ? blue >=
                previous -
                    epsilon // 더 이상 줄지 않으면 이번 수축 끝
          : blue < previous - epsilon; // 줄기 시작하면 대기 끝
      if (done) {
        final end = zones[i - 1].timeMs;
        return (
          phase: current.phase,
          shrinking: shrinking,
          remainingMs: (end - timeMs).clamp(0, double.infinity),
        );
      }
    }
    return null;
  }

  List<List<ReplayPosition>> pathSegmentsAt(double timeMs) =>
      focus?.segmentsAt(timeMs) ?? const [];

  double get durationMs => [
    for (final track in squad) track.points.lastOrNull?.timeMs ?? 0,
    fights.lastOrNull?.timeMs ?? 0,
    zones.lastOrNull?.timeMs ?? 0,
  ].fold(0, (a, b) => a > b ? a : b);

  factory MatchReplay.fromJson(Map<String, dynamic> json, String nickname) {
    final normalized = normalizeBgmsMapId(json['mapName']?.toString());
    final mapId = bgmsMapCatalog
        .where((map) => map.id.toLowerCase() == normalized)
        .firstOrNull
        ?.id;
    if (mapId == null) {
      throw const FormatException('현재 리플레이 지도는 6개 전술 맵을 지원합니다.');
    }
    final events = json['events'];
    final zoneEvents = json['zoneEvents'];
    if (events is! List ||
        zoneEvents is! List ||
        DateTime.tryParse(json['startTime']?.toString() ?? '') == null) {
      throw const FormatException('리플레이 파일의 형식을 확인할 수 없습니다.');
    }
    final name = nickname.trim().toLowerCase();
    final teamNames = [
      for (final teamName in (json['teamNames'] as List?) ?? const [])
        teamName.toString().trim().toLowerCase(),
    ];
    bool isSquad(Object? player) {
      final lower = player?.toString().trim().toLowerCase();
      return lower == name || teamNames.contains(lower);
    }

    final tracks = <ReplayTrack>[];
    // encoding v1: 좌표는 선수별 열 배열(tracks)에 있고 events에는 track 번호만 남는다.
    final rawTracks = json['tracks'];
    if (rawTracks is List) {
      for (final raw in rawTracks.whereType<Map>()) {
        final times = raw['t'];
        final xs = raw['x'];
        final ys = raw['y'];
        final vehicles = raw['veh'] is List ? raw['veh'] as List : const [];
        if (times is! List || xs is! List || ys is! List) continue;
        final count = [
          times.length,
          xs.length,
          ys.length,
        ].reduce((a, b) => a < b ? a : b);
        final points = <ReplayPosition>[];
        for (var i = 0; i < count; i++) {
          final time = _number(times[i]);
          final x = _coordinate(xs[i]);
          final y = _coordinate(ys[i]);
          if (time == null || time < 0 || x == null || y == null) continue;
          final vehicle = i < vehicles.length ? vehicles[i] : null;
          points.add(
            ReplayPosition(
              time,
              x,
              y,
              vehicle: vehicle is String ? vehicle : null,
            ),
          );
        }
        _addTrack(
          tracks,
          raw['name']?.toString() ?? '',
          _number(raw['teamId'])?.toInt() ?? -1,
          raw['isTeam'] == true,
          points,
        );
      }
    }

    // 이전 형식: 좌표가 position 이벤트로 섞여 있다.
    final legacy = <String, List<ReplayPosition>>{};
    final fights = <ReplayFight>[];
    final feed = <ReplayFight>[];
    // 위치 기록(10초 간격) 사이를 채우는 좌표. 사격·피해·탑승·하차·투척 순간의 위치다.
    final extras = <String, List<_ExtraPoint>>{};
    void extra(
      Object? player,
      Object? rawX,
      Object? rawY,
      double time, {
      bool? riding,
      String? vehicle,
    }) {
      final key = player?.toString().trim().toLowerCase() ?? '';
      final x = _coordinate(rawX);
      final y = _coordinate(rawY);
      if (key.isEmpty || x == null || y == null) return;
      extras
          .putIfAbsent(key, () => [])
          .add(
            _ExtraPoint(ReplayPosition(time, x, y, vehicle: vehicle), riding),
          );
    }

    for (final event in events.whereType<Map>()) {
      final time = _number(event['relativeTimeMs']);
      if (time == null || time < 0) continue;
      switch (event['type']) {
        case 'shot' || 'throw':
          extra(event['name'], event['x'], event['y'], time);
        case 'damage':
          extra(
            event['attackerName'],
            event['attackerX'],
            event['attackerY'],
            time,
          );
          extra(event['victimName'], event['x'], event['y'], time);
        case 'ride':
          final vehicle = event['vehicle']?.toString();
          extra(
            event['name'],
            event['x'],
            event['y'],
            time,
            riding: true,
            vehicle: vehicle,
          );
        case 'leave':
          extra(event['name'], event['x'], event['y'], time, riding: false);
      }
      if (event['type'] == 'position') {
        final x = _coordinate(event['x']);
        final y = _coordinate(event['y']);
        final player = event['name']?.toString().trim() ?? '';
        if (x != null && y != null && player.isNotEmpty) {
          legacy.putIfAbsent(player, () => []).add(ReplayPosition(time, x, y));
        }
      }
      if (const ['kill', 'groggy', 'revive'].contains(event['type'])) {
        final fight = ReplayFight(
          time,
          event['type'].toString(),
          event['attacker']?.toString() ?? '-',
          event['victim']?.toString() ?? '-',
          event['weapon']?.toString() ?? '',
          x: _coordinate(event['victimX'] ?? event['x']),
          y: _coordinate(event['victimY'] ?? event['y']),
        );
        if (event['type'] != 'revive') feed.add(fight);
        if ([event['attacker'], event['victim']].any(isSquad)) {
          fights.add(fight);
        }
      }
    }
    legacy.forEach((player, points) {
      _addTrack(tracks, player, -1, isSquad(player), points);
    });
    for (var i = 0; i < tracks.length; i++) {
      final more = extras[tracks[i].name.toLowerCase()];
      if (more != null) tracks[i] = _withExtras(tracks[i], more);
    }

    final zones = <ReplayZone>[];
    for (final row in zoneEvents.whereType<Map>()) {
      final time = _number(row['relativeTimeMs']);
      if (time == null || time < 0) continue;
      zones.add(
        ReplayZone(
          time,
          _coordinate(row['whiteX']),
          _coordinate(row['whiteY']),
          _coordinate(row['whiteRadius']),
          _coordinate(row['blueX']),
          _coordinate(row['blueY']),
          _coordinate(row['blueRadius']),
          phase: _number(row['phase'])?.toInt(),
        ),
      );
    }
    fights.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    feed.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    zones.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return MatchReplay(
      mapId: mapId,
      focusName: name,
      tracks: tracks,
      fights: fights,
      zones: zones,
      teamNames: teamNames,
      feed: feed,
    );
  }
}

void _addTrack(
  List<ReplayTrack> tracks,
  String name,
  int teamId,
  bool isTeam,
  List<ReplayPosition> points,
) {
  if (name.isEmpty || points.isEmpty) return;
  points.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  tracks.add(
    ReplayTrack(name: name, teamId: teamId, isTeam: isTeam, points: points),
  );
}

class _ExtraPoint {
  const _ExtraPoint(this.position, this.riding);
  final ReplayPosition position;

  /// 탑승(true)·하차(false) 순간이면 그 상태로, 아니면(null) 앞 위치의 탈것을 이어받는다.
  final bool? riding;
}

/// 이벤트 좌표를 위치 기록 사이에 끼워 넣고, 탈것 상태는 앞 기록에서 이어받는다.
ReplayTrack _withExtras(ReplayTrack track, List<_ExtraPoint> extras) {
  final merged = <(ReplayPosition, bool?, bool)>[
    for (final point in track.points) (point, null, true),
    for (final extra in extras) (extra.position, extra.riding, false),
  ]..sort((a, b) => a.$1.timeMs.compareTo(b.$1.timeMs));
  final points = <ReplayPosition>[];
  String? vehicle;
  for (final (point, riding, recorded) in merged) {
    if (recorded) {
      vehicle = point.vehicle;
      points.add(point);
      continue;
    }
    if (riding == true) vehicle = point.vehicle;
    if (riding == false) vehicle = null;
    points.add(
      ReplayPosition(point.timeMs, point.x, point.y, vehicle: vehicle),
    );
  }
  return ReplayTrack(
    name: track.name,
    teamId: track.teamId,
    isTeam: track.isTeam,
    points: points,
  );
}

double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

/// 리플레이 좌표는 맵 한 변을 8192로 나눈 단위다.
double? _coordinate(Object? value) {
  final number = _number(value);
  return number != null && number >= 0 && number <= 8192 ? number / 8192 : null;
}
