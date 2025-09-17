import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> addBlueMarkerImage(MapboxMap mapboxMap) async {
  // Load image bytes from assets
  final byteData = await rootBundle.load('assets/images/ic_blue_marker.png');
  final bytes = byteData.buffer.asUint8List();

  // Create MbxImage (adjust width/height as needed or use decode)
  final image = MbxImage(
    width: 64,   // should match your image size or scale ratio
    height: 64,  // should match your image size or scale ratio
    data: bytes,
  );

  // Add image to Mapbox style
  await mapboxMap.style.addStyleImage(
    'blue-marker', // name you will use in your layers
    1.0,           // pixel ratio
    image,
    false,         // set to true only if using SDF (for icon tinting)
    [],            // stretchX (used for 9-patch images, leave empty)
    [],            // stretchY
    [] as ImageContent?,           // scale
  );
}
