abstract final class Endpoints {
  static const String tokenObtain = '/auth/token/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String register = '/auth/register/';
  static const String me = '/security/me/';
  static const String authMe = '/auth/me/';

  static const String categories = '/services/categories/';
  static const String serviceRequests = '/services/requests/';
  static const String availableRequests = '/services/requests/available/';
  static const String activeRequest = '/services/requests/active/';
  static const String locationPings = '/services/location-pings/';

  static String serviceRequest(int id) => '/services/requests/$id/';

  static String acceptRequest(int id) => '/services/requests/$id/accept/';
}
