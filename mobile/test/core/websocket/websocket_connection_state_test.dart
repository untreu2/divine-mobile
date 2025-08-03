// ABOUTME: Tests for WebSocket connection state machine
// ABOUTME: Verifies proper state transitions and event-driven behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/core/websocket/websocket_connection_state.dart';

void main() {
  group('WebSocketConnectionState', () {
    test('should define all connection states', () {
      expect(WebSocketConnectionState.values,
          contains(WebSocketConnectionState.disconnected));
      expect(WebSocketConnectionState.values,
          contains(WebSocketConnectionState.connecting));
      expect(WebSocketConnectionState.values,
          contains(WebSocketConnectionState.connected));
      expect(WebSocketConnectionState.values,
          contains(WebSocketConnectionState.reconnecting));
      expect(WebSocketConnectionState.values,
          contains(WebSocketConnectionState.error));
      expect(WebSocketConnectionState.values,
          contains(WebSocketConnectionState.closed));
    });

    test('should have exactly 6 states', () {
      expect(WebSocketConnectionState.values.length, equals(6));
    });
  });

  group('WebSocketStateMachine', () {
    late WebSocketStateMachine stateMachine;

    setUp(() {
      stateMachine = WebSocketStateMachine();
    });

    test('should start in disconnected state', () {
      expect(stateMachine.currentState,
          equals(WebSocketConnectionState.disconnected));
    });

    test('should expose state stream', () {
      expect(stateMachine.stateStream, isA<Stream<WebSocketConnectionState>>());
    });

    test('should transition from disconnected to connecting', () {
      expect(stateMachine.canTransition(WebSocketConnectionState.connecting),
          isTrue);
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      expect(stateMachine.currentState,
          equals(WebSocketConnectionState.connecting));
    });

    test('should transition from connecting to connected', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isTrue);
      stateMachine.transitionTo(WebSocketConnectionState.connected);
      expect(stateMachine.currentState,
          equals(WebSocketConnectionState.connected));
    });

    test('should transition from connecting to error', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.error), isTrue);
      stateMachine.transitionTo(WebSocketConnectionState.error);
      expect(stateMachine.currentState, equals(WebSocketConnectionState.error));
    });

    test('should transition from connected to disconnected', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.connected);
      expect(stateMachine.canTransition(WebSocketConnectionState.disconnected),
          isTrue);
      stateMachine.transitionTo(WebSocketConnectionState.disconnected);
      expect(stateMachine.currentState,
          equals(WebSocketConnectionState.disconnected));
    });

    test('should transition from error to reconnecting', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.error);
      expect(stateMachine.canTransition(WebSocketConnectionState.reconnecting),
          isTrue);
      stateMachine.transitionTo(WebSocketConnectionState.reconnecting);
      expect(stateMachine.currentState,
          equals(WebSocketConnectionState.reconnecting));
    });

    test('should not allow invalid transitions', () {
      // Cannot go directly from disconnected to connected
      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isFalse);
      expect(
        () => stateMachine.transitionTo(WebSocketConnectionState.connected),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('should emit state changes on stream', () async {
      final states = <WebSocketConnectionState>[];
      final subscription = stateMachine.stateStream.listen(states.add);

      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.connected);

      // Allow stream to emit using proper async pattern
      await pumpEventQueue();

      expect(
        states,
        equals([
          WebSocketConnectionState.connecting,
          WebSocketConnectionState.connected,
        ]),
      );

      await subscription.cancel();
    });

    test('should track state history', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.connected);
      stateMachine.transitionTo(WebSocketConnectionState.disconnected);

      expect(
        stateMachine.stateHistory,
        equals([
          WebSocketConnectionState.disconnected, // Initial state
          WebSocketConnectionState.connecting,
          WebSocketConnectionState.connected,
          WebSocketConnectionState.disconnected,
        ]),
      );
    });

    test('should provide time in current state', () async {
      final beforeTransition = DateTime.now();
      
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      
      // Use a controlled wait time for deterministic testing
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < 100) {
        await Future(() => {});
      }
      stopwatch.stop();

      final timeInState = stateMachine.timeInCurrentState;
      expect(timeInState.inMilliseconds, greaterThanOrEqualTo(90)); // Allow for timing variance
      expect(timeInState.inMilliseconds, lessThan(300));
    });

    test('should handle concurrent transition attempts safely', () async {
      // First transition to connecting
      stateMachine.transitionTo(WebSocketConnectionState.connecting);

      // Try multiple concurrent transitions from connecting
      final futures = [
        Future(() {
          try {
            stateMachine.transitionTo(WebSocketConnectionState.connected);
          } catch (e) {
            // Expected if another transition wins
          }
        }),
        Future(() {
          try {
            stateMachine.transitionTo(WebSocketConnectionState.error);
          } catch (e) {
            // Expected if another transition wins
          }
        }),
        Future(() {
          try {
            stateMachine.transitionTo(WebSocketConnectionState.disconnected);
          } catch (e) {
            // Expected if another transition wins
          }
        }),
      ];

      await Future.wait(futures);

      // Should have transitioned to one of the valid states
      expect(
        [
          WebSocketConnectionState.connected,
          WebSocketConnectionState.error,
          WebSocketConnectionState.disconnected,
        ],
        contains(stateMachine.currentState),
      );
    });

    test('should provide reason for state transitions', () {
      stateMachine.transitionTo(
        WebSocketConnectionState.connecting,
        reason: 'User initiated connection',
      );

      expect(stateMachine.lastTransitionReason,
          equals('User initiated connection'));

      stateMachine.transitionTo(
        WebSocketConnectionState.error,
        reason: 'Connection timeout',
      );

      expect(stateMachine.lastTransitionReason, equals('Connection timeout'));
    });

    test('should reset state machine', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.connected);

      stateMachine.reset();

      expect(stateMachine.currentState,
          equals(WebSocketConnectionState.disconnected));
      expect(stateMachine.stateHistory.length, equals(1));
      expect(stateMachine.lastTransitionReason, isNull);
    });

    test('state machine should be disposable', () {
      stateMachine.dispose();

      // Should not throw when disposed
      expect(() => stateMachine.currentState, returnsNormally);

      // But should not allow new transitions
      expect(
        () => stateMachine.transitionTo(WebSocketConnectionState.connecting),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('State Transition Rules', () {
    late WebSocketStateMachine stateMachine;

    setUp(() {
      stateMachine = WebSocketStateMachine();
    });

    test('disconnected state transitions', () {
      // From disconnected
      expect(stateMachine.canTransition(WebSocketConnectionState.connecting),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isFalse);
      expect(stateMachine.canTransition(WebSocketConnectionState.reconnecting),
          isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.error), isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.closed), isTrue);
    });

    test('connecting state transitions', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);

      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isTrue);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.error), isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.disconnected),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.reconnecting),
          isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.closed), isTrue);
    });

    test('connected state transitions', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.connected);

      expect(stateMachine.canTransition(WebSocketConnectionState.disconnected),
          isTrue);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.error), isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.connecting),
          isFalse);
      expect(stateMachine.canTransition(WebSocketConnectionState.reconnecting),
          isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.closed), isTrue);
    });

    test('error state transitions', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.error);

      expect(stateMachine.canTransition(WebSocketConnectionState.reconnecting),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.disconnected),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.connecting),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.closed), isTrue);
    });

    test('reconnecting state transitions', () {
      stateMachine.transitionTo(WebSocketConnectionState.connecting);
      stateMachine.transitionTo(WebSocketConnectionState.error);
      stateMachine.transitionTo(WebSocketConnectionState.reconnecting);

      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isTrue);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.error), isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.disconnected),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.connecting),
          isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.closed), isTrue);
    });

    test('closed state transitions', () {
      stateMachine.transitionTo(WebSocketConnectionState.closed);

      // Closed is terminal - no transitions allowed except back to disconnected
      expect(stateMachine.canTransition(WebSocketConnectionState.disconnected),
          isTrue);
      expect(stateMachine.canTransition(WebSocketConnectionState.connecting),
          isFalse);
      expect(stateMachine.canTransition(WebSocketConnectionState.connected),
          isFalse);
      expect(
          stateMachine.canTransition(WebSocketConnectionState.error), isFalse);
      expect(stateMachine.canTransition(WebSocketConnectionState.reconnecting),
          isFalse);
    });
  });
}
