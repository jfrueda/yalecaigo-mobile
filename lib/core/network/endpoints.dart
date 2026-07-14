abstract final class Endpoints {
  static const String tokenObtain = '/auth/token/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String register = '/auth/register/';
  static const String passwordResetRequest = '/auth/password-reset/request/';
  static const String passwordResetConfirm = '/auth/password-reset/confirm/';
  static const String me = '/security/me/';
  static const String authMe = '/auth/me/';

  static const String categories = '/services/categories/';
  static const String serviceRequests = '/services/requests/';
  static const String availableRequests = '/services/requests/available/';
  static const String providerHistory = '/services/requests/provider-history/';
  static const String activeRequest = '/services/requests/active/';
  static const String locationPings = '/services/location-pings/';
  static const String panicEvents = '/security/panic-events/';
  static const String notifications = '/notifications/';

  static String serviceRequest(int id) => '/services/requests/$id/';
  static String acceptRequest(int id) => '/services/requests/$id/accept/';
  static String arriveRequest(int id) => '/services/requests/$id/arrive/';
  static String startRequest(int id) => '/services/requests/$id/start/';
  static String finishRequest(int id) => '/services/requests/$id/finish/';
  static String lateRequest(int id) => '/services/requests/$id/late/';
  static String cancelRequest(int id) => '/services/requests/$id/cancel/';
  static String rateRequest(int id) => '/services/requests/$id/rate/';

  static String payment(int id) => '/payments/requests/$id/';
  static String simulatePayment(int id) =>
      '/payments/requests/$id/simulate-approve/';
  static String releasePayment(int id) => '/payments/requests/$id/release/';
}
