import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class PaymentService {
  Future<Map<String, dynamic>> getPayment(int requestId) async {
    final response = await ApiClient.dio.get(Endpoints.payment(requestId));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> simulateApproval(int requestId) async {
    final response = await ApiClient.dio.post(Endpoints.simulatePayment(requestId));
    return Map<String, dynamic>.from(response.data as Map);
  }
}
