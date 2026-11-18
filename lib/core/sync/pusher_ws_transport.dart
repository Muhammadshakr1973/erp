import 'pusher_ws_interface.dart';
import 'pusher_ws_transport_stub.dart'
    if (dart.library.io) 'pusher_ws_transport_io.dart'
    if (dart.library.html) 'pusher_ws_transport_web.dart' as impl;

export 'pusher_ws_interface.dart';

Future<PusherWsTransport> connectPusherWebSocket(String url) =>
    impl.connectPusherWebSocket(url);
