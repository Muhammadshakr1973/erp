// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'pusher_ws_interface.dart';

class _WebPusherWsTransport implements PusherWsTransport {
  final html.WebSocket _socket;
  late final StreamController<String> _messagesController;
  late final StreamController<void> _closedController;
  late final StreamSubscription<dynamic> _msgSub;
  late final StreamSubscription<dynamic> _closeSub;
  late final StreamSubscription<dynamic> _errSub;
  final List<String> _pendingMessages = [];
  bool _pendingClosed = false;
  bool _closed = false;

  _WebPusherWsTransport(this._socket) {
    _messagesController = StreamController<String>.broadcast(
      onListen: _flushPendingMessages,
    );
    _closedController = StreamController<void>.broadcast(
      onListen: _flushPendingClosed,
    );

    _msgSub = _socket.onMessage.listen((event) {
      final data = event.data;
      if (data is String && !_messagesController.isClosed) {
        if (_messagesController.hasListener && _pendingMessages.isEmpty) {
          _messagesController.add(data);
        } else {
          _pendingMessages.add(data);
        }
      }
    });
    _closeSub = _socket.onClose.listen((_) => _notifyClosed());
    _errSub = _socket.onError.listen((_) => _notifyClosed());
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
    if (_socket.readyState == html.WebSocket.OPEN) {
      _socket.send(payload);
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _pendingMessages.clear();
    _pendingClosed = false;
    await _msgSub.cancel();
    await _closeSub.cancel();
    await _errSub.cancel();
    try {
      _socket.close();
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
  final socket = html.WebSocket(url);
  final completer = Completer<PusherWsTransport>();

  late StreamSubscription<dynamic> openSub;
  late StreamSubscription<dynamic> errorSub;

  openSub = socket.onOpen.listen((_) {
    openSub.cancel();
    errorSub.cancel();
    if (!completer.isCompleted) {
      completer.complete(_WebPusherWsTransport(socket));
    }
  });

  errorSub = socket.onError.listen((_) {
    openSub.cancel();
    errorSub.cancel();
    if (!completer.isCompleted) {
      completer.completeError(
        Exception('WebSocket connection failed on Web'),
      );
    }
  });

  return completer.future.timeout(const Duration(seconds: 10));
}
