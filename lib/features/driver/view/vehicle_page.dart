import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/driver/viewmodel/vehicle_view_model.dart';
import 'package:mobileapp/features/driver/widgets/vehicle_widgets.dart';
import 'package:mobileapp/features/driver/widgets/add_edit_vehicle_modal.dart';
import 'package:mobileapp/features/map/viewmodel/map_view_model.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  bool _isAddModalOpen = false;
  VehicleModel? _editingVehicle;
  String? _defaultVehicleId;

  @override
  void initState() {
    super.initState();
    _loadDefaultVehicle();
  }

  void _loadDefaultVehicle() {
    final authLocal = ref.read(authLocalRepositoryProvider);
    setState(() {
      _defaultVehicleId = authLocal.getDefaultVehicleId();
    });
  }

  Future<void> _setDefaultVehicle(VehicleModel vehicle) async {
    final authLocal = ref.read(authLocalRepositoryProvider);
    await authLocal.setDefaultVehicleId(vehicle.vehicleId!);
    // Also update the map view model so it's ready for trip acceptance
    ref.read(mapViewModelProvider.notifier).updateSelectedVehicle(vehicle.vehicleId!);
    setState(() {
      _defaultVehicleId = vehicle.vehicleId;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${vehicle.displayName} set as default'),
          backgroundColor: AppPalette.primary,
        ),
      );
    }
  }

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

      // Clear default if this was the default vehicle
      if (_defaultVehicleId == vehicle.vehicleId) {
        final authLocal = ref.read(authLocalRepositoryProvider);
        await authLocal.removeDefaultVehicleId();
        setState(() => _defaultVehicleId = null);
      }

      if (mounted) {
        ref.invalidate(getAllVehiclesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle deleted successfully'),
            backgroundColor: AppPalette.navy,
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
    final isDefault = _defaultVehicleId == vehicle.vehicleId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildVehicleDetailsModal(vehicle, isDefault),
    );
  }

  Widget _buildVehicleDetailsModal(VehicleModel vehicle, bool isDefault) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (isDefault)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppPalette.primary),
                              const SizedBox(width: 4),
                              Text('Default vehicle',
                                  style: TextStyle(fontSize: 13, color: AppPalette.primary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                    ],
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
              _buildDetailRow(
                  'Seating Capacity', '${vehicle.seatingCapacity} seats'),
            if (vehicle.insuranceNumber != null)
              _buildDetailRow('Insurance Number', vehicle.insuranceNumber!),
            if (vehicle.insuranceExpiryDate != null)
              _buildDetailRow('Insurance Expiry', vehicle.insuranceExpiryDate!),
            const SizedBox(height: 20),
            // Set as default button
            if (!isDefault)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _setDefaultVehicle(vehicle);
                  },
                  icon: const Icon(Icons.star, size: 18),
                  label: const Text('Set as Default'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            const SizedBox(height: 12),
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
      body: SafeArea(
        child: Stack(
          children: [
            _buildMainContent(),
            if (_isAddModalOpen) _buildModal(),
          ],
        ),
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
                  'Tap a vehicle to set it as your default',
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

            // Auto-set default if only one vehicle and no default set
            if (vehicles.length == 1 && _defaultVehicleId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _setDefaultVehicle(vehicles.first);
              });
            }

            return ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                final isDefault = _defaultVehicleId == vehicle.vehicleId;
                return _buildVehicleCardWithDefault(
                  vehicle,
                  isDefault: isDefault,
                  onTap: () => _onVehicleTap(vehicle),
                  onEdit: () => _openEditModal(vehicle),
                  onDelete: () => _showDeleteConfirmation(vehicle),
                  onSetDefault: () => _setDefaultVehicle(vehicle),
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

  Widget _buildVehicleCardWithDefault(
    VehicleModel vehicle, {
    required bool isDefault,
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onSetDefault,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDefault ? AppPalette.primary.withOpacity(0.6) : Colors.black12,
            width: isDefault ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDefault ? AppPalette.primary.withOpacity(0.1) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: isDefault ? AppPalette.primary : Colors.black54,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicle.plateNumber,
                        style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.primary.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppPalette.primary),
                        const SizedBox(width: 4),
                        Text('Default', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppPalette.primaryDark)),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: onSetDefault,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Use This',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChip(Icons.palette_outlined, vehicle.color),
                const SizedBox(width: 8),
                if (vehicle.seatingCapacity != null)
                  _buildChip(Icons.event_seat, '${vehicle.seatingCapacity} seats'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        ],
      ),
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
      backgroundColor: AppPalette.navy,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
