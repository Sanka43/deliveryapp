import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/constants/legal_urls.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

enum LegalDocumentKind { privacy, terms }

/// In-app Privacy Policy / Terms (Play Store: easily accessible from the app).
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({required this.kind, super.key});

  final LegalDocumentKind kind;

  bool get _isPrivacy => kind == LegalDocumentKind.privacy;

  String get _title => _isPrivacy ? 'Privacy Policy' : 'Terms of Service';

  String get _webUrl =>
      _isPrivacy ? LegalUrls.privacyPolicy : LegalUrls.termsOfService;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_LegalSection> sections =
        _isPrivacy ? _privacySections : _termsSections;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: _title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          Text(
            'Last updated: 6 August 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...sections.map(
            (_LegalSection s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.heading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(s.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final Uri uri = Uri.parse(_webUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open on website'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Questions: ${LegalUrls.supportEmail}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

const List<_LegalSection> _privacySections = <_LegalSection>[
  _LegalSection(
    'Who we are',
    'MND Delivery (“MND”, “we”) provides food, grocery, ride, and local jobs '
        'services through the MND customer app. Contact: ${LegalUrls.supportEmail}.',
  ),
  _LegalSection(
    'Data we collect',
    'Account data (phone number via OTP, name, email if provided, profile photo), '
        'delivery addresses, order and trip history, approximate/precise location '
        'when you grant permission (maps, delivery pin, live features), device '
        'push notification tokens, and app usage needed to operate the service.',
  ),
  _LegalSection(
    'How we use data',
    'To authenticate you, fulfil orders and rides, show maps and ETAs, send '
        'order/promo notifications you opt into, prevent fraud, and improve the app. '
        'We do not sell your personal information.',
  ),
  _LegalSection(
    'Sharing',
    'We share data with vendors and riders only as needed to fulfil your order '
        'or trip, and with Firebase/Google infrastructure that hosts Auth, '
        'Firestore, Storage, Maps, and Messaging. Legal disclosure may occur when '
        'required by law.',
  ),
  _LegalSection(
    'reCAPTCHA (web)',
    'On the web app, phone sign-in is protected by Google reCAPTCHA. Use of '
        'reCAPTCHA is subject to the Google Privacy Policy and Terms of Service. '
        'reCAPTCHA may collect hardware and software information for abuse '
        'prevention; that data is used under Google’s policies.',
  ),
  _LegalSection(
    'Retention & deletion',
    'We keep account and order data while your account is active and as needed '
        'for legal/accounting purposes. You can delete your account in Settings → '
        'Delete account. That removes your Auth account and customer profile data '
        'from the app backends we control; some anonymised operational records '
        '(e.g. completed orders) may remain for business records.',
  ),
  _LegalSection(
    'Your choices',
    'You can deny location or notification permissions in system settings, '
        'update profile data in the app, and request support via '
        '${LegalUrls.supportEmail}.',
  ),
];

const List<_LegalSection> _termsSections = <_LegalSection>[
  _LegalSection(
    'Agreement',
    'By using the MND Delivery customer app you agree to these Terms and our '
        'Privacy Policy. If you do not agree, do not use the app.',
  ),
  _LegalSection(
    'Service',
    'MND connects customers with local vendors, riders, and job listings. '
        'Availability, prices, delivery fees, and ETAs may change. Cash on '
        'delivery is the current payment method unless otherwise stated in-app.',
  ),
  _LegalSection(
    'Accounts',
    'You must provide accurate information and keep your phone number secure. '
        'You are responsible for activity under your account. You may delete your '
        'account at any time from Settings.',
  ),
  _LegalSection(
    'Acceptable use',
    'Do not misuse the app (fraud, harassment, illegal listings, spam, or '
        'attempts to disrupt systems). We may suspend accounts that violate '
        'these Terms or applicable law.',
  ),
  _LegalSection(
    'User content (jobs)',
    'Job posts and applications you submit must be lawful and accurate. We may '
        'moderate or remove content. Listing visibility may require admin approval.',
  ),
  _LegalSection(
    'Liability',
    'To the fullest extent permitted by law, MND is not liable for indirect or '
        'consequential losses arising from third-party vendors, riders, or '
        'network outages. Nothing in these Terms limits rights you have under '
        'mandatory consumer law in your country.',
  ),
  _LegalSection(
    'Contact',
    'Support: ${LegalUrls.supportEmail}',
  ),
];
