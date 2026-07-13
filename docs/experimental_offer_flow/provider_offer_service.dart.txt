import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class ProviderOfferService {
  Future<Response<dynamic>> listOffers() {
    return ApiClient.dio.get('/services/offers/');
  }

  Future<Response<dynamic>> acceptOffer(int offerId) {
    return ApiClient.dio.post('/services/offers/$offerId/accept/');
  }

  Future<Response<dynamic>> rejectOffer(int offerId) {
    return ApiClient.dio.post('/services/offers/$offerId/reject/');
  }
}
