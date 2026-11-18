abstract class PusherWsTransport {
  Stream<String> get messages;
  Stream<void> get onClosed;
  void send(String payload);
  Future<void> close();
}
