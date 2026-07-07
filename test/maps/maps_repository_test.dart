import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/maps/maps_repository.dart';

void main() {
  test('filterActiveLayers restricts available layers based on admin settings', () {
    final repository = MapsRepository();
    final mockSettings = {
      'Erangel': ['Garage', 'SecretRoom'],
      'Miramar': ['Garage', 'HotDrop'],
    };
    
    final erangelLayers = ['Garage', 'SecretRoom', 'Glider', 'Boat'];
    final filtered = repository.filterActiveLayers('Erangel', erangelLayers, mockSettings);
    
    expect(filtered, contains('Garage'));
    expect(filtered, contains('SecretRoom'));
    expect(filtered, isNot(contains('Glider')));
  });
}
