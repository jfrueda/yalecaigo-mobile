abstract final class Endpoints {
  // Authentication and onboarding.
  static const String tokenObtain = '/auth/token/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String register = '/auth/register/';
  static const String geographyCountries = '/auth/geography/countries/';
  static const String geographyPlaces = '/auth/geography/places/';
  static const String modes = '/auth/modes/';
  static const String logout = '/auth/logout/';
  static const String logoutAll = '/auth/logout-all/';
  static const String logoutOthers = '/auth/logout-others/';
  static const String sessions = '/auth/sessions/';
  static const String changePassword = '/auth/change-password/';
  static const String passwordResetRequest = '/auth/password-reset/request/';
  static const String passwordResetConfirm = '/auth/password-reset/confirm/';
  static const String otpRequest = '/auth/otp/request/';
  static const String otpVerify = '/auth/otp/verify/';
  static const String legalDocuments = '/auth/legal-documents/';
  static const String consents = '/auth/consents/';
  static const String onboardingStatus = '/auth/onboarding/status/';
  static const String socialGoogle = '/auth/social/google/';
  static const String socialFacebook = '/auth/social/facebook/';
  static const String socialCompleteRegistration =
      '/auth/social/complete-registration/';
  static const String socialAccounts = '/auth/social/accounts/';
  static const String socialLink = '/auth/social/link/';
  static const String authMe = '/auth/me/';
  static const String profile = '/auth/profile/';
  static const String locationOptions = '/auth/location-options/';
  static const String securityPhone = '/auth/security-phone/';
  static const String providerProfile = '/auth/provider-profile/';
  static const String providerProfileSubmitReview =
      '/auth/provider-profile/submit-review/';
  static const String providerCapabilities = '/auth/provider-capabilities/';
  static const String emergencyContacts = '/auth/emergency-contacts/';
  static const String availability = '/auth/availability/';
  static const String identityVerification = '/auth/identity-verification/';
  static const String identityVerificationResubmit =
      '/auth/identity-verification/resubmit/';
  static const String accountDeletionStatus = '/auth/account-deletion/status/';
  static const String accountDeletionRequest =
      '/auth/account-deletion/request/';
  static const String accountDeletionConfirm =
      '/auth/account-deletion/confirm/';
  static const String accountDeletionCancel = '/auth/account-deletion/cancel/';

  static String session(String sessionId) => '/auth/sessions/$sessionId/';

  static String socialUnlink(String provider) =>
      '/auth/social/${provider.toLowerCase()}/unlink/';

  static String emergencyContact(int id) => '/auth/emergency-contacts/$id/';

  static String identityDocument(int verificationId, String documentKind) =>
      '/auth/identity-verification/$verificationId/documents/$documentKind/';

  // Security.
  static const String me = '/security/me/';
  static const String panicEvents = '/security/panic-events/';
  static const String sos = '/security/sos/';
  static const String activeSos = '/security/sos/active/';

  static String sosDetail(int incidentId) => '/security/sos/$incidentId/';

  // Notifications.
  static const String notifications = '/notifications/';
  static const String notificationDevices = '/notifications/devices/';
  static const String notificationUnreadCount = '/notifications/unread-count/';
  static const String notificationReadAll = '/notifications/read-all/';

  static String notificationRead(int notificationId) =>
      '/notifications/$notificationId/read/';

  // Service categories, requests and offers.
  static const String categories = '/services/categories/';
  static const String serviceRequests = '/services/requests/';
  static const String availableRequests = '/services/requests/available/';
  static const String activeRequest = '/services/requests/active/';
  static const String providerHistory = '/services/requests/provider-history/';
  static const String locationPings = '/services/location-pings/';
  static const String serviceOffers = '/services/offers/';

  static String serviceRequest(int id) => '/services/requests/$id/';

  static String acceptRequest(int id) => '/services/requests/$id/accept/';

  static String confirmRequest(int id) => '/services/requests/$id/confirm/';

  static String enRouteRequest(int id) => '/services/requests/$id/en-route/';

  static String arriveRequest(int id) => '/services/requests/$id/arrive/';

  static String startRequest(int id) => '/services/requests/$id/start/';

  static String finishRequest(int id) => '/services/requests/$id/finish/';

  static String completionRequest(int id) =>
      '/services/requests/$id/completion/';

  static String noShowRequest(int id) => '/services/requests/$id/no-show/';

  static String lateRequest(int id) => '/services/requests/$id/late/';

  static String rescheduleRequest(int id) =>
      '/services/requests/$id/reschedule/';

  static String respondRescheduleRequest(int id) =>
      '/services/requests/$id/reschedule/respond/';

  static String cancelRequest(int id) => '/services/requests/$id/cancel/';

  static String dismissRequest(int id) => '/services/requests/$id/dismiss/';

  static String rateRequest(int id) => '/services/requests/$id/rate/';

  static String ratingRequest(int id) => '/services/requests/$id/rating/';

  static String behaviorReport(int id) => '/services/requests/$id/report/';

  static const String blockedUsers = '/services/blocked-users/';

  static String blockUser(int userId) => '/services/users/$userId/block/';

  static String providerReputation(int providerId) =>
      '/services/providers/$providerId/reputation/';

  static String trackingRequest(int id) => '/services/requests/$id/tracking/';

  static String shareRequest(int id) => '/services/requests/$id/share/';

  static String safetyTimerRequest(int id) =>
      '/services/requests/$id/safety-timer/';

  static String sharedActivity(String token) => '/services/shared/$token/';

  static String acceptOffer(int id) => '/services/offers/$id/accept/';

  static String rejectOffer(int id) => '/services/offers/$id/reject/';

  // Payments and provider wallet.
  static const String wallet = '/payments/wallet/';
  static const String walletTransactions = '/payments/wallet/transactions/';

  static String payment(int requestId) => '/payments/requests/$requestId/';

  static String epaycoCheckoutSession(int requestId) =>
      '/payments/epayco/requests/$requestId/session/';

  static String simulatePayment(int requestId) =>
      '/payments/requests/$requestId/simulate-approve/';

  static String releasePayment(int requestId) =>
      '/payments/requests/$requestId/release/';

  // Chat.
  static String chatRoom(int serviceRequestId) =>
      '/chat/rooms/$serviceRequestId/';

  static String chatMessages(int serviceRequestId) =>
      '/chat/rooms/$serviceRequestId/messages/';
}
