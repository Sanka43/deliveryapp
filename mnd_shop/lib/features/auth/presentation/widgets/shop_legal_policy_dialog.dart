import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/constants/shop_legal_urls.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShopLegalPolicyType { privacy, terms }

/// Opens the public HTTPS legal page; falls back to an in-app dialog.
Future<void> showShopLegalPolicyDialog(
  BuildContext context, {
  required ShopLegalPolicyType type,
}) async {
  final Uri uri = type == ShopLegalPolicyType.privacy
      ? ShopLegalUrls.privacyPolicyUri
      : ShopLegalUrls.termsOfServiceUri;
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
    builder: (BuildContext ctx) => _ShopLegalPolicyDialog(type: type),
  );
}

class _ShopLegalPolicyDialog extends StatelessWidget {
  const _ShopLegalPolicyDialog({required this.type});

  final ShopLegalPolicyType type;

  @override
  Widget build(BuildContext context) {
    final bool isPrivacy = type == ShopLegalPolicyType.privacy;
    final String title = isPrivacy
        ? _vTxt(context, en: 'Privacy Policy', si: 'රහස්‍යතා ප්‍රතිපත්තිය')
        : _vTxt(context, en: 'Terms of Service', si: 'සේවා නියම');
    final List<_PolicySection> sections =
        isPrivacy ? _privacySections(context) : _termsSections(context);

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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textCharcoal,
              ),
            ),
          ),
          IconButton(
            tooltip: _vTxt(context, en: 'Dismiss', si: 'වසන්න'),
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
                  _vTxt(
                    context,
                    en: 'Last updated: July 16, 2026',
                    si: 'අවසන් යාවත්කාලීනය: 2026 ජූලි 16',
                  ),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < sections.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 14),
                  Text(
                    sections[i].heading,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sections[i].body,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textMuted,
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
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              _vTxt(context, en: 'Got it', si: 'තේරුණා'),
              style: const TextStyle(fontWeight: FontWeight.w800),
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

List<_PolicySection> _privacySections(BuildContext context) {
  return <_PolicySection>[
    _PolicySection(
      heading: _vTxt(context, en: '1. Introduction', si: '1. හැඳින්වීම'),
      body: _vTxt(
        context,
        en:
            'MND Delivery ("MND", "we", "us") operates the MND Shop vendor app. '
            'This Privacy Policy explains how we collect, use, store, and protect '
            'information when you register and use the vendor platform.',
        si:
            'MND Delivery ("MND", "අපි") MND Shop vendor යෙදුම පවත්වාගෙන යයි. '
            'මෙම රහස්‍යතා ප්‍රතිපත්තියෙන් ඔබ vendor වේදිකාවේ ලියාපදිංචි වී භාවිතා කරන විට '
            'අපි තොරතුරු එකතු කරන, භාවිතා කරන, ගබඩා කරන සහ ආරක්ෂා කරන ආකාරය පැහැදිලි කරයි.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '2. Information we collect',
        si: '2. අප එකතු කරන තොරතුරු',
      ),
      body: _vTxt(
        context,
        en:
            'We may collect shop and account details such as business name, '
            'owner name, email address, phone number, shop address and map '
            'location, product catalogues, order history, device identifiers, '
            'and app usage data needed to run delivery operations.',
        si:
            'අපි ව්‍යාපාර නාමය, හිමිකරුගේ නම, email ලිපිනය, දුරකථන අංකය, '
            'කඩ ස්ථානය සහ සිතියම් පිහිටීම, නිෂ්පාදන ලැයිස්තු, ඇණවුම් ඉතිහාසය, '
            'උපාංග හඳුනාගැනීම් සහ බෙදාහැරීම් මෙහෙයුම් සඳහා අවශ්‍ය යෙදුම් භාවිත දත්ත '
            'වැනි කඩ සහ ගිණුම් විස්තර එකතු කළ හැක.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '3. How we use your information',
        si: '3. ඔබේ තොරතුරු භාවිතා කරන ආකාරය',
      ),
      body: _vTxt(
        context,
        en:
            'We use your information to create and manage vendor accounts, '
            'process and fulfil customer orders, enable payments and settlements, '
            'send order alerts and service notifications, improve app performance, '
            'prevent fraud, and comply with legal obligations.',
        si:
            'අපි ඔබේ තොරතුරු vendor ගිණුම් සෑදීමට සහ කළමනාකරණයට, පාරිභෝගික ඇණවුම් '
            'සැකසීමට සහ සම්පූර්ණ කිරීමට, ගෙවීම් සහ බේරුම්කරණයට, ඇණවුම් ඇඟවීම් සහ '
            'සේවා දැනුම්දීම් යැවීමට, යෙදුම් කාර්යසාධනය වැඩිදියුණු කිරීමට, වංචා '
            'වැළැක්වීමට සහ නීතිමය යුතුකම් පිළිපැදීමට භාවිතා කරමු.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '4. Sharing of information',
        si: '4. තොරතුරු බෙදාගැනීම',
      ),
      body: _vTxt(
        context,
        en:
            'We may share limited information with customers (for order fulfilment), '
            'delivery riders, payment processors, cloud infrastructure providers, '
            'and regulators when required by law. We do not sell your personal '
            'data to third parties for marketing.',
        si:
            'ඇණවුම් සම්පූර්ණ කිරීම සඳහා පාරිභෝගිකයන් සමඟ, බෙදාහැරීම් රයිඩර්වරුන්, '
            'ගෙවීම් සැකසුම්කරුවන්, වලාකුළු යටිතල පහසුකම් සපයන්නන් සහ නීතිය අනුව '
            'අවශ්‍ය වූ විට නියාමකයන් සමඟ සීමිත තොරතුරු බෙදාගත හැක. අපි ඔබේ පුද්ගලික '
            'දත්ත අලෙවිකරණය සඳහා තෙවන පාර්ශ්වයන්ට විකුණන්නේ නැත.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(context, en: '5. Data security', si: '5. දත්ත ආරක්ෂාව'),
      body: _vTxt(
        context,
        en:
            'We apply reasonable technical and organisational measures to protect '
            'your data, including authenticated access, encrypted transport, and '
            'restricted internal permissions. No method of transmission or storage '
            'is completely secure, so please keep your login credentials private.',
        si:
            'අපි සත්‍යාපිත ප්‍රවේශය, සංකේතනය කළ ප්‍රවාහනය සහ සීමිත අභ්‍යන්තර අවසර '
            'ඇතුළුව ඔබේ දත්ත ආරක්ෂා කිරීමට සාධාරණ තාක්ෂණික සහ සංවිධානාත්මක පියවර '
            'ගනිමු. කිසිදු ප්‍රවාහන හෝ ගබඩා ක්‍රමයක් සම්පූර්ණයෙන් ආරක්ෂිත නොවන බැවින් '
            'ඔබේ පිවිසුම් අක්තපත්‍ර පුද්ගලිකව තබා ගන්න.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(context, en: '6. Your rights', si: '6. ඔබේ අයිතිවාසිකම්'),
      body: _vTxt(
        context,
        en:
            'You may request access to, correction of, or deletion of your account '
            'information, subject to legal and operational retention needs. Contact '
            'MND Shop support from the app settings or your onboarding channel to '
            'submit a request.',
        si:
            'නීතිමය සහ මෙහෙයුම් රඳවා තබා ගැනීමේ අවශ්‍යතාවලට යටත්ව, ඔබේ ගිණුම් '
            'තොරතුරු වෙත ප්‍රවේශ වීමට, නිවැරදි කිරීමට හෝ මකා දැමීමට ඉල්ලීමක් කළ හැක. '
            'ඉල්ලීමක් ඉදිරිපත් කිරීමට යෙදුම් සැකසුම්වලින් හෝ ඔබේ ලියාපදිංචි නාලිකාවෙන් '
            'MND Shop සහාය අමතන්න.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(context, en: '7. Contact', si: '7. සම්බන්ධ වන්න'),
      body: _vTxt(
        context,
        en:
            'For privacy questions about the MND Shop vendor app, contact MND '
            'Delivery support through the in-app support option or your vendor '
            'onboarding representative.',
        si:
            'MND Shop vendor යෙදුම පිළිබඳ රහස්‍යතා ප්‍රශ්න සඳහා, යෙදුම තුළ සහාය '
            'විකල්පය හරහා හෝ ඔබේ vendor ලියාපදිංචි නියෝජිතයා හරහා MND Delivery '
            'සහාය අමතන්න.',
      ),
    ),
  ];
}

List<_PolicySection> _termsSections(BuildContext context) {
  return <_PolicySection>[
    _PolicySection(
      heading: _vTxt(context, en: '1. Acceptance', si: '1. පිළිගැනීම'),
      body: _vTxt(
        context,
        en:
            'By creating a vendor account or signing in to MND Shop, you agree to '
            'these Terms of Service and all related platform policies, including the '
            'Privacy Policy. If you do not agree, do not use the app.',
        si:
            'Vendor ගිණුමක් සෑදීමෙන් හෝ MND Shop වෙත පිවිසීමෙන්, ඔබ මෙම සේවා නියම '
            'සහ රහස්‍යතා ප්‍රතිපත්තිය ඇතුළු අදාළ වේදිකා ප්‍රතිපත්තිවලට එකඟ වේ. එකඟ '
            'නොවන්නේ නම් යෙදුම භාවිතා නොකරන්න.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '2. Eligibility and account',
        si: '2. සුදුසුකම් සහ ගිණුම',
      ),
      body: _vTxt(
        context,
        en:
            'You must be authorised to operate the registered shop and provide true, '
            'complete business details. You are responsible for all activity under '
            'your login. Notify MND immediately if you suspect unauthorised access.',
        si:
            'ඔබ ලියාපදිංචි කඩය ක්‍රියාත්මක කිරීමට අවසර ලත් අයෙකු විය යුතු අතර සත්‍ය, '
            'සම්පූර්ණ ව්‍යාපාර විස්තර ලබා දිය යුතුය. ඔබේ පිවිසුම යටතේ සිදුවන සියලු '
            'ක්‍රියාකාරකම් සඳහා ඔබ වගකිව යුතුය. අනවසර ප්‍රවේශයක් සැක කරන්නේ නම් වහාම '
            'MND දැනුවත් කරන්න.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '3. Vendor responsibilities',
        si: '3. Vendor වගකීම්',
      ),
      body: _vTxt(
        context,
        en:
            'You must keep shop profile, product availability, and pricing accurate; '
            'prepare accepted orders on time; follow food safety and business laws; '
            'and treat customers and riders respectfully. Misleading listings or '
            'unsafe products are not allowed.',
        si:
            'ඔබ කඩ පැතිකඩ, නිෂ්පාදන ලබා ගත හැකි බව සහ මිල නිවැරදිව තබා ගත යුතුය; '
            'පිළිගත් ඇණවුම් නියමිත වේලාවට සූදානම් කළ යුතුය; ආහාර ආරක්ෂාව සහ ව්‍යාපාර '
            'නීති පිළිපැදිය යුතුය; පාරිභෝගිකයන්ට සහ රයිඩර්වරුන්ට ගෞරවයෙන් සැලකිය යුතුය. '
            'නොමඟ යවන ලැයිස්තු හෝ අනාරක්ෂිත නිෂ්පාදන අවසර නැත.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '4. Orders and fulfilment',
        si: '4. ඇණවුම් සහ සම්පූර්ණ කිරීම',
      ),
      body: _vTxt(
        context,
        en:
            'Incoming orders must be accepted or rejected promptly. Once accepted, '
            'you must prepare the order as described. Repeated cancellations, long '
            'delays, or inaccurate listings may lead to warnings or temporary '
            'suspension from the marketplace.',
        si:
            'පැමිණෙන ඇණවුම් ඉක්මනින් පිළිගත හෝ ප්‍රතික්ෂේප කළ යුතුය. පිළිගත් පසු, '
            'විස්තර කළ පරිදි ඇණවුම සූදානම් කළ යුතුය. නැවත නැවත අවලංගු කිරීම්, දිගු '
            'ප්‍රමාද හෝ වැරදි ලැයිස්තු නිසා අනතුරු ඇඟවීම් හෝ වෙළඳපොළෙන් තාවකාලිකව '
            'අත්හිටුවීමට ලක් විය හැක.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '5. Fees, payouts, and taxes',
        si: '5. ගාස්තු, ගෙවීම් සහ බදු',
      ),
      body: _vTxt(
        context,
        en:
            'Platform commission, delivery fees, and settlement timelines are set by '
            'MND and may be updated with notice. You remain responsible for any '
            'taxes or regulatory filings related to your shop sales.',
        si:
            'වේදිකා කොමිසම්, බෙදාහැරීම් ගාස්තු සහ බේරුම්කරණ කාලසීමා MND විසින් '
            'නියම කරන අතර දැනුම්දීමක් සමඟ යාවත්කාලීන කළ හැක. ඔබේ කඩ අලෙවියට අදාළ '
            'බදු හෝ නියාමන ලිපිගොනු සඳහා වගකීම ඔබ සතුව පවතී.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '6. Prohibited use',
        si: '6. තහනම් භාවිතය',
      ),
      body: _vTxt(
        context,
        en:
            'You may not misuse the app to commit fraud, manipulate ratings, harass '
            'users, scrape data, bypass security, sell illegal items, or interfere '
            'with MND systems or other vendors.',
        si:
            'වංචා කිරීමට, ශ්‍රේණිගත කිරීම් හැසිරවීමට, පරිශීලකයන්ට හිරිහැර කිරීමට, '
            'දත්ත ඉවත් කිරීමට, ආරක්ෂාව මඟහැරීමට, නීති විරෝධී භාණ්ඩ විකිණීමට හෝ MND '
            'පද්ධති සහ අනෙකුත් vendorවරුන්ට බාධා කිරීමට යෙදුම අනිසි ලෙස භාවිතා '
            'නොකළ යුතුය.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '7. Account suspension',
        si: '7. ගිණුම අත්හිටුවීම',
      ),
      body: _vTxt(
        context,
        en:
            'MND may suspend or terminate access for policy violations, fraud, '
            'safety concerns, or prolonged inactivity. You may also request account '
            'closure through support, subject to outstanding orders and settlements.',
        si:
            'ප්‍රතිපත්ති උල්ලංඝනය, වංචා, ආරක්ෂක ගැටළු හෝ දිගු කාලීන අක්‍රියතාව නිසා '
            'MND ප්‍රවේශය අත්හිටුවිය හෝ අවසන් කළ හැක. පොරොත්තු ඇණවුම් සහ බේරුම්කරණවලට '
            'යටත්ව, සහාය හරහා ගිණුම වසා දැමීමටද ඔබට ඉල්ලිය හැක.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '8. Intellectual property',
        si: '8. බුද්ධිමය දේපළ',
      ),
      body: _vTxt(
        context,
        en:
            'MND branding, software, and platform content remain MND property. You '
            'keep rights to your shop logos and product content, and grant MND a '
            'licence to display them for marketplace and marketing use.',
        si:
            'MND සන්නාමකරණය, මෘදුකාංග සහ වේදිකා අන්තර්ගතය MND සතුව පවතී. ඔබේ කඩ '
            'ලාංඡන සහ නිෂ්පාදන අන්තර්ගතයට අයිතිය ඔබ සතුව පවතින අතර, වෙළඳපොළ සහ '
            'අලෙවිකරණ භාවිතය සඳහා ඒවා ප්‍රදර්ශනය කිරීමට MND හට බලපත්‍රයක් ලබා දෙයි.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(
        context,
        en: '9. Limitation of liability',
        si: '9. වගකීම් සීමාව',
      ),
      body: _vTxt(
        context,
        en:
            'To the fullest extent permitted by law, MND is not liable for indirect '
            'or consequential losses from use of the vendor app, including missed '
            'orders caused by device, network, or third-party failures.',
        si:
            'නීතියෙන් අනුමත කරන උපරිම ප්‍රමාණයට, උපාංග, ජාල හෝ තෙවන පාර්ශ්ව '
            'අසාර්ථකත්වය නිසා මඟහැරුණු ඇණවුම් ඇතුළුව vendor යෙදුම භාවිතයෙන් ඇතිවන '
            'වක්‍ර හෝ ප්‍රතිවිපාක අලාභ සඳහා MND වගකිව යුතු නොවේ.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(context, en: '10. Changes', si: '10. වෙනස්කම්'),
      body: _vTxt(
        context,
        en:
            'We may update these terms from time to time. Continued use of MND Shop '
            'after changes means you accept the updated terms. Material changes may '
            'also be communicated in-app or by email.',
        si:
            'අපි කලින් කලට මෙම නියම යාවත්කාලීන කළ හැක. වෙනස්කම්වලට පසුවත් MND Shop '
            'භාවිතා කිරීමෙන් යාවත්කාලීන නියම පිළිගන්නා බව අදහස් වේ. වැදගත් වෙනස්කම් '
            'යෙදුම තුළ හෝ email මගින්ද දැනුම් දිය හැක.',
      ),
    ),
    _PolicySection(
      heading: _vTxt(context, en: '11. Contact', si: '11. සම්බන්ධ වන්න'),
      body: _vTxt(
        context,
        en:
            'For questions about these Terms of Service, contact MND Delivery '
            'support through the in-app support option or your vendor onboarding '
            'representative.',
        si:
            'මෙම සේවා නියම පිළිබඳ ප්‍රශ්න සඳහා, යෙදුම තුළ සහාය විකල්පය හරහා හෝ '
            'ඔබේ vendor ලියාපදිංචි නියෝජිතයා හරහා MND Delivery සහාය අමතන්න.',
      ),
    ),
  ];
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return ta ?? vendorTamilFallback(en);
  return en;
}
