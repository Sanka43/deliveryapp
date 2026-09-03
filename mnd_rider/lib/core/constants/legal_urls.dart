/// Public legal URLs for Play Console and in-app links.
/// Hosted on Firebase Hosting site `mnd-customer-legal` (shared with customer app).
abstract final class LegalUrls {
  static const String privacyPolicy =
      'https://mnd-customer-legal.web.app/privacy';
  static const String termsOfService =
      'https://mnd-customer-legal.web.app/terms';

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicy);

  static Uri get termsOfServiceUri => Uri.parse(termsOfService);
}
