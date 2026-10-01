import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import 'map_models.dart';
import 'map_view_helpers.dart';
import 'maps_screen.dart';

/// 48px 터치 영역이 겹치는 마커를 인접 격자까지 확인해 묶는다.
List<List<MapMarker>> clusterMapMarkers(
  List<MapMarker> markers, {
  required double width,
  required double height,
  required double scale,
}) {
  final cells = <(int, int), List<int>>{};
  final parents = List.generate(markers.length, (index) => index);
  int root(int index) {
    while (parents[index] != index) {
      parents[index] = parents[parents[index]];
      index = parents[index];
    }
    return index;
  }

  for (var index = 0; index < markers.length; index++) {
    final marker = markers[index];
    final x = marker.x * width * scale;
    final y = marker.y * height * scale;
    final cellX = (x / 48).floor();
    final cellY = (y / 48).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final otherIndex
            in cells[(cellX + dx, cellY + dy)] ?? const <int>[]) {
          final other = markers[otherIndex];
          if ((x - other.x * width * scale).abs() < 48 &&
              (y - other.y * height * scale).abs() < 48) {
            parents[root(index)] = root(otherIndex);
          }
        }
      }
    }
    (cells[(cellX, cellY)] ??= []).add(index);
  }
  final groups = <int, List<MapMarker>>{};
  for (var index = 0; index < markers.length; index++) {
    (groups[root(index)] ??= []).add(markers[index]);
  }
  return groups.values.toList();
}

/// 화면상 48px 안에 겹치는 마커는 개수로 표시하고 목록에서 선택한다.
class MapMarkerOverlay extends StatelessWidget {
  const MapMarkerOverlay({
    super.key,
    required this.markers,
    required this.scale,
    required this.onMarkerTap,
  });
  final List<MapMarker> markers;
  final double scale;
  final ValueChanged<MapMarker> onMarkerTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final groups = clusterMapMarkers(
        markers,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        scale: scale,
      );
      return Stack(
        children: [
          for (final group in groups)
            Positioned(
              left: group.first.x * constraints.maxWidth - 24,
              top: group.first.y * constraints.maxHeight - 24,
              width: 48,
              height: 48,
              child: Transform.scale(
                scale: 1 / scale,
                child: group.length == 1
                    ? MapMarkerWidget(
                        marker: group.first,
                        onTap: () => onMarkerTap(group.first),
                      )
                    : Semantics(
                        button: true,
                        label: '마커 ${group.length}개',
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: BgmsColors.accent,
                              foregroundColor: BgmsColors.bgBase,
                            ),
                            onPressed: () async {
                              final selected =
                                  await showModalBottomSheet<MapMarker>(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: ListView.builder(
                                        itemCount: group.length,
                                        itemBuilder: (context, index) =>
                                            ListTile(
                                              title: Text(group[index].label),
                                              subtitle: Text(
                                                getCategoryLabel(
                                                  group[index].layer,
                                                ),
                                              ),
                                              onTap: () => Navigator.pop(
                                                context,
                                                group[index],
                                              ),
                                            ),
                                      ),
                                    ),
                                  );
                              if (selected != null && context.mounted) {
                                onMarkerTap(selected);
                              }
                            },
                            child: Text('${group.length}'),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      );
    },
  );
}
