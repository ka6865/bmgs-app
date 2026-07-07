import 'package:flutter/material.dart';
import 'map_models.dart';
import 'maps_screen.dart'; // 기존 타일모자이크 및 마커 사용을 위해
import 'map_view_helpers.dart'; // Matrix4ScaleExtension 사용을 위해

class MapFullscreenView extends StatefulWidget {
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
  State<MapFullscreenView> createState() => _MapFullscreenViewState();
}

class _MapFullscreenViewState extends State<MapFullscreenView> {
  final TransformationController _transformationController = TransformationController();
  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleZoomChange);
  }

  void _handleZoomChange() {
    final zoomMatrix = _transformationController.value;
    final currentScale = zoomMatrix.getMaxScaleOnViewport();
    if (_zoomScaleNotifier.value != currentScale) {
      _zoomScaleNotifier.value = currentScale;
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleZoomChange);
    _transformationController.dispose();
    _zoomScaleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleMarkers = widget.markers.where((m) => widget.activeLayers.contains(m.layer)).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.map.name} 정밀 지도', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 6.0,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: MapTileMosaic(map: widget.map),
                  ),
                ),
                ...visibleMarkers.map(
                  (marker) => ValueListenableBuilder<double>(
                    valueListenable: _zoomScaleNotifier,
                    builder: (context, scale, child) {
                      return Align(
                        alignment: FractionalOffset(marker.x, marker.y),
                        child: Transform.scale(
                          scale: 1.0 / scale,
                          child: MapMarkerWidget(
                            marker: marker,
                            onTap: () {
                              widget.onMarkerTap(marker);
                            },
                          ),
                        ),
                      );
                    },
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
