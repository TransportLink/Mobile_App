// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class DriverDocument {
  final String document_id;
  final String driver_id;
  final String document_type;
  final String document_number;
  final String document_file_url;
  final String expiry_date;
  final String status;
  final String uploaded_at;
  DriverDocument({
    required this.document_id,
    required this.driver_id,
    required this.document_type,
    required this.document_number,
    required this.document_file_url,
    required this.expiry_date,
    required this.status,
    required this.uploaded_at,
  });

  DriverDocument copyWith({
    String? document_id,
    String? driver_id,
    String? document_type,
    String? document_number,
    String? document_file_url,
    String? expiry_date,
    String? status,
    String? uploaded_at,
  }) {
    return DriverDocument(
      document_id: document_id ?? this.document_id,
      driver_id: driver_id ?? this.driver_id,
      document_type: document_type ?? this.document_type,
      document_number: document_number ?? this.document_number,
      document_file_url: document_file_url ?? this.document_file_url,
      expiry_date: expiry_date ?? this.expiry_date,
      status: status ?? this.status,
      uploaded_at: uploaded_at ?? this.uploaded_at,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'document_id': document_id,
      'driver_id': driver_id,
      'document_type': document_type,
      'document_number': document_number,
      'document_file_url': document_file_url,
      'expiry_date': expiry_date,
      'status': status,
      'uploaded_at': uploaded_at,
    };
  }

  factory DriverDocument.fromMap(Map<String, dynamic> map) {
    return DriverDocument(
      document_id: map['document_id'] ?? '',
      driver_id: map['driver_id'] ?? '',
      document_type: map['document_type'] ?? '',
      document_number: map['document_number'] ?? '',
      document_file_url: map['document_file_url'] ?? '',
      expiry_date: map['expiry_date'] ?? '',
      status: map['status'] ?? '',
      uploaded_at: map['uploaded_at'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory DriverDocument.fromJson(String source) => DriverDocument.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'DriverDocument(document_id: $document_id, driver_id: $driver_id, document_type: $document_type, document_number: $document_number, document_file_url: $document_file_url, expiry_date: $expiry_date, status: $status, uploaded_at: $uploaded_at)';
  }

  @override
  bool operator ==(covariant DriverDocument other) {
    if (identical(this, other)) return true;
  
    return 
      other.document_id == document_id &&
      other.driver_id == driver_id &&
      other.document_type == document_type &&
      other.document_number == document_number &&
      other.document_file_url == document_file_url &&
      other.expiry_date == expiry_date &&
      other.status == status &&
      other.uploaded_at == uploaded_at;
  }

  @override
  int get hashCode {
    return document_id.hashCode ^
      driver_id.hashCode ^
      document_type.hashCode ^
      document_number.hashCode ^
      document_file_url.hashCode ^
      expiry_date.hashCode ^
      status.hashCode ^
      uploaded_at.hashCode;
  }
}
