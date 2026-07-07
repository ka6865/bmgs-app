import 'package:flutter/material.dart';
import 'map_models.dart';
import 'maps_screen.dart'; // 기존 타일모자이크 및 마커 사용을 위해

class MapFullscreenView extends StatelessWidget {
  const MapFullscreenView({
    super.key,
    required this.map,
    required this.markers,
    required this.activeLayers,
    required this.onMarkerTap,
  });

  final BgmsMap map;
  final List<MapMarker> markers;
  final Set<String> activeLayers;
  final Function(MapMarker) onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final visibleMarkers = markers.where((m) => activeLayers.contains(m.layer)).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${map.name} 정밀 지도', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 6.0,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: MapTileMosaic(map: map),
                  ),
                ),
                ...visibleMarkers.map(
                  (marker) => Align(
                    alignment: FractionalOffset(marker.x, marker.y),
                    child: MapMarkerWidget(
                      marker: marker,
                      onTap: () {
                        // 모달을 닫고 디테일을 띄우거나, 전체화면 안에서 디테일 노출
                        onMarkerTap(marker);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
