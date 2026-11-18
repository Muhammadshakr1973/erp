// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'pusher_ws_interface.dart';

class _WebPusherWsTransport implements PusherWsTransport {
  final html.WebSocket _socket;
  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();
  final StreamController<void> _closedController =
      StreamController<void>.broadcast();
  late final StreamSubscription<dynamic> _msgSub;
  late final StreamSubscription<dynamic> _closeSub;
  late final StreamSubscription<dynamic> _errSub;
  bool _closed = false;

  _WebPusherWsTransport(this._socket) {
    _msgSub = _socket.onMessage.listen((event) {
      final data = event.data;
      if (data is String && !_messagesController.isClosed) {
        _messagesController.add(data);
      }
    });
    _closeSub = _socket.onClose.listen((_) => _notifyClosed());
    _errSub = _socket.onError.listen((_) => _notifyClosed());
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
    if (_socket.readyState == html.WebSocket.OPEN) {
      _socket.send(payload);
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
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
