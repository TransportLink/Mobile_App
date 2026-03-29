import 'package:flutter/material.dart';
import '../model/passenger_state.dart';

/// Driver ETA Card Widget
///
/// Shows incoming driver information with ETA and seats available.
class DriverEtaCard extends StatelessWidget {
  final IncomingDriver driver;
  final int position;

  const DriverEtaCard({
    Key? key,
    required this.driver,
    this.position = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasEta = driver.eta != null && driver.eta! > 0;
    final etaMinutes = driver.eta ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Position number (for queue)
            if (position > 0) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '#$position',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],

            // Bus icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getBusColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Driver info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus color and plate
                  Text(
                    '${driver.busColor ?? 'Bus'} ${driver.licensePlate ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Driver ID
                  Text(
                    driver.driverId,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // ETA and seats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ETA
                if (hasEta) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getEtaColor(etaMinutes).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: _getEtaColor(etaMinutes),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$etaMinutes min',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getEtaColor(etaMinutes),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Seats available
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_seat,
                      size: 16,
                      color: driver.seatsAvailable > 0
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${driver.seatsAvailable} seats',
                      style: TextStyle(
                        fontSize: 14,
                        color: driver.seatsAvailable > 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBusColor() {
    if (driver.busColor == null) return Colors.blue;

    final colorLower = driver.busColor!.toLowerCase();
    if (colorLower.contains('blue')) return Colors.blue;
    if (colorLower.contains('red')) return Colors.red;
    if (colorLower.contains('green')) return Colors.green;
    if (colorLower.contains('white')) return Colors.grey.shade300;
    if (colorLower.contains('yellow')) return Colors.amber;

    return Colors.blue;
  }

  Color _getEtaColor(int minutes) {
    if (minutes <= 5) return Colors.green;
    if (minutes <= 10) return Colors.orange;
    return Colors.red;
  }
}
