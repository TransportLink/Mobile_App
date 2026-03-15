/// Driver earnings data model
class DriverEarnings {
  final String id;
  final double amount;
  final int passengerCount;
  final String routeSummary;
  final DateTime tripCompletedAt;
  final List<EarningsBreakdown> breakdown;

  DriverEarnings({
    required this.id,
    required this.amount,
    required this.passengerCount,
    required this.routeSummary,
    required this.tripCompletedAt,
    required this.breakdown,
  });

  factory DriverEarnings.fromMap(Map<String, dynamic> map) {
    return DriverEarnings(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      passengerCount: map['passenger_count'] ?? 0,
      routeSummary: map['route_summary'] ?? '',
      tripCompletedAt: DateTime.parse(map['trip_completed_at']),
      breakdown: (map['breakdown'] as List<dynamic>?)
              ?.map((b) => EarningsBreakdown.fromMap(b))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'passenger_count': passengerCount,
      'route_summary': routeSummary,
      'trip_completed_at': tripCompletedAt.toIso8601String(),
      'breakdown': breakdown.map((b) => b.toMap()).toList(),
    };
  }
}

/// Breakdown of earnings by destination
class EarningsBreakdown {
  final String destination;
  final int passengers;
  final double farePerPassenger;
  final double subtotal;

  EarningsBreakdown({
    required this.destination,
    required this.passengers,
    required this.farePerPassenger,
    required this.subtotal,
  });

  factory EarningsBreakdown.fromMap(Map<String, dynamic> map) {
    return EarningsBreakdown(
      destination: map['destination'] ?? '',
      passengers: map['passengers'] ?? 0,
      farePerPassenger: (map['fare_per_passenger'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'destination': destination,
      'passengers': passengers,
      'fare_per_passenger': farePerPassenger,
      'subtotal': subtotal,
    };
  }
}

/// Driver statistics for different periods
class DriverStats {
  final String driverId;
  final PeriodStats today;
  final PeriodStats thisWeek;
  final PeriodStats thisMonth;
  final PeriodStats allTime;

  DriverStats({
    required this.driverId,
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.allTime,
  });

  factory DriverStats.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? map;
    return DriverStats(
      driverId: data['driver_id'] ?? '',
      today: PeriodStats.fromMap(data['today'] as Map<String, dynamic>? ?? {}),
      thisWeek:
          PeriodStats.fromMap(data['this_week'] as Map<String, dynamic>? ?? {}),
      thisMonth: PeriodStats.fromMap(
          data['this_month'] as Map<String, dynamic>? ?? {}),
      allTime:
          PeriodStats.fromMap(data['all_time'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driver_id': driverId,
      'today': today.toMap(),
      'this_week': thisWeek.toMap(),
      'this_month': thisMonth.toMap(),
      'all_time': allTime.toMap(),
    };
  }
}

/// Statistics for a specific period
class PeriodStats {
  final int trips;
  final int passengers;
  final double earnings;
  final double hoursActive;

  PeriodStats({
    required this.trips,
    required this.passengers,
    required this.earnings,
    required this.hoursActive,
  });

  factory PeriodStats.fromMap(Map<String, dynamic> map) {
    return PeriodStats(
      trips: map['trips'] ?? 0,
      passengers: map['passengers'] ?? 0,
      earnings: (map['earnings'] ?? 0).toDouble(),
      hoursActive: (map['hours_active'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trips': trips,
      'passengers': passengers,
      'earnings': earnings,
      'hours_active': hoursActive,
    };
  }
}
