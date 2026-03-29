import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// Shared tile layer for all map screens.
///
/// Uses CancellableNetworkTileProvider which:
/// - Properly cancels in-flight HTTP requests when tiles leave viewport
/// - Prevents connection flooding to OSM servers
/// - Reduces "Connection attempt cancelled" errors
/// - Works with any tile server
TileLayer buildCachedTileLayer() {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.airlectric.smarttrotro',
    tileProvider: CancellableNetworkTileProvider(),
    maxZoom: 18,
    keepBuffer: 3, // Keep 3 tiles beyond viewport for smooth panning
    errorTileCallback: (tile, error, stackTrace) {}, // Suppress tile errors
  );
}
