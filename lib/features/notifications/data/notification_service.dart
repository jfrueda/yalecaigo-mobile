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

  Future<int> unreadCount() async {
    final response = await ApiClient.dio.get(Endpoints.notificationUnreadCount);
    final data = response.data;
    if (data is Map) {
      return int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;
    }
    return 0;
  }

  Future<void> markRead(int notificationId) async {
    await ApiClient.dio.post<dynamic>(
      Endpoints.notificationRead(notificationId),
    );
  }

  Future<void> markAllRead() async {
    await ApiClient.dio.post<dynamic>(Endpoints.notificationReadAll);
  }
}
