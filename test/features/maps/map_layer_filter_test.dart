import 'package:bgms_mobile_app/features/maps/maps_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = MapsRepository();

  test('서버 설정이 없으면 내장 카테고리로 레이어를 좁힌다', () {
    // 마커 API는 허용 목록 밖의 레이어(Boat)도 함께 준다.
    final available = [
      'Boat',
      'Esports',
      'EsportsBoat',
      'Garage',
      'Glider',
      'SecretRoom',
    ];

    final allowed = repository.filterActiveLayers('Erangel', available, {});

    // 에란겔에는 Boat가 없어야 한다. 웹과 동일한 기준이다.
    expect(allowed, isNot(contains('Boat')));
    expect(allowed, contains('Garage'));
    expect(allowed, contains('SecretRoom'));
  });

  test('서버 설정이 있으면 그 값을 우선한다', () {
    final allowed = repository.filterActiveLayers(
      'Erangel',
      ['Garage', 'Boat', 'Glider'],
      {
        'Erangel': ['Garage'],
      },
    );

    expect(allowed, ['Garage']);
  });

  test('맵 아이디 대소문자가 달라도 매칭한다', () {
    final allowed = repository.filterActiveLayers('erangel', [
      'Garage',
      'Boat',
    ], {});

    expect(allowed, contains('Garage'));
    expect(allowed, isNot(contains('Boat')));
  });

  test('모르는 맵은 받은 레이어를 그대로 준다', () {
    final allowed = repository.filterActiveLayers('UnknownMap', [
      'Garage',
      'Boat',
    ], {});

    expect(allowed, ['Garage', 'Boat']);
  });
}
