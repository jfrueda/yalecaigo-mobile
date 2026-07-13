import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class HomeService {
  Future<Response<List<dynamic>>> listOffers() {
    return ApiClient.dio.get<List<dynamic>>(Endpoints.serviceOffers);
  }

  Future<Response<Map<String, dynamic>>> acceptOffer(int offerId) {
    return ApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.acceptOffer(offerId),
    );
  }

  Future<Response<Map<String, dynamic>>> rejectOffer(int offerId) {
    return ApiClient.dio.post<Map<String, dynamic>>(
      Endpoints.rejectOffer(offerId),
    );
  }
}
