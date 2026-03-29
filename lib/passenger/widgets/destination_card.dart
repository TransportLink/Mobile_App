import 'package:flutter/material.dart';

/// Destination Selection Card Widget
///
/// Shows available destinations with passenger count selector.
class DestinationCard extends StatelessWidget {
  final String destination;
  final int passengerCount;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<int> onPassengerCountChanged;

  const DestinationCard({
    Key? key,
    required this.destination,
    required this.passengerCount,
    required this.isSelected,
    required this.onSelect,
    required this.onPassengerCountChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Destination name
              Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.location_on_outlined,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Passenger count selector
              if (isSelected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Passengers:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: passengerCount > 1
                              ? () => onPassengerCountChanged(passengerCount - 1)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$passengerCount',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: passengerCount < 10
                              ? () => onPassengerCountChanged(passengerCount + 1)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
