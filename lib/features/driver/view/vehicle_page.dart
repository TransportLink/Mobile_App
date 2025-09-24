import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/driver/viewmodel/vehicle_view_model.dart';
import 'package:mobileapp/features/driver/widgets/vehicle_widgets.dart';
import 'package:mobileapp/features/driver/widgets/add_edit_vehicle_modal.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  bool _isAddModalOpen = false;
  VehicleModel? _editingVehicle;

  void _openAddModal() {
    setState(() {
      _isAddModalOpen = true;
      _editingVehicle = null;
    });
  }

  void _openEditModal(VehicleModel vehicle) {
    setState(() {
      _isAddModalOpen = true;
      _editingVehicle = vehicle;
    });
  }

  void _closeModal() {
    setState(() {
      _isAddModalOpen = false;
      _editingVehicle = null;
    });
  }

  void _showDeleteConfirmation(VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text(
          'Are you sure you want to delete ${vehicle.displayName}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVehicle(vehicle);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    try {
      await ref.read(vehicleViewModelProvider.notifier).deleteVehicle(
        vehicle.vehicleId!,
      );
      
      if (mounted) {
        // Refresh vehicles list
        ref.invalidate(getAllVehiclesProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle deleted successfully'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onVehicleTap(VehicleModel vehicle) {
    _showVehicleDetails(vehicle);
  }

  void _showVehicleDetails(VehicleModel vehicle) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildVehicleDetailsModal(vehicle),
    );
  }

  Widget _buildVehicleDetailsModal(VehicleModel vehicle) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicle.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Plate Number', vehicle.plateNumber),
          _buildDetailRow('Brand', vehicle.brand),
          _buildDetailRow('Model', vehicle.model),
          _buildDetailRow('Year', vehicle.year),
          _buildDetailRow('Color', vehicle.color),
          if (vehicle.vehicleType != null)
            _buildDetailRow('Type', vehicle.vehicleType!),
          if (vehicle.seatingCapacity != null)
            _buildDetailRow('Seating Capacity', '${vehicle.seatingCapacity} seats'),
          if (vehicle.insuranceNumber != null)
            _buildDetailRow('Insurance Number', vehicle.insuranceNumber!),
          if (vehicle.insuranceExpiryDate != null)
            _buildDetailRow('Insurance Expiry', vehicle.insuranceExpiryDate!),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openEditModal(vehicle);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(vehicle);
                  },
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMainContent(),
          if (_isAddModalOpen) _buildModal(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'My Vehicles',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _openAddModal,
          icon: const Icon(Icons.add, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusHeader(),
          const SizedBox(height: 24),
          Expanded(child: _buildVehiclesList()),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Management',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your fleet of vehicles',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesList() {
    return Consumer(
      builder: (context, ref, child) {
        final vehiclesAsync = ref.watch(getAllVehiclesProvider);
        
        return vehiclesAsync.when(
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return VehicleWidgets.buildEmptyState(_openAddModal);
            }

            return ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return VehicleWidgets.buildVehicleCard(
                  vehicle,
                  onTap: () => _onVehicleTap(vehicle),
                  onEdit: () => _openEditModal(vehicle),
                  onDelete: () => _showDeleteConfirmation(vehicle),
                );
              },
            );
          },
          error: (error, stackTrace) {
            return VehicleWidgets.buildErrorState(
              error.toString(),
              () => ref.invalidate(getAllVehiclesProvider),
            );
          },
          loading: () => const Center(child: Loader()),
        );
      },
    );
  }

  Widget _buildModal() {
    return AddEditVehicleModal(
      vehicle: _editingVehicle,
      onClose: _closeModal,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _openAddModal,
      backgroundColor: Colors.black,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}