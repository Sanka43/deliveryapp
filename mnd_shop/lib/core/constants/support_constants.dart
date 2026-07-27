/// Vendor help & support contact details (update for production).
abstract final class SupportConstants {
  static const String supportPhoneDisplay = '+94 77 637 6869';
  static const String supportPhoneE164 = '+94776376869';
  static const String supportWhatsAppDigits = '94776376869';
  static const String supportEmail = 'masterndelivery111@gmail.com';
  static const String supportWhatsAppMessage =
      'Hi, I need help with my MND Shop account.';

  static Uri get supportTelUri => Uri.parse('tel:$supportPhoneE164');

  static Uri get supportEmailUri => Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: 'subject=${Uri.encodeComponent('MND Shop support')}',
  );

  static Uri get supportWhatsAppUri => Uri.parse(
    'https://wa.me/$supportWhatsAppDigits?text=${Uri.encodeComponent(supportWhatsAppMessage)}',
  );

  static Uri get supportWhatsAppAppUri => Uri.parse(
    'whatsapp://send?phone=$supportWhatsAppDigits&text=${Uri.encodeComponent(supportWhatsAppMessage)}',
  );
}
