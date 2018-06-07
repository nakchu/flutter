import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';


void main() {
  group(AnnotatedRegion, () {
    test('finds the first value in a ContainerLayer of OffsetLayers without clipped children', () {
      final ContainerLayer containerLayer = new ContainerLayer();
      final List<OffsetLayer> layers = <OffsetLayer>[
        new OffsetLayer(offset: Offset.zero),
        new OffsetLayer(offset: const Offset(0.0, 100.0)),
        new OffsetLayer(offset: const Offset(0.0, 200.0)),
      ];
      int i = 0;
      for (OffsetLayer layer in layers) {
        layer.append(new AnnotatedRegionLayer<int>(i));
        containerLayer.append(layer);
        i += 1;
      }

      expect(containerLayer.findRegion(const Offset(0.0, 1.0), int), 0);
      expect(containerLayer.findRegion(const Offset(0.0, 101.0), int), 0);
      expect(containerLayer.findRegion(const Offset(0.0, 201.0), int), 0);
    });

    test('finds a value within the clip in a ContainerLayer of ClipRectLayer', () {
      final ContainerLayer containerLayer = new ContainerLayer();
      final List<ClipRectLayer> layers = <ClipRectLayer>[
        new ClipRectLayer(clipRect: new Rect.fromLTRB(0.0, 0.0, 100.0, 100.0)),
        new ClipRectLayer(clipRect: new Rect.fromLTRB(0.0, 100.0, 100.0, 200.0)),
        new ClipRectLayer(clipRect: new Rect.fromLTRB(0.0, 200.0, 100.0, 300.0)),
      ];
      int i = 0;
      for (ClipRectLayer layer in layers) {
        layer.append(new AnnotatedRegionLayer<int>(i));
        containerLayer.append(layer);
        i += 1;
      }

      expect(containerLayer.findRegion(const Offset(0.0, 1.0), int), 0);
      expect(containerLayer.findRegion(const Offset(0.0, 101.0), int), 1);
      expect(containerLayer.findRegion(const Offset(0.0, 201.0), int), 2);
    });


    test('finds a value within the clip in a ContainerLayer of ClipRRectLayer', () {
      final ContainerLayer containerLayer = new ContainerLayer();
      final List<ClipRRectLayer> layers = <ClipRRectLayer>[
        new ClipRRectLayer(clipRRect: new RRect.fromLTRBR(0.0, 0.0, 100.0, 100.0, const Radius.circular(4.0))),
        new ClipRRectLayer(clipRRect: new RRect.fromLTRBR(0.0, 100.0, 100.0, 200.0, const Radius.circular(4.0))),
        new ClipRRectLayer(clipRRect: new RRect.fromLTRBR(0.0, 200.0, 100.0, 300.0, const Radius.circular(4.0))),
      ];
      int i = 0;
      for (ClipRRectLayer layer in layers) {
        layer.append(new AnnotatedRegionLayer<int>(i));
        containerLayer.append(layer);
        i += 1;
      }

      expect(containerLayer.findRegion(const Offset(5.0, 5.0), int), 0);
      expect(containerLayer.findRegion(const Offset(5.0, 105.0), int), 1);
      expect(containerLayer.findRegion(const Offset(5.0, 205.0), int), 2);
    });
  });
}

