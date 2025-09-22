// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// ignore_for_file: non_constant_identifier_names

class DriverModel {
  final String id;
  final String full_name;
  final String email;
  final String password;
  final String phone_number;
  final String date_of_birth;
  final String license_number;
  final String license_expiry;
  final String national_id;
  DriverModel({
    required this.id,
    required this.full_name,
    required this.email,
    required this.password,
    required this.phone_number,
    required this.date_of_birth,
    required this.license_number,
    required this.license_expiry,
    required this.national_id,
  });

  DriverModel copyWith({
    String? id,
    String? full_name,
    String? email,
    String? password,
    String? phone_number,
    String? date_of_birth,
    String? license_number,
    String? license_expiry,
    String? national_id,
  }) {
    return DriverModel(
      id: id ?? this.id,
      full_name: full_name ?? this.full_name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone_number: phone_number ?? this.phone_number,
      date_of_birth: date_of_birth ?? this.date_of_birth,
      license_number: license_number ?? this.license_number,
      license_expiry: license_expiry ?? this.license_expiry,
      national_id: national_id ?? this.national_id,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'full_name': full_name,
      'email': email,
      'password': password,
      'phone_number': phone_number,
      'date_of_birth': date_of_birth,
      'license_number': license_number,
      'license_expiry': license_expiry,
      'national_id': national_id,
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      id: map['id'] as String,
      full_name: map['full_name'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      phone_number: map['phone_number'] as String,
      date_of_birth: map['date_of_birth'] as String,
      license_number: map['license_number'] as String,
      license_expiry: map['license_expiry'] as String,
      national_id: map['national_id'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory DriverModel.fromJson(String source) => DriverModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'DriverModel(id: $id, full_name: $full_name, email: $email, password: $password, phone_number: $phone_number, date_of_birth: $date_of_birth, license_number: $license_number, license_expiry: $license_expiry, national_id: $national_id)';
  }

  @override
  bool operator ==(covariant DriverModel other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.full_name == full_name &&
      other.email == email &&
      other.password == password &&
      other.phone_number == phone_number &&
      other.date_of_birth == date_of_birth &&
      other.license_number == license_number &&
      other.license_expiry == license_expiry &&
      other.national_id == national_id;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      full_name.hashCode ^
      email.hashCode ^
      password.hashCode ^
      phone_number.hashCode ^
      date_of_birth.hashCode ^
      license_number.hashCode ^
      license_expiry.hashCode ^
      national_id.hashCode;
  }
}
