/// Demand data models for driver opportunities.
/// 
/// Task 2.5: Demand List View

/// Demand data response from /demand/broadcast endpoint
class DemandData {
  final DriverLocation driverLocation;
  final double searchRadiusKm;
  final String timestamp;
  final DemandSummary summary;
  final List<BusStopOpportunity> busStops;

  DemandData({
    required this.driverLocation,
    required this.searchRadiusKm,
    required this.timestamp,
    required this.summary,
    required this.busStops,
  });

  factory DemandData.fromMap(Map<String, dynamic> map) {
    return DemandData(
      driverLocation: DriverLocation.fromMap(map['driver_location'] ?? {}),
      searchRadiusKm: (map['search_radius_km'] ?? 0).toDouble(),
      timestamp: map['timestamp'] ?? '',
      summary: DemandSummary.fromMap(map['summary'] ?? {}),
      busStops: (map['bus_stops'] as List<dynamic>?)
              ?.map((s) => BusStopOpportunity.fromMap(s))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driver_location': driverLocation.toMap(),
      'search_radius_km': searchRadiusKm,
      'timestamp': timestamp,
      'summary': summary.toMap(),
      'bus_stops': busStops.map((s) => s.toMap()).toList(),
    };
  }
}

/// Driver location
class DriverLocation {
  final double latitude;
  final double longitude;

  DriverLocation({required this.latitude, required this.longitude});

  factory DriverLocation.fromMap(Map<String, dynamic> map) {
    return DriverLocation(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Demand summary
class DemandSummary {
  final int busStopsFound;
  final int highDemandStops;
  final int totalPassengers;
  final BestOpportunity? bestOpportunity;

  DemandSummary({
    required this.busStopsFound,
    required this.highDemandStops,
    required this.totalPassengers,
    this.bestOpportunity,
  });

  factory DemandSummary.fromMap(Map<String, dynamic> map) {
    return DemandSummary(
      busStopsFound: map['bus_stops_found'] ?? 0,
      highDemandStops: map['high_demand_stops'] ?? 0,
      totalPassengers: map['total_passengers'] ?? 0,
      bestOpportunity: map['best_opportunity'] != null
          ? BestOpportunity.fromMap(map['best_opportunity'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bus_stops_found': busStopsFound,
      'high_demand_stops': highDemandStops,
      'total_passengers': totalPassengers,
      'best_opportunity': bestOpportunity?.toMap(),
    };
  }
}

/// Best opportunity summary
class BestOpportunity {
  final String? location;
  final double? revenueScore;
  final double? etaMinutes;

  BestOpportunity({
    this.location,
    this.revenueScore,
    this.etaMinutes,
  });

  factory BestOpportunity.fromMap(Map<String, dynamic> map) {
    return BestOpportunity(
      location: map['location'],
      revenueScore: (map['revenue_score'] ?? 0).toDouble(),
      etaMinutes: (map['eta_minutes'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'revenue_score': revenueScore,
      'eta_minutes': etaMinutes,
    };
  }
}

/// Bus stop opportunity
class BusStopOpportunity {
  final String? systemId;
  final String? location;
  final Coordinates? coordinates;
  final double? distanceKm;
  final double? etaMinutes;
  final Map<String, DestinationDemand> demand;
  final int? totalPassengers;
  final int? driversEnRoute;
  final double? revenueScore;
  final String? demandLevel;
  final List<String> destinations;
  final double? estimatedRevenue;

  BusStopOpportunity({
    this.systemId,
    this.location,
    this.coordinates,
    this.distanceKm,
    this.etaMinutes,
    required this.demand,
    this.totalPassengers,
    this.driversEnRoute,
    this.revenueScore,
    this.demandLevel,
    required this.destinations,
    this.estimatedRevenue,
  });

  factory BusStopOpportunity.fromMap(Map<String, dynamic> map) {
    final demandMap = <String, DestinationDemand>{};
    final demandData = map['demand'] as Map<String, dynamic>? ?? {};
    demandData.forEach((key, value) {
      demandMap[key] = DestinationDemand.fromMap(value);
    });

    return BusStopOpportunity(
      systemId: map['system_id'],
      location: map['location'],
      coordinates: map['coordinates'] != null
          ? Coordinates.fromMap(map['coordinates'])
          : null,
      distanceKm: (map['distance_km'] ?? 0).toDouble(),
      etaMinutes: (map['eta_minutes'] ?? 0).toDouble(),
      demand: demandMap,
      totalPassengers: map['total_passengers'] ?? 0,
      driversEnRoute: map['drivers_en_route'] ?? 0,
      revenueScore: (map['revenue_score'] ?? 0).toDouble(),
      demandLevel: map['demand_level'],
      destinations: (map['destinations'] as List<dynamic>?)?.cast<String>() ?? [],
      estimatedRevenue: (map['estimated_revenue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'system_id': systemId,
      'location': location,
      'coordinates': coordinates?.toMap(),
      'distance_km': distanceKm,
      'eta_minutes': etaMinutes,
      'demand': demand.map((k, v) => MapEntry(k, v.toMap())),
      'total_passengers': totalPassengers,
      'drivers_en_route': driversEnRoute,
      'revenue_score': revenueScore,
      'demand_level': demandLevel,
      'destinations': destinations,
      'estimated_revenue': estimatedRevenue,
    };
  }
}

/// Coordinates
class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({required this.latitude, required this.longitude});

  factory Coordinates.fromMap(Map<String, dynamic> map) {
    return Coordinates(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Destination demand
class DestinationDemand {
  final int passengers;
  final double estimatedRevenue;

  DestinationDemand({
    required this.passengers,
    required this.estimatedRevenue,
  });

  factory DestinationDemand.fromMap(Map<String, dynamic> map) {
    return DestinationDemand(
      passengers: map['passengers'] ?? 0,
      estimatedRevenue: (map['estimated_revenue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'passengers': passengers,
      'estimated_revenue': estimatedRevenue,
    };
  }
}
