import 'package:flutter/material.dart';

/// Incoming Driver Information
class IncomingDriver {
  final String driverId;
  final String? licensePlate;
  final String? busColor;
  final int? eta;
  final int seatsAvailable;

  IncomingDriver({
    required this.driverId,
    this.licensePlate,
    this.busColor,
    this.eta,
    required this.seatsAvailable,
  });

  factory IncomingDriver.fromJson(Map<String, dynamic> json) {
    return IncomingDriver(
      driverId: json['driver_id'] ?? '',
      licensePlate: json['license_plate'],
      busColor: json['bus_color'],
      eta: json['eta'],
      seatsAvailable: json['seats_available'] ?? 0,
    );
  }
}

/// Passenger Check-In State
class PassengerCheckInState {
  final String? checkinId;
  final String systemId;
  final String destination;
  final int passengerCount;
  final int queuePosition;
  final int totalWaiting;
  final DateTime checkedInAt;
  final List<IncomingDriver> incomingDrivers;

  PassengerCheckInState({
    required this.checkinId,
    required this.systemId,
    required this.destination,
    required this.passengerCount,
    required this.queuePosition,
    required this.totalWaiting,
    required this.checkedInAt,
    required this.incomingDrivers,
  });

  factory PassengerCheckInState.fromJson(Map<String, dynamic> json) {
    return PassengerCheckInState(
      checkinId: json['checkin_id']?.toString(),
      systemId: json['system_id'],
      destination: json['destination'],
      passengerCount: json['passenger_count'] ?? 1,
      queuePosition: json['queue_position'] ?? 1,
      totalWaiting: json['total_waiting'] ?? 0,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      incomingDrivers: (json['incoming_drivers'] as List?)
              ?.map((d) => IncomingDriver.fromJson(d))
              .toList() ??
          [],
    );
  }

  PassengerCheckInState copyWith({
    String? checkinId,
    String? systemId,
    String? destination,
    int? passengerCount,
    int? queuePosition,
    int? totalWaiting,
    DateTime? checkedInAt,
    List<IncomingDriver>? incomingDrivers,
  }) {
    return PassengerCheckInState(
      checkinId: checkinId ?? this.checkinId,
      systemId: systemId ?? this.systemId,
      destination: destination ?? this.destination,
      passengerCount: passengerCount ?? this.passengerCount,
      queuePosition: queuePosition ?? this.queuePosition,
      totalWaiting: totalWaiting ?? this.totalWaiting,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      incomingDrivers: incomingDrivers ?? this.incomingDrivers,
    );
  }
}

/// Bus Stop Demand Information
class BusStopDemand {
  final String systemId;
  final Map<String, int> demand;
  final Map<String, List<IncomingDriver>> incomingDrivers;

  BusStopDemand({
    required this.systemId,
    required this.demand,
    required this.incomingDrivers,
  });

  factory BusStopDemand.fromJson(Map<String, dynamic> json) {
    final demandMap = <String, int>{};
    final incomingMap = <String, List<IncomingDriver>>{};

    final demand = json['demand'] as Map<String, dynamic>? ?? {};
    demand.forEach((key, value) {
      demandMap[key] = value as int;
    });

    final incoming = json['incoming_drivers'] as Map<String, dynamic>? ?? {};
    incoming.forEach((key, value) {
      incomingMap[key] = (value as List)
          .map((d) => IncomingDriver.fromJson(d as Map<String, dynamic>))
          .toList();
    });

    return BusStopDemand(
      systemId: json['system_id'],
      demand: demandMap,
      incomingDrivers: incomingMap,
    );
  }
}
