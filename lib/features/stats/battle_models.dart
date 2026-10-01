class BattleComparison {
  const BattleComparison({
    required this.key,
    required this.label,
    required this.unit,
    required this.firstValue,
    required this.secondValue,
    required this.winner,
  });

  final String key;
  final String label;
  final String unit;
  final double? firstValue;
  final double? secondValue;
  final String winner;

  static BattleComparison fromJson(Map<String, dynamic> json) =>
      BattleComparison(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '지표',
        unit: json['unit']?.toString() ?? '',
        firstValue: _number(json['v1']),
        secondValue: _number(json['v2']),
        winner: json['winner']?.toString() ?? 'draw',
      );
}

class BattleResult {
  const BattleResult({
    required this.firstNickname,
    required this.secondNickname,
    required this.firstPlatform,
    required this.secondPlatform,
    required this.comparisons,
    required this.firstScore,
    required this.secondScore,
    required this.drawScore,
    required this.overallWinner,
    required this.comparisonMatchCount,
    required this.tacticalComparable,
    required this.withheldCount,
  });

  final String firstNickname;
  final String secondNickname;
  final String firstPlatform;
  final String secondPlatform;
  final List<BattleComparison> comparisons;
  final int firstScore;
  final int secondScore;
  final int drawScore;
  final String overallWinner;
  final int comparisonMatchCount;
  final bool tacticalComparable;
  final int withheldCount;

  static BattleResult fromJson(Map<String, dynamic> json) {
    final score = json['score'] is Map ? json['score'] as Map : const {};
    return BattleResult(
      firstNickname: json['nick1']?.toString() ?? '',
      secondNickname: json['nick2']?.toString() ?? '',
      firstPlatform: json['platform1']?.toString() ?? '',
      secondPlatform: json['platform2']?.toString() ?? '',
      comparisons: (json['comparisons'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (raw) => BattleComparison.fromJson(Map<String, dynamic>.from(raw)),
          )
          .toList(growable: false),
      firstScore: _integer(score['nick1']),
      secondScore: _integer(score['nick2']),
      drawScore: _integer(score['draw']),
      overallWinner: json['overallWinner']?.toString() ?? 'draw',
      comparisonMatchCount: _integer(json['comparisonMatchCount']),
      tacticalComparable: json['tacticalComparable'] == true,
      withheldCount: _integer(json['withheldCount']),
    );
  }
}

double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

int _integer(Object? value) => _number(value)?.round() ?? 0;
