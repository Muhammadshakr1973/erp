import 'dart:async';
import 'dart:io';

import 'pusher_ws_interface.dart';

class _IoPusherWsTransport implements PusherWsTransport {
  final WebSocket _socket;
  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();
  final StreamController<void> _closedController =
      StreamController<void>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;

  _IoPusherWsTransport(this._socket) {
    _subscription = _socket.listen(
      (dynamic data) {
        if (data is String && !_messagesController.isClosed) {
          _messagesController.add(data);
        }
      },
      onError: (_) => _notifyClosed(),
      onDone: _notifyClosed,
      cancelOnError: false,
    );
  }

  void _notifyClosed() {
    if (_closed) return;
    _closed = true;
    if (!_closedController.isClosed) {
      _closedController.add(null);
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
