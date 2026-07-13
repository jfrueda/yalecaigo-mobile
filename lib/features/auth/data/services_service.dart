import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class ServicesService {
  Future<Response<List<dynamic>>> listOffers() {
    return ApiClient.dio.get<List<dynamic>>('/services/offers/');
  }
}
