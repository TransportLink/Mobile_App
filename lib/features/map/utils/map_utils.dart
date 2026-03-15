import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/route.dart' as route_models;

class MapUtils {
  List<Marker> buildBusStopMarkers(List<BusStop> busStops) {
    return busStops.map((stop) {
      return Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 60,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stop.totalCount?.toString() ?? '0',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Icon(
              Icons.directions_bus,
              color: Colors.blue,
              size: 30,
            ),
          ],
        ),
      );
    }).toList();
  }

  Marker buildUserLocationMarker(geo.Position position) {
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 24,
          ),
        ),
      ),
    );
  }

  LatLngBounds? calculateCameraBounds(
    geo.Position position,
    List<BusStop> busStops,
  ) {
    if (busStops.isEmpty) return null;

    final sortedBusStops = List<BusStop>.from(busStops)
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
    final points = [
      LatLng(position.latitude, position.longitude),
      ...closestStops.map((stop) => LatLng(stop.latitude, stop.longitude)),
    ];

    return LatLngBounds.fromPoints(points);
  }

  Polyline? buildRoutePolyline(route_models.Route route) {
    if (route.coordinates.isEmpty) return null;

    final points = route.coordinates
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();

    return Polyline(
      points: points,
      color: Colors.red.withOpacity(0.7),
      strokeWidth: 6.0,
    );
  }
}
