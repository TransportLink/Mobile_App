// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:mobileapp/core/model/bus_stop.dart';
import 'package:mobileapp/core/model/destination.dart';
import 'package:mobileapp/core/model/route.dart' as route_models;

// ignore_for_file: non_constant_identifier_names

class UserModel {
  final String id;
  final String full_name;
  final String email;
  final String password_hash;
  final String phone_number;
  final String date_of_birth;
  final String license_number;
  final String license_expiry;
  final String national_id;
  final String? profile_photo_url;
  final List<BusStop>? busStops;
  final route_models.Route? currentRoute;
  final Destination? currentDestination;
  final String? driverId;
  final double? searchRadius;

  UserModel({
    required this.id,
    required this.full_name,
    required this.email,
    required this.password_hash,
    required this.phone_number,
    required this.date_of_birth,
    required this.license_number,
    required this.license_expiry,
    required this.national_id,
    this.profile_photo_url,
    this.busStops,
    this.currentRoute,
    this.currentDestination,
    this.driverId,
    this.searchRadius,
  });

  /// Infer role from profile data — drivers have a license number
  bool get isDriver => license_number.isNotEmpty;
  bool get isPassenger => license_number.isEmpty;

  UserModel copyWith({
    String? id,
    String? full_name,
    String? email,
    String? password_hash,
    String? phone_number,
    String? date_of_birth,
    String? license_number,
    String? license_expiry,
    String? national_id,
    String? profile_photo_url,
    List<BusStop>? busStops,
    route_models.Route? currentRoute,
    Destination? currentDestination,
    String? driverId,
    double? searchRadius,
  }) {
    return UserModel(
        id: id ?? this.id,
        full_name: full_name ?? this.full_name,
        email: email ?? this.email,
        password_hash: password_hash ?? this.password_hash,
        phone_number: phone_number ?? this.phone_number,
        date_of_birth: date_of_birth ?? this.date_of_birth,
        license_number: license_number ?? this.license_number,
        license_expiry: license_expiry ?? this.license_expiry,
        national_id: national_id ?? this.national_id,
        busStops: busStops ?? this.busStops,
        currentRoute: currentRoute ?? this.currentRoute,
        currentDestination: currentDestination ?? this.currentDestination,
        driverId: driverId ?? this.driverId,
        searchRadius: searchRadius ?? this.searchRadius,
        profile_photo_url: profile_photo_url ?? this.profile_photo_url);
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? map['driver_id'] ?? '',
      full_name: map['full_name'] ?? '',
      email: map['email'] ?? '',
      password_hash: map['password_hash'] ?? '',
      phone_number: map['phone_number'] ?? '',
      date_of_birth: map['date_of_birth'] ?? '',
      license_number: map['license_number'] ?? '',
      license_expiry: map['license_expiry'] ?? '',
      national_id: map['national_id'] ?? '',
      profile_photo_url: map['profile_photo_url'] ?? '',
      busStops: map['busStops'] != null
          ? List<BusStop>.from(
              (map['busStops'] as List<int>).map<BusStop?>(
                (x) => BusStop.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      currentRoute: map['currentRoute'] != null
          ? route_models.Route.fromMap(
              map['currentRoute'] as Map<String, dynamic>)
          : null,
      currentDestination: map['currentDestination'] != null
          ? Destination.fromMap(
              map['destination'] as Map<String, dynamic>)
          : null,
      driverId: map['driverId'] ?? map['driver_id'] ?? '',
      searchRadius: map['searchRadius'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'full_name': full_name,
      'email': email,
      'password_hash': password_hash,
      'phone_number': phone_number,
      'date_of_birth': date_of_birth,
      'license_number': license_number,
      'license_expiry': license_expiry,
      'national_id': national_id,
      'profile_photo_url': profile_photo_url,
      'busStops': busStops?.map((x) => x.toMap()).toList(),
      'currentRoute': currentRoute?.toMap(),
      'currentDestination': currentDestination?.toMap(),
      'driverId': driverId,
      'searchRadius': searchRadius,
    };
  }
}
