import 'package:flutter/material.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';

class VehicleUtils {
  static IconData getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'car':
      case 'sedan':
        return Icons.directions_car;
      case 'suv':
        return Icons.directions_car_filled;
      case 'truck':
        return Icons.local_shipping;
      case 'van':
        return Icons.airport_shuttle;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bicycle':
        return Icons.pedal_bike;
      default:
        return Icons.directions_car;
    }
  }

  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static String getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'maintenance':
        return 'Maintenance';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  static List<String> getVehicleBrands() {
    return [
      'Toyota',
      'Honda',
      'Hyundai',
      'Kia',
      'Nissan',
      'Mercedes-Benz',
      'BMW',
      'Audi',
      'Volkswagen',
      'Ford',
      'Chevrolet',
      'Mazda',
      'Subaru',
      'Lexus',
      'Infiniti',
      'Acura',
      'Volvo',
      'Jaguar',
      'Land Rover',
      'Porsche',
    ];
  }

  static List<String> getVehicleTypes() {
    return [
      'car', 'van', 'bus', 'bike', 'other'
    ];
  }
  static List<String> getVehicleColors() {
    return [
      'White',
      'Black',
      'Silver',
      'Gray',
      'Red',
      'Blue',
      'Green',
      'Yellow',
      'Orange',
      'Brown',
      'Gold',
      'Purple',
    ];
  }

  static List<String> getVehicleYears() {
    final currentYear = DateTime.now().year;
    return List.generate(
      currentYear - 1989,
      (index) => (currentYear - index).toString(),
    );
  }

  static bool isValidPlateNumber(String plateNumber) {
    if (plateNumber.trim().isEmpty) return false;
    return plateNumber.trim().length >= 3;
  }

  static String formatVehicleDisplayName(VehicleModel vehicle) {
    return '${vehicle.year} ${vehicle.brand} ${vehicle.model}';
  }

  static int getVehicleAge(String year) {
    try {
      final vehicleYear = int.parse(year);
      return DateTime.now().year - vehicleYear;
    } catch (e) {
      return 0;
    }
  }

  static bool isOldVehicle(String year) {
    return getVehicleAge(year) > 10;
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  static String getRelativeTime(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years years ago';
    }
  }

  static Map<String, String?> validateVehicleData({
    required String brand,
    required String model,
    required String year,
    required String plateNumber,
    required String color,
    String? seatingCapacity,
    String? insuranceNumber,
    String? insuranceExpiryDate,
  }) {
    Map<String, String?> errors = {};

    if (brand.trim().isEmpty) {
      errors['brand'] = 'Brand is required';
    }

    if (model.trim().isEmpty) {
      errors['model'] = 'Model is required';
    }

    if (year.trim().isEmpty) {
      errors['year'] = 'Year is required';
    } else {
      try {
        final yearInt = int.parse(year);
        final currentYear = DateTime.now().year;
        if (yearInt < 1990 || yearInt > currentYear + 1) {
          errors['year'] = 'Please enter a valid year';
        }
      } catch (e) {
        errors['year'] = 'Please enter a valid year';
      }
    }

    if (plateNumber.trim().isEmpty) {
      errors['plateNumber'] = 'Plate number is required';
    } else if (!isValidPlateNumber(plateNumber)) {
      errors['plateNumber'] = 'Please enter a valid plate number';
    }

    if (color.trim().isEmpty) {
      errors['color'] = 'Color is required';
    }

    if (seatingCapacity != null && seatingCapacity.trim().isNotEmpty) {
      try {
        final capacity = int.parse(seatingCapacity);
        if (capacity < 1 || capacity > 50) {
          errors['seatingCapacity'] = 'Seating capacity must be between 1 and 50';
        }
      } catch (e) {
        errors['seatingCapacity'] = 'Please enter a valid number';
      }
    }

    if (insuranceExpiryDate != null && insuranceExpiryDate.trim().isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(insuranceExpiryDate);
        if (expiryDate.isBefore(DateTime.now())) {
          errors['insuranceExpiryDate'] = 'Insurance expiry date cannot be in the past';
        }
      } catch (e) {
        errors['insuranceExpiryDate'] = 'Please enter a valid date';
      }
    }

    return errors.isEmpty ? {} : errors;
  }
}