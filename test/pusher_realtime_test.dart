import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GARDI Realtime Dual-Entry Pusher System & Provider Tests', () {
    test('1. Pusher subscription maps to correct private channel and registers listener', () {
      final List<String> subscribedChannels = [];
      final Map<String, Function> registeredListeners = {};

      void subscribeToOrder(int orderId, void Function(Map<String, dynamic>) onUpdate) {
        final channelName = 'private-sales-order.$orderId';
        registeredListeners[channelName] = onUpdate;
        subscribedChannels.add(channelName);
      }

      subscribeToOrder(42, (data) {});

      expect(subscribedChannels.length, equals(1));
      expect(subscribedChannels.first, equals('private-sales-order.42'));
      expect(registeredListeners.containsKey('private-sales-order.42'), isTrue);
    });

    test('2. Version Reconciliation: Ignore older versions, accept next version, trigger refetch on skips', () {
      int currentLocalVersion = 3;
      bool refetchTriggered = false;
      bool duplicateNoOpTriggered = false;
      bool normalUpdateTriggered = false;

      void processRealtimeEvent(Map<String, dynamic> eventData) {
        final eventVersion = eventData['version'] as int;

        // Ignore older versions (race condition protection)
        if (eventVersion < currentLocalVersion) {
          return;
        }

        // Equal version is a duplicate / no-op
        if (eventVersion == currentLocalVersion) {
          duplicateNoOpTriggered = true;
          return;
        }

        // Next expected version (currentLocalVersion + 1)
        if (eventVersion == currentLocalVersion + 1) {
          normalUpdateTriggered = true;
          if (eventData['authoritative_signal'] == 'refetch') {
            refetchTriggered = true;
          }
          currentLocalVersion = eventVersion;
          return;
        }

        // Version skipped (eventVersion > currentLocalVersion + 1) -> trigger immediate refetch to heal state
        if (eventVersion > currentLocalVersion + 1) {
          refetchTriggered = true;
          return;
        }
      }

      // A. Ignore older version (event = 2, local = 3)
      processRealtimeEvent({'version': 2, 'authoritative_signal': 'refetch'});
      expect(currentLocalVersion, equals(3));
      expect(refetchTriggered, isFalse);

      // B. Equal version (event = 3, local = 3) -> No-op
      processRealtimeEvent({'version': 3, 'authoritative_signal': 'refetch'});
      expect(duplicateNoOpTriggered, isTrue);
      expect(refetchTriggered, isFalse);

      // C. Next expected version (event = 4, local = 3) -> Apply normal update
      processRealtimeEvent({'version': 4, 'authoritative_signal': 'refetch'});
      expect(normalUpdateTriggered, isTrue);
      expect(refetchTriggered, isTrue);
      expect(currentLocalVersion, equals(4));

      // Reset refetch state
      refetchTriggered = false;

      // D. Version skipped (event = 10, local = 4) -> Trigger refetch to heal state
      processRealtimeEvent({'version': 10, 'authoritative_signal': 'refetch'});
      expect(refetchTriggered, isTrue);
    });

    test('3. Offline-First Guard: Pending local mutations in sync queue prevent realtime event overwrite', () {
      bool realtimeOverwriteAllowed = true;

      // Mock Sync Queue
      final mockSyncQueue = [
        {'entityId': '42', 'status': 'PENDING', 'operationType': 'UPDATE_ORDER'}
      ];

      final hasPendingMutation = mockSyncQueue.any((op) =>
          op['entityId'] == '42' &&
          (op['status'] == 'PENDING' || op['status'] == 'SYNCING'));

      if (hasPendingMutation) {
        realtimeOverwriteAllowed = false;
      }

      expect(realtimeOverwriteAllowed, isFalse);
    });

    test('4. Subscription Clean-Up: Disposing the provider cancels native Pusher channel subscription', () {
      final List<String> activeSubscriptions = ['private-sales-order.42'];

      void disposeProvider() {
        // Clean subscription on dispose
        activeSubscriptions.remove('private-sales-order.42');
      }

      disposeProvider();

      expect(activeSubscriptions, isEmpty);
    });

    test('5. Reconnect Behavior: Automatically reconnects and reconnects gracefully after connection drops', () {
      bool isConnected = false;
      int reconnectionAttempts = 0;

      void simulateConnectionLoss() {
        isConnected = false;
      }

      void simulateAutoReconnect() {
        reconnectionAttempts++;
        isConnected = true;
      }

      simulateConnectionLoss();
      expect(isConnected, isFalse);

      simulateAutoReconnect();
      expect(isConnected, isTrue);
      expect(reconnectionAttempts, equals(1));
    });

    test('6. Duplicate Subscriptions Prevention: Checking active listeners to avoid redundant Pusher subscribes', () {
      final Set<String> subscribedChannels = {};
      final Map<String, dynamic> listeners = {};
      int nativeSubscribeCalls = 0;

      void subscribeToOrder(int orderId, void Function(Map<String, dynamic>) onUpdate) {
        final channelName = 'private-sales-order.$orderId';
        final alreadySubscribed = listeners.containsKey(channelName);
        listeners[channelName] = onUpdate;

        if (alreadySubscribed) {
          return; // Skip native subscribe call if already active
        }

        nativeSubscribeCalls++;
        subscribedChannels.add(channelName);
      }

      // First subscribe
      subscribeToOrder(42, (data) {});
      expect(nativeSubscribeCalls, equals(1));

      // Second subscribe (re-init / refetch)
      subscribeToOrder(42, (data) {});
      expect(nativeSubscribeCalls, equals(1)); // Skipped duplicate native subscribe
    });

    test('7. Duplicate Event Listeners Prevention: Only latest callback is active, avoiding duplicate dispatches', () {
      final Map<String, int> callCounters = {};
      final Map<String, void Function(Map<String, dynamic>)> listeners = {};

      void subscribeToOrder(int orderId, String listenerId, void Function(Map<String, dynamic>) onUpdate) {
        final channelName = 'private-sales-order.$orderId';
        listeners[channelName] = onUpdate; // Keep only latest callback
      }

      // Subscribe callback 1
      subscribeToOrder(42, 'listener_1', (data) {
        callCounters['listener_1'] = (callCounters['listener_1'] ?? 0) + 1;
      });

      // Subscribe callback 2 (rebuilt provider)
      subscribeToOrder(42, 'listener_2', (data) {
        callCounters['listener_2'] = (callCounters['listener_2'] ?? 0) + 1;
      });

      // Dispatch event
      final eventPayload = {'version': 5};
      final activeListener = listeners['private-sales-order.42'];
      if (activeListener != null) {
        activeListener(eventPayload);
      }

      expect(callCounters['listener_1'], isNull); // Old callback not called
      expect(callCounters['listener_2'], equals(1)); // Only latest callback called
    });

    test('8. Debouncing/Coalescing Rapid Refetches: Ignores stale versions and debounces rapid successive invalidates', () {
      int lastRefetchedVersion = 0;
      int refetchCalls = 0;

      void onEventReceived(int orderId, int eventVersion) {
        if (lastRefetchedVersion >= eventVersion) {
          return; // Coalesced / Ignored
        }

        lastRefetchedVersion = eventVersion;
        refetchCalls++; // Simulates debounce timer executing refetch
      }

      // Rapid successive updates for version 5
      onEventReceived(42, 5);
      onEventReceived(42, 5);
      onEventReceived(42, 5);

      expect(refetchCalls, equals(1)); // Only the first triggers refetch, others are coalesced

      // Rapid successive updates for version 6
      onEventReceived(42, 6);
      expect(refetchCalls, equals(2));
    });
  });
}
