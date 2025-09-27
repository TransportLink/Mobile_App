class VehicleModel {
  final String? vehicleId;
  final String? driverId;
  final String plateNumber;
  final String? vehicleType;
  final String brand;
  final String model;
  final String year;
  final String color;
  final int? seatingCapacity;
  final String? insuranceNumber;
  final String? insuranceExpiryDate;
  final String? status;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VehicleModel({
    this.vehicleId,
    this.driverId,
    required this.plateNumber,
    this.vehicleType,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    this.seatingCapacity,
    this.insuranceNumber,
    this.insuranceExpiryDate,
    this.status,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      vehicleId: json['vehicle_id']?.toString(),
      driverId: json['driver_id']?.toString(),
      plateNumber: json['plate_number']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString(),
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      seatingCapacity: json['seating_capacity'] != null
          ? int.tryParse(json['seating_capacity'].toString())
          : null,
      insuranceNumber: json['insurance_number']?.toString(),
      insuranceExpiryDate: json['insurance_expiry_date']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'driver_id': driverId,
      'plate_number': plateNumber,
      'vehicle_type': vehicleType,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'seating_capacity': seatingCapacity,
      'status': status,
      'insurance_number': insuranceNumber,
      'insurance_expiry_date': insuranceExpiryDate,
      'photo_url': photoUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  VehicleModel copyWith({
    String? vehicleId,
    String? driverId,
    String? plateNumber,
    String? vehicleType,
    String? brand,
    String? model,
    String? year,
    String? color,
    String? status,
    int? seatingCapacity,
    String? insuranceNumber,
    String? insuranceExpiryDate,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleModel(
      vehicleId: vehicleId ?? this.vehicleId,
      driverId: driverId ?? this.driverId,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      status: status ?? this.status,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      insuranceNumber: insuranceNumber ?? this.insuranceNumber,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => '$year $brand $model';

  @override
  String toString() {
    return 'VehicleModel(vehicleId: $vehicleId, brand: $brand, model: $model, year: $year, plateNumber: $plateNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VehicleModel &&
        other.vehicleId == vehicleId &&
        other.driverId == driverId &&
        other.plateNumber == plateNumber &&
        other.vehicleType == vehicleType &&
        other.brand == brand &&
        other.model == model &&
        other.year == year &&
        other.color == color &&
        other.status == status &&
        other.seatingCapacity == seatingCapacity &&
        other.insuranceNumber == insuranceNumber &&
        other.insuranceExpiryDate == insuranceExpiryDate &&
        other.photoUrl == photoUrl;
  }

  @override
  int get hashCode {
    return vehicleId.hashCode ^
        driverId.hashCode ^
        plateNumber.hashCode ^
        vehicleType.hashCode ^
        brand.hashCode ^
        model.hashCode ^
        year.hashCode ^
        color.hashCode ^
        seatingCapacity.hashCode ^
        status.hashCode ^
        insuranceNumber.hashCode ^
        insuranceExpiryDate.hashCode ^
        photoUrl.hashCode;
  }
}
