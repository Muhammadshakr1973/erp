import 'dart:async';
import 'dart:io';

import 'pusher_ws_interface.dart';

class _IoPusherWsTransport implements PusherWsTransport {
  final WebSocket _socket;
  late final StreamController<String> _messagesController;
  late final StreamController<void> _closedController;
  late final StreamSubscription<dynamic> _subscription;
  final List<String> _pendingMessages = [];
  bool _pendingClosed = false;
  bool _closed = false;

  _IoPusherWsTransport(this._socket) {
    _messagesController = StreamController<String>.broadcast(
      onListen: _flushPendingMessages,
    );
    _closedController = StreamController<void>.broadcast(
      onListen: _flushPendingClosed,
    );

    _subscription = _socket.listen(
      (dynamic data) {
        if (data is String && !_messagesController.isClosed) {
          if (_messagesController.hasListener && _pendingMessages.isEmpty) {
            _messagesController.add(data);
          } else {
            _pendingMessages.add(data);
          }
        }
      },
      onError: (_) => _notifyClosed(),
      onDone: _notifyClosed,
      cancelOnError: false,
    );
  }

  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty || _messagesController.isClosed) return;
    scheduleMicrotask(() {
      while (_pendingMessages.isNotEmpty &&
          !_messagesController.isClosed &&
          _messagesController.hasListener) {
        final msg = _pendingMessages.removeAt(0);
        _messagesController.add(msg);
      }
    });
  }

  void _flushPendingClosed() {
    if (!_pendingClosed || _closedController.isClosed) return;
    scheduleMicrotask(() {
      if (_pendingClosed &&
          !_closedController.isClosed &&
          _closedController.hasListener) {
        _pendingClosed = false;
        _closedController.add(null);
      }
    });
  }

  void _notifyClosed() {
    if (_closed) return;
    _closed = true;
    if (!_closedController.isClosed) {
      if (_closedController.hasListener) {
        _closedController.add(null);
      } else {
        _pendingClosed = true;
      }
    }
  }

  @override
  Stream<String> get messages => _messagesController.stream;

  @override
  Stream<void> get onClosed => _closedController.stream;

  @override
  void send(String payload) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(payload);
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _pendingMessages.clear();
    _pendingClosed = false;
    await _subscription.cancel();
    try {
      await _socket.close();
    } catch (_) {}
    if (!_messagesController.isClosed) {
      await _messagesController.close();
    }
    if (!_closedController.isClosed) {
      await _closedController.close();
    }
  }
}

Future<PusherWsTransport> connectPusherWebSocket(String url) async {
  final socket = await WebSocket.connect(url).timeout(
    const Duration(seconds: 10),
  );
  return _IoPusherWsTransport(socket);
}
