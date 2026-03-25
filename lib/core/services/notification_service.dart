import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _highPriorityChannelId = 'smart_trotro_urgent';
  static const String _normalChannelId = 'smart_trotro_normal';
  static const String _silentChannelId = 'smart_trotro_silent';

  final Map<String, DateTime> _lastDemandAlert = {};

  String? _pendingNavigation;
  String? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _highPriorityChannelId,
          'Urgent Alerts',
          description: 'High demand alerts and trip cancellations',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _normalChannelId,
          'Trip Updates',
          description: 'Trip confirmations and demand changes',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: false,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _silentChannelId,
          'Summaries',
          description: 'Daily summaries and informational updates',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );

      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _pendingNavigation = payload;
    }
  }

  // Priority 0: Urgent

  Future<void> showHighDemandAlert({
    required String systemId,
    required String stopName,
    required Map<String, int> demand,
    required int driversEnRoute,
    required double etaMinutes,
  }) async {
    final lastAlert = _lastDemandAlert[systemId];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inMinutes < 5) {
      return;
    }
    _lastDemandAlert[systemId] = DateTime.now();

    if (driversEnRoute > 0) return;
    final totalDemand = demand.values.fold(0, (a, b) => a + b);
    if (totalDemand < 5) return;

    final demandText = demand.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value} for ${e.key}')
        .join(', ');

    await _notifications.show(
      systemId.hashCode,
      'High demand at $stopName',
      '$demandText. No drivers heading there. ${etaMinutes.toStringAsFixed(0)} min away.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _highPriorityChannelId,
          'Urgent Alerts',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.recommendation,
        ),
      ),
      payload: 'demand_list',
    );
  }

  Future<void> showTripCancelledAlert({
    required int tripId,
    required String stopName,
    required String reason,
  }) async {
    await _notifications.show(
      tripId,
      'Trip #$tripId cancelled',
      'Passengers at $stopName $reason. Trip cancelled.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _highPriorityChannelId,
          'Urgent Alerts',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: 'map',
    );
  }

  Future<void> showSystemOfflineAlert({
    required String systemId,
    required String stopName,
    required int minutesSinceLastUpdate,
  }) async {
    await _notifications.show(
      'offline_$systemId'.hashCode,
      '$stopName offline',
      'Passenger count data may be stale. Last update $minutesSinceLastUpdate min ago.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _highPriorityChannelId,
          'Urgent Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'map',
    );
  }

  // Priority 1: Important

  Future<void> showTripConfirmed({
    required int tripId,
    required String stopName,
    required double etaMinutes,
    required int passengerCount,
    required String destination,
  }) async {
    await _notifications.show(
      tripId,
      'Trip confirmed',
      'Route to $stopName. ETA ${etaMinutes.toStringAsFixed(0)} min. $passengerCount passengers for $destination.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _normalChannelId,
          'Trip Updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.navigation,
        ),
      ),
      payload: 'map',
    );
  }

  Future<void> showApproachingBusStop({
    required String stopName,
    required int passengerCount,
    required String destination,
  }) async {
    await _notifications.show(
      'approaching_$stopName'.hashCode,
      'Approaching $stopName',
      '$passengerCount passengers waiting for $destination. Prepare to stop.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _normalChannelId,
          'Trip Updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.navigation,
        ),
      ),
      payload: 'map',
    );
  }

  Future<void> showDemandChangedDuringTrip({
    required String stopName,
    required String destination,
    required int oldCount,
    required int newCount,
  }) async {
    final direction = newCount > oldCount ? 'increased' : 'decreased';
    await _notifications.show(
      'demand_change_$stopName'.hashCode,
      'Demand update at $stopName',
      '$destination passengers $direction: $oldCount -> $newCount.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _normalChannelId,
          'Trip Updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'map',
    );
  }

  // Priority 2: Silent

  Future<void> showDailySummary({
    required int trips,
    required int passengers,
    required double estimatedEarnings,
  }) async {
    await _notifications.show(
      'daily_summary'.hashCode,
      "Today's summary",
      '$trips trips, $passengers passengers, ~GHS ${estimatedEarnings.toStringAsFixed(2)} estimated.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _silentChannelId,
          'Summaries',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      payload: 'wallet',
    );
  }

  Future<void> showNewBusStopInRange({
    required String stopName,
    required Map<String, int> demand,
    required double distanceKm,
  }) async {
    final totalDemand = demand.values.fold(0, (a, b) => a + b);
    if (totalDemand < 3) return;

    final topDest = demand.entries.reduce((a, b) => a.value > b.value ? a : b);

    await _notifications.show(
      'new_stop_$stopName'.hashCode,
      'New demand nearby',
      '$stopName: ${topDest.value} passengers for ${topDest.key}. ${distanceKm.toStringAsFixed(1)} km away.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _silentChannelId,
          'Summaries',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      payload: 'demand_list',
    );
  }

  // Scheduled daily summary at 9pm

  Future<void> scheduleDailySummary() async {
    await _notifications.cancel('daily_summary_scheduled'.hashCode);

    await _notifications.zonedSchedule(
      'daily_summary_scheduled'.hashCode,
      "Today's summary",
      'Tap to see your earnings',
      _nextInstanceOf9PM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _silentChannelId,
          'Summaries',
          importance: Importance.low,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'wallet',
    );
  }

  tz.TZDateTime _nextInstanceOf9PM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
