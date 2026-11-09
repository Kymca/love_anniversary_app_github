/// A push payload is only a wake-up signal; it must not contain postcard data.
abstract interface class PostcardPushGateway {
  Stream<String> get receivedPostcardIds;
}
