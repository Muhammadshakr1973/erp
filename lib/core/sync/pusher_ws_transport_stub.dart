import 'pusher_ws_interface.dart';

Future<PusherWsTransport> connectPusherWebSocket(String url) {
  throw UnsupportedError(
    'WebSocket transport is not supported on this platform.',
  );
}
