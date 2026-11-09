import '../models/postcard.dart';

/// Authenticated backend operations for durably storing and reading postcards.
///
/// Implementations must verify that sender and recipient belong to the same
/// pair. A successful send means the postcard is already persisted remotely.
abstract interface class PostcardDeliveryGateway {
  Future<Postcard> sendPostcard({
    required String recipientId,
    required String message,
  });

  Future<Postcard?> loadReceivedPostcard(String postcardId);

  Future<List<Postcard>> loadReceivedPostcards();
}
