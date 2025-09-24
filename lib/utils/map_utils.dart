import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../models/bus_stop.dart';
import '../models/route.dart' as route_models;

class MapUtils {
  Future<void> addBusStopMarkers(
    mapbox.MapboxMap? mapboxMap,
    mapbox.PointAnnotationManager? pointAnnotationManager,
    List<BusStop> busStops,
    BuildContext context,
  ) async {
    print("🛠️ Adding ${busStops.length} bus stop markers");
    await pointAnnotationManager?.deleteAll();
    final manager = await mapboxMap?.annotations.createPointAnnotationManager();
    if (manager == null) {
      print("❌ Failed to create PointAnnotationManager");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create marker manager')),
      );
      return;
    }
    final ByteData bytes = await rootBundle.load('assets/images/bus_stop.png');
    final Uint8List imageData = bytes.buffer.asUint8List();

    for (var stop in busStops) {
      try {
        print(
            "🚌 Adding marker for ${stop.systemId} at (${stop.latitude}, ${stop.longitude}) with ${stop.totalCount} passengers");
        await manager.create(mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
              coordinates: mapbox.Position(stop.longitude, stop.latitude)),
          image: imageData,
          iconSize: 0.8,
          textField: stop.totalCount?.toString() ?? '0',
          textOffset: [0.0, -2.0],
          textColor: Colors.blue.value,
          textHaloColor: Colors.white.value,
          textHaloWidth: 2.0,
          textSize: 20.0,
        ));
      } catch (e) {
        print("❌ Failed to add marker for ${stop.systemId}: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add marker for ${stop.systemId}: $e')),
        );
      }
    }
    pointAnnotationManager = manager;
    print("✅ Finished adding markers");
  }

  Future<void> showUserLocation(
    mapbox.MapboxMap? mapboxMap,
    mapbox.PointAnnotationManager? pointAnnotationManager,
    BuildContext context,
  ) async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      final center = mapbox.Point(
          coordinates: mapbox.Position(position.longitude, position.latitude));
      await pointAnnotationManager?.deleteAll();
      final manager =
          await mapboxMap?.annotations.createPointAnnotationManager();
      if (manager == null) {
        print("❌ Failed to create PointAnnotationManager for user location");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create marker manager')),
        );
        return;
      }
      final ByteData bytes =
          await rootBundle.load('assets/images/driver_loc.png');
      final Uint8List imageData = bytes.buffer.asUint8List();
      await manager.create(mapbox.PointAnnotationOptions(
        geometry: center,
        image: imageData,
        iconSize: 0.5,
      ));
      pointAnnotationManager = manager;
      print(
          "📍 User location marker added: ${position.latitude}, ${position.longitude}");
      await fitMapToBounds(mapboxMap, position, []);
    } catch (e) {
      print("❌ Error showing user location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to show user location')),
      );
    }
  }

  Future<void> fitMapToBounds(
    mapbox.MapboxMap? mapboxMap,
    geo.Position position,
    List<BusStop> busStops,
  ) async {
    if (mapboxMap == null) {
      print("❌ Mapbox map not initialized, skipping fit bounds");
      return;
    }

    if (busStops.isEmpty) {
      await mapboxMap.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
              coordinates:
                  mapbox.Position(position.longitude, position.latitude)),
          zoom: 14.0,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
      print(
          "✅ Map centered on driver location: (${position.longitude}, ${position.latitude})");
      return;
    }

    final sortedBusStops = busStops
      ..sort((a, b) {
        final distanceA = geo.Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.latitude,
          a.longitude,
        );
        final distanceB = geo.Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

    final closestStops = sortedBusStops.take(5).toList();
    final coordinates = [
      [position.longitude, position.latitude],
      ...closestStops.map((stop) => [stop.longitude, stop.latitude]),
    ];

    double minLon = coordinates[0][0];
    double maxLon = coordinates[0][0];
    double minLat = coordinates[0][1];
    double maxLat = coordinates[0][1];
    for (var coord in coordinates) {
      minLon = minLon < coord[0] ? minLon : coord[0];
      maxLon = maxLon > coord[0] ? maxLon : coord[0];
      minLat = minLat < coord[1] ? minLat : coord[1];
      maxLat = maxLat > coord[1] ? maxLat : coord[1];
    }

    final centerLon = (minLon + maxLon) / 2;
    final centerLat = (minLat + maxLat) / 2;
    final latDelta = (maxLat - minLat).abs();
    final lonDelta = (maxLon - minLon).abs();
    final maxDelta = latDelta > lonDelta ? latDelta : lonDelta;

    double zoomLevel;
    if (maxDelta < 0.005) {
      zoomLevel = 15.0;
    } else if (maxDelta < 0.02) {
      zoomLevel = 14.0;
    } else if (maxDelta < 0.05) {
      zoomLevel = 13.0;
    } else {
      zoomLevel = 12.0;
    }

    const padding = 0.005;
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    await mapboxMap.flyTo(
      mapbox.CameraOptions(
        center:
            mapbox.Point(coordinates: mapbox.Position(centerLon, centerLat)),
        zoom: zoomLevel,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
    print(
        "✅ Map fitted to bounds: center=($centerLon, $centerLat), zoom=$zoomLevel, bounds=[($minLon, $minLat), ($maxLon, $maxLat)]");
  }

  Future<void> showRoute(
    mapbox.MapboxMap? mapboxMap,
    route_models.Route route,
    BuildContext context,
  ) async {
    try {
      if (route.coordinates == null) {
        print("❌ Route coordinates are null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route coordinates are missing')),
        );
        return;
      }
      final geoJsonData = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': route.coordinates,
            },
            'properties': {'color': '#FF0000', 'width': 4.0},
          },
        ],
      };
      final jsonString = jsonEncode(geoJsonData);

      final style = mapboxMap?.style;
      if (style != null) {
        final layers = await style.getStyleLayers();
        final sources = await style.getStyleSources();
        if (layers.any((layer) => layer?.id == 'route-line-layer')) {
          await style.removeStyleLayer('route-line-layer');
          print("✅ Removed existing route-line-layer");
        }
        if (sources.any((source) => source?.id == 'route-line-source')) {
          await style.removeStyleSource('route-line-source');
          print("✅ Removed existing route-line-source");
        }
      }

      await mapboxMap?.style.addSource(
        mapbox.GeoJsonSource(id: 'route-line-source', data: jsonString),
      );
      await mapboxMap?.style.addLayer(
        mapbox.LineLayer(
          id: 'route-line-layer',
          sourceId: 'route-line-source',
          lineJoin: mapbox.LineJoin.ROUND,
          lineCap: mapbox.LineCap.ROUND,
          lineOpacity: 0.7,
          lineColor: Colors.red.value,
          lineWidth: 8.0,
        ),
      );

      final bounds = _calculateBounds(route.coordinates!);
      await mapboxMap?.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(
              (bounds[0][0] + bounds[1][0]) / 2,
              (bounds[0][1] + bounds[1][1]) / 2,
            ),
          ),
          zoom: 13.0,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
      print("✅ Route displayed");
    } catch (e) {
      print("❌ Error showing route: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to show route: $e')),
      );
    }
  }

  Future<void> clearRouteLayer(mapbox.MapboxMap? mapboxMap) async {
    try {
      final style = mapboxMap?.style;
      if (style != null) {
        final layers = await style.getStyleLayers();
        final sources = await style.getStyleSources();
        if (layers.any((layer) => layer?.id == 'route-line-layer')) {
          await style.removeStyleLayer('route-line-layer');
          print("✅ Removed route-line-layer");
        }
        if (sources.any((source) => source?.id == 'route-line-source')) {
          await style.removeStyleSource('route-line-source');
          print("✅ Removed route-line-source");
        }
      }
    } catch (e) {
      print("❌ Error clearing route layer: $e");
    }
  }

  List<List<double>> _calculateBounds(List<List<double>> coordinates) {
    double minLon = coordinates[0][0];
    double maxLon = coordinates[0][0];
    double minLat = coordinates[0][1];
    double maxLat = coordinates[0][1];
    for (var coord in coordinates) {
      minLon = minLon < coord[0] ? minLon : coord[0];
      maxLon = maxLon > coord[0] ? maxLon : coord[0];
      minLat = minLat < coord[1] ? minLat : coord[1];
      maxLat = maxLat > coord[1] ? maxLat : coord[1];
    }
    return [
      [minLon, minLat],
      [maxLon, maxLat]
    ];
  }
}
