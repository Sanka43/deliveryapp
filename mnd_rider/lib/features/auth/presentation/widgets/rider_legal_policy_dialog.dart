import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/legal_urls.dart';
import 'package:url_launcher/url_launcher.dart';

enum RiderLegalPolicyType { privacy, terms }

/// Opens the public HTTPS legal page; falls back to an in-app dialog.
Future<void> showRiderLegalPolicyDialog(
  BuildContext context, {
  required RiderLegalPolicyType type,
}) async {
  final Uri uri = type == RiderLegalPolicyType.privacy
      ? LegalUrls.privacyPolicyUri
      : LegalUrls.termsOfServiceUri;
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
      return;
    }
  } catch (_) {
    // Fall through to in-app copy.
  }
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => _RiderLegalPolicyDialog(type: type),
  );
}

class _RiderLegalPolicyDialog extends StatelessWidget {
  const _RiderLegalPolicyDialog({required this.type});

  final RiderLegalPolicyType type;

  static const Color _ink = Color(0xFF0A0A0A);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final bool isPrivacy = type == RiderLegalPolicyType.privacy;
    final String title =
        isPrivacy ? 'Privacy Policy' : 'Terms of Service';
    final List<_PolicySection> sections =
        isPrivacy ? _privacySections : _termsSections;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      title: Row(
        children: <Widget>[
          Icon(
            isPrivacy
                ? Icons.privacy_tip_outlined
                : Icons.description_outlined,
            color: AppColors.primaryBlue,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Last updated: July 16, 2026',
                  style: GoogleFonts.plusJakartaSans(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < sections.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 14),
                  Text(
                    sections[i].heading,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sections[i].body,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.45,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'Got it',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.heading, required this.body});

  final String heading;
  final String body;
}

const List<_PolicySection> _privacySections = <_PolicySection>[
  _PolicySection(
    heading: '1. Introduction',
    body:
        'MND Delivery ("MND", "we", "us") operates the MND Rider app. '
        'This Privacy Policy explains how we collect, use, store, and protect '
        'information when you register and use the rider platform.',
  ),
  _PolicySection(
    heading: '2. Information we collect',
    body:
        'We may collect personal and account details such as your full name, '
        'phone number, NIC, city, profile photo, driving license, vehicle '
        'photos, insurance and revenue license documents, vehicle type and '
        'number, location data while online, device identifiers, and app usage '
        'data needed to run delivery operations.',
  ),
  _PolicySection(
    heading: '3. How we use your information',
    body:
        'We use your information to create and manage rider accounts, verify '
        'your identity and documents, assign and fulfil delivery jobs, process '
        'earnings and settlements, send job alerts and service notifications, '
        'improve app performance, prevent fraud, and comply with legal obligations.',
  ),
  _PolicySection(
    heading: '4. Sharing of information',
    body:
        'We may share limited information with customers and vendors (for order '
        'fulfilment), payment processors, cloud infrastructure providers, and '
        'regulators when required by law. We do not sell your personal data '
        'to third parties for marketing.',
  ),
  _PolicySection(
    heading: '5. Data security',
    body:
        'We apply reasonable technical and organisational measures to protect '
        'your data, including authenticated access, encrypted transport, and '
        'restricted internal permissions. Please keep your login credentials private.',
  ),
  _PolicySection(
    heading: '6. Your rights',
    body:
        'You may request access to, correction of, or deletion of your account '
        'information, subject to legal and operational retention needs. Contact '
        'MND Rider support to submit a request.',
  ),
  _PolicySection(
    heading: '7. Contact',
    body:
        'For privacy questions about the MND Rider app, contact MND Delivery '
        'support through the in-app support option.',
  ),
];

const List<_PolicySection> _termsSections = <_PolicySection>[
  _PolicySection(
    heading: '1. Acceptance',
    body:
        'By creating a rider account or signing in to MND Rider, you agree to '
        'these Terms of Service and all related platform policies, including the '
        'Privacy Policy. If you do not agree, do not use the app.',
  ),
  _PolicySection(
    heading: '2. Eligibility and account',
    body:
        'You must hold a valid driving license, meet vehicle and insurance '
        'requirements, and provide true, complete registration details. You are '
        'responsible for all activity under your login. Notify MND immediately '
        'if you suspect unauthorised access.',
  ),
  _PolicySection(
    heading: '3. Rider responsibilities',
    body:
        'You must keep your profile, documents, and vehicle details accurate; '
        'accept and fulfil assigned jobs safely and on time; follow traffic and '
        'business laws; and treat customers, vendors, and other users respectfully.',
  ),
  _PolicySection(
    heading: '4. Jobs and fulfilment',
    body:
        'Incoming job offers must be accepted or declined promptly. Once accepted, '
        'you must complete the delivery as described. Repeated cancellations, '
        'delays, or policy violations may lead to warnings or suspension.',
  ),
  _PolicySection(
    heading: '5. Earnings and payouts',
    body:
        'Delivery fees, commissions, and settlement timelines are set by MND and '
        'may be updated with notice. You remain responsible for any taxes or '
        'regulatory filings related to your earnings.',
  ),
  _PolicySection(
    heading: '6. Prohibited use',
    body:
        'You may not misuse the app to commit fraud, manipulate ratings, harass '
        'users, scrape data, bypass security, or interfere with MND systems or '
        'other riders.',
  ),
  _PolicySection(
    heading: '7. Account suspension',
    body:
        'MND may suspend or terminate access for policy violations, fraud, '
        'safety concerns, or expired documents. You may also request account '
        'closure through support, subject to outstanding jobs and settlements.',
  ),
  _PolicySection(
    heading: '8. Changes',
    body:
        'We may update these terms from time to time. Continued use of MND Rider '
        'after changes means you accept the updated terms.',
  ),
  _PolicySection(
    heading: '9. Contact',
    body:
        'For questions about these Terms of Service, contact MND Delivery support '
        'through the in-app support option.',
  ),
];
