// Helper methods
import 'package:flutter/material.dart';

IconData getDocumentIcon(String documentType) {
  switch (documentType) {
    case 'Driver License':
      return Icons.credit_card;
    case 'Vehicle Registration':
      return Icons.directions_car;
    case 'Insurance Certificate':
      return Icons.security;
    case 'Vehicle Inspection':
      return Icons.build_circle;
    case 'National ID':
      return Icons.badge;
    case 'Medical Certificate':
      return Icons.local_hospital;
    case 'Police Clearance':
      return Icons.verified_user;
    default:
      return Icons.description;
  }
}

bool isDocumentExpired(String expiryDate) {
  final expiry = DateTime.parse(expiryDate);
  return expiry.isBefore(DateTime.now());
}

bool isDocumentExpiringSoon(String expiryDate) {
  final expiry = DateTime.parse(expiryDate);
  final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
  return expiry.isBefore(thirtyDaysFromNow) && expiry.isAfter(DateTime.now());
}

List<Map<String, dynamic>> getSampleDocuments() {
  return [
    {
      'type': 'Driver License',
      'number': 'DL123456789',
      'expiryDate': '2026-12-31',
      'status': 'valid',
    },
    {
      'type': 'Vehicle Registration',
      'number': 'VR987654321',
      'expiryDate': '2025-10-15',
      'status': 'expiring_soon',
    },
    {
      'type': 'Insurance Certificate',
      'number': 'IC456789123',
      'expiryDate': '2023-06-30',
      'status': 'expired',
    },
  ];
}
