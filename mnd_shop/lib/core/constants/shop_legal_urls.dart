/// Public HTTPS legal pages for Play Console and in-app links.
///
/// Hosted on the admin Firebase Hosting site (`mnd-masterndelivery`).
/// Deploy with: `firebase deploy --only hosting:admin`
abstract final class ShopLegalUrls {
  static const String privacyPolicy =
      'https://mnd-masterndelivery.web.app/legal/shop-privacy.html';

  static const String termsOfService =
      'https://mnd-masterndelivery.web.app/legal/shop-terms.html';

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicy);

  static Uri get termsOfServiceUri => Uri.parse(termsOfService);
}
