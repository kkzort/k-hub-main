import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InteractiveSvgMap extends StatefulWidget {
  final String svgAsset;
  final List<SvgMarker> markers;
  final Function(Offset)? onMapTap;
  final double minScale;
  final double maxScale;
  final TransformationController? controller;

  const InteractiveSvgMap({
    super.key,
    required this.svgAsset,
    this.markers = const [],
    this.onMapTap,
    this.minScale = 1.0,
    this.maxScale = 50.0,
    this.controller,
  });

  @override
  State<InteractiveSvgMap> createState() => _InteractiveSvgMapState();
}

class _InteractiveSvgMapState extends State<InteractiveSvgMap> {
  late TransformationController _controller;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TransformationController();
    _controller.addListener(_handleTransformation);
    // İlk değeri alalım
    _currentScale = _controller.value.getMaxScaleOnAxis();
  }

  @override
  void dispose() {
    // Eğer dışarıdan bir controller gelmediyse biz dispose ediyoruz
    if (widget.controller == null) {
      _controller.removeListener(_handleTransformation);
      _controller.dispose();
    } else {
      _controller.removeListener(_handleTransformation);
    }
    super.dispose();
  }

  void _handleTransformation() {
    final double newScale = _controller.value.getMaxScaleOnAxis();
    if (newScale != _currentScale) {
      setState(() {
        _currentScale = newScale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: _controller,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          boundaryMargin: const EdgeInsets.all(0),
          child: Center(
            child: AspectRatio(
              aspectRatio: 1210 / 750, // SVG orijinal oranı
              child: LayoutBuilder(
                builder: (context, mapConstraints) {
                  return GestureDetector(
                    onTapUp: widget.onMapTap == null
                        ? null
                        : (details) {
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final localOffset = box.globalToLocal(details.globalPosition);
                            final x = localOffset.dx / mapConstraints.maxWidth;
                            final y = localOffset.dy / mapConstraints.maxHeight;
                            widget.onMapTap!(Offset(x, y));
                          },
                    child: Stack(
                      children: [
                        SvgPicture.asset(
                          widget.svgAsset,
                          width: mapConstraints.maxWidth,
                          height: mapConstraints.maxHeight,
                          fit: BoxFit.fill,
                        ),
                        ...widget.markers.map((marker) {
                          // Marker boyutu zoom yapıldıkça ters oranda küçülürse
                          // ekrandaki görsel boyutu sabit kalır.
                          final double displaySize = marker.size / _currentScale;
                          
                          return Positioned(
                            left: (marker.x * mapConstraints.maxWidth) - (displaySize / 2),
                            top: (marker.y * mapConstraints.maxHeight) - (displaySize / 2),
                            child: GestureDetector(
                              onTap: marker.onTap,
                              child: SizedBox(
                                width: displaySize,
                                height: displaySize,
                                child: marker.child,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }
              ),
            ),
          ),
        );
      },
    );
  }
}

class SvgMarker {
  final double x; // 0.0 to 1.0
  final double y; // 0.0 to 1.0
  final Widget child;
  final double size;
  final VoidCallback? onTap;

  SvgMarker({
    required this.x,
    required this.y,
    required this.child,
    this.size = 40,
    this.onTap,
  });
}
