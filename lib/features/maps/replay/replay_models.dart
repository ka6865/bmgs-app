class ReplayPosition {
  const ReplayPosition(this.timeMs, this.x, this.y);
  final double timeMs;
  final double x;
  final double y;
}

class ReplayFight {
  const ReplayFight(
    this.timeMs,
    this.type,
    this.attacker,
    this.victim,
    this.weapon,
  );
  final double timeMs;
  final String type;
  final String attacker;
  final String victim;
  final String weapon;
}

class ReplayZone {
  const ReplayZone(
    this.timeMs,
    this.whiteX,
    this.whiteY,
    this.whiteRadius,
    this.blueX,
    this.blueY,
    this.blueRadius,
  );
  final double timeMs;
  final double? whiteX, whiteY, whiteRadius, blueX, blueY, blueRadius;
}

class MatchReplay {
  const MatchReplay({
    required this.mapId,
    required this.positions,
    required this.fights,
    required this.zones,
  });
  final String mapId;
  final List<ReplayPosition> positions;
  final List<ReplayFight> fights;
  final List<ReplayZone> zones;

  /// 기록이 30초 넘게 끊긴 구간은 이동 선으로 이어 붙이지 않는다.
  List<List<ReplayPosition>> pathSegmentsAt(double timeMs) {
    final segments = <List<ReplayPosition>>[];
    for (final position in positions) {
      if (position.timeMs > timeMs) break;
      if (segments.isEmpty ||
          position.timeMs - segments.last.last.timeMs > 30000) {
        segments.add([]);
      }
      segments.last.add(position);
    }
    return segments;
  }

  double get durationMs => [
    positions.lastOrNull?.timeMs ?? 0,
    fights.lastOrNull?.timeMs ?? 0,
    zones.lastOrNull?.timeMs ?? 0,
  ].reduce((a, b) => a > b ? a : b);

  factory MatchReplay.fromJson(Map<String, dynamic> json, String nickname) {
    final map = json['mapName']?.toString().toLowerCase() ?? '';
    const aliases = {
      'erangel': 'Erangel',
      'baltic_main': 'Erangel',
      'miramar': 'Miramar',
      'desert_main': 'Miramar',
      'taego': 'Taego',
      'tiger_main': 'Taego',
      'rondo': 'Rondo',
      'neon_main': 'Rondo',
      'vikendi': 'Vikendi',
      'dihorotok_main': 'Vikendi',
      'deston': 'Deston',
      'kiki_main': 'Deston',
    };
    final mapId = aliases[map];
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
    final positions = <ReplayPosition>[];
    final fights = <ReplayFight>[];
    for (final event in events.whereType<Map>()) {
      final time = _number(event['relativeTimeMs']);
      if (time == null || time < 0) continue;
      if (event['type'] == 'position' &&
          event['name']?.toString().trim().toLowerCase() == name) {
        final x = _coordinate(event['x']);
        final y = _coordinate(event['y']);
        if (x != null && y != null) positions.add(ReplayPosition(time, x, y));
      }
      if (const ['kill', 'groggy', 'revive'].contains(event['type']) &&
          [
            event['attacker'],
            event['victim'],
          ].any((v) => v?.toString().trim().toLowerCase() == name)) {
        fights.add(
          ReplayFight(
            time,
            event['type'].toString(),
            event['attacker']?.toString() ?? '-',
            event['victim']?.toString() ?? '-',
            event['weapon']?.toString() ?? '',
          ),
        );
      }
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
        ),
      );
    }
    positions.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    fights.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    zones.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return MatchReplay(
      mapId: mapId,
      positions: positions,
      fights: fights,
      zones: zones,
    );
  }
}

double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
double? _coordinate(Object? value) {
  final number = _number(value);
  return number != null && number >= 0 && number <= 8192 ? number / 8192 : null;
}
