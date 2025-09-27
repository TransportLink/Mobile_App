import 'package:flutter/material.dart';

class DriverUtils {
  static IconData getDocumentIcon(String documentType) {
    switch (documentType) {
      case 'License':
        return Icons.credit_card;
      case 'Vehicle Registration':
        return Icons.directions_car;
      case 'Insurance':
        return Icons.security;
      case 'ID Card':
        return Icons.badge;
      default:
        return Icons.description;
    }
  }

  static bool isDocumentExpired(String expiryDate) {
    try {
      final expiry = DateTime.parse(expiryDate);
      return expiry.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  static bool isDocumentExpiringSoon(String expiryDate) {
    try {
      final expiry = DateTime.parse(expiryDate);
      final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
      return expiry.isBefore(thirtyDaysFromNow) && expiry.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  static List<String> getDocumentTypes() {
    return [
      'license',
      'vehicle_registration',
      'insurance',
      'ID_Card',
    ];
  }

  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }
}