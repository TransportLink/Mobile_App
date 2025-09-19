import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../models/route.dart' as route_models;
import '../models/destination.dart';
import 'package:collection/collection.dart';

class UIComponents {
  static Widget buildBusStopCard(
    BusStop stop,
    VoidCallback onCancel,
    VoidCallback onAccept,
  ) {
    print("ℹ️ Building bus stop card for ${stop.systemId}");
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stop.systemId,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Total Passengers: ${stop.totalCount ?? 0}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Destinations:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: stop.destinations.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.value ?? 0}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildTripCard(
    Destination destination,
    route_models.Route? route,
    String? currentBusStopId,
    List<BusStop> busStops,
    VoidCallback onArrived,
    VoidCallback onCancel,
  ) {
    final passengerCount = currentBusStopId != null
        ? busStops
                .firstWhereOrNull((stop) => stop.systemId == currentBusStopId)
                ?.totalCount ??
            0
        : 0;
    print(
        "ℹ️ Building trip card: route=${destination.routeName}, passengers=$passengerCount");
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip to ${destination.routeName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (route != null) ...[
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ETA: ${(route.eta / 60).toStringAsFixed(1)} min',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Distance: ${(route.distance / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Passengers: $passengerCount',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: onArrived,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Arrived'),
              ),
              ElevatedButton(
                onPressed: onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildMinimizedTripCard(
    Destination destination,
    route_models.Route? route,
    String? currentBusStopId,
    List<BusStop> busStops,
    VoidCallback onTap,
  ) {
    final passengerCount = currentBusStopId != null
        ? busStops
                .firstWhereOrNull((stop) => stop.systemId == currentBusStopId)
                ?.totalCount ??
            0
        : 0;
    print(
        "ℹ️ Building minimized trip card: route=${destination.routeName}, passengers=$passengerCount");

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8.0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        margin: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade100, Colors.green.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Tooltip(
                    message: 'Current Trip',
                    child: Row(
                      children: [
                        Icon(Icons.route,
                            color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 4),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            destination.routeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (route != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Tooltip(
                      message: 'Estimated Time',
                      child: Row(
                        children: [
                          Icon(Icons.timer,
                              color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${(route.eta / 60).toStringAsFixed(1)} min',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (route != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Tooltip(
                      message: 'Distance',
                      child: Row(
                        children: [
                          Icon(Icons.straighten,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${(route.distance / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Tooltip(
                    message: 'Passengers',
                    child: Row(
                      children: [
                        Icon(Icons.people,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$passengerCount',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.arrow_upward,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
