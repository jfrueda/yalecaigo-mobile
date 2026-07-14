import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';

class NotificationService {
  Future<List<Map<String, dynamic>>> listNotifications() async {
    final response = await ApiClient.dio.get(Endpoints.notifications);
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
