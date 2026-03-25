import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobileapp/core/constants/server_constants.dart';

/// SSE (Server-Sent Events) client for real-time demand updates.
///
/// Task 2.6: Real-time updates without polling
class SSEClient {
  final String url;
  final Duration reconnectDelay;

  http.Client? _client;
  StreamSubscription? _subscription;

  bool _isConnected = false;
  bool _isManualDisconnect = false;

  // Event callbacks
  Function(String type, dynamic data)? onEvent;
  Function()? onConnected;
  Function(String error)? onError;
  Function()? onDisconnected;
  Function()? onReconnecting;

  SSEClient({
    required this.url,
    this.reconnectDelay = const Duration(seconds: 5),
  });

  /// Connect to SSE stream
  void connect() {
    _isManualDisconnect = false;
    _connect();
  }

  void _connect() {
    if (_isConnected) return;

    _client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    _client!.send(request).then((response) {
      if (response.statusCode == 200) {
        _isConnected = true;
        onConnected?.call();

        _subscription = response.stream.transform(utf8.decoder).listen(
              _handleMessage,
              onError: _handleError,
              onDone: _handleDone,
            );
      } else {
        _handleError('Connection failed: ${response.statusCode}');
      }
    }).catchError((error) {
      _handleError(error);
    });
  }

  void _handleMessage(String message) {
    if (message.startsWith(':')) {
      // Keepalive comment, ignore
      return;
    }

    final lines = message.split('\n');
    String eventType = 'message';
    String data = '';

    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data = line.substring(5).trim();
      }
    }

    if (data.isNotEmpty) {
      try {
        final jsonData = json.decode(data);
        onEvent?.call(eventType, jsonData);
      } catch (e) {
        // Non-JSON data
        onEvent?.call(eventType, data);
      }
    }
  }

  void _handleError(dynamic error) {
    _isConnected = false;
    onError?.call(error.toString());

    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDone() {
    _isConnected = false;
    onDisconnected?.call();

    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    onReconnecting?.call();
    Future.delayed(reconnectDelay, () {
      if (!_isManualDisconnect) {
        _connect();
      }
    });
  }

  /// Disconnect from SSE stream
  void disconnect() {
    _isManualDisconnect = true;
    _close();
  }

  void _close() {
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;
    _isConnected = false;
  }

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Dispose resources
  void dispose() {
    disconnect();
  }
}

/// SSE Event types
class SSEEventType {
  static const String connected = 'connected';
  static const String update = 'update';
  static const String demandUpdate = 'demand_update';
  static const String tripStarted = 'trip_started';
  static const String tripCompleted = 'trip_completed';
  static const String systemStatus = 'system_status';
}
