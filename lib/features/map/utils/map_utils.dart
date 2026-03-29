import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/route.dart' as route_models;

class MapUtils {
  List<Marker> buildBusStopMarkers(List<BusStop> busStops) {
    return busStops.map((stop) {
      final count = stop.totalCount ?? 0;
      final hasPassengers = count > 0;

      return Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 56,
        height: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Passenger count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasPassengers ? Colors.green.shade700 : Colors.grey.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Bus stop pin
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasPassengers ? Colors.green.shade600 : Colors.grey.shade500,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.hail_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Driver location marker — shows a car icon with GPS accuracy ring.
  /// Heading rotates the icon when available.
  Marker buildUserLocationMarker(geo.Position position, {double? heading}) {
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // GPS accuracy ring
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.10),
              border: Border.all(color: Colors.green.withOpacity(0.25), width: 1),
            ),
          ),
          // Car icon with optional heading rotation
          Transform.rotate(
            angle: (heading ?? 0) * 3.14159265 / 180,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade600,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build camera bounds around the driver and nearby bus stops.
  /// When on trip, only includes the route destination — not all bus stops.
  LatLngBounds? calculateCameraBounds(
    geo.Position position,
    List<BusStop> busStops,
  ) {
    if (busStops.isEmpty) return null;

    final sortedBusStops = List<BusStop>.from(busStops)
      ..sort((a, b) {
        final distanceA = geo.Geolocator.distanceBetween(
          position.latitude, position.longitude,
          a.latitude, a.longitude,
        );
        final distanceB = geo.Geolocator.distanceBetween(
          position.latitude, position.longitude,
          b.latitude, b.longitude,
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
      color: Colors.green.shade600,
      strokeWidth: 5.0,
    );
  }
}
