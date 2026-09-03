import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:mnd_shop/features/profile/data/vendor_profile_repository.dart';

class VendorProfilePage extends ConsumerStatefulWidget {
  const VendorProfilePage({super.key});

  @override
  ConsumerState<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends ConsumerState<VendorProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _open = TextEditingController();
  final TextEditingController _close = TextEditingController();
  final TextEditingController _openingNote = TextEditingController();
  bool _closedSunday = false;

  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _city.dispose();
    _open.dispose();
    _close.dispose();
    _openingNote.dispose();
    super.dispose();
  }

  void _hydrateFromDoc(Map<String, dynamic>? doc) {
    if (_hydrated || doc == null) return;
    _hydrated = true;
    _name.text = (doc['name'] as String?)?.trim() ?? '';
    _description.text = (doc['description'] as String?)?.trim() ?? '';
    _phone.text = (doc['phone'] as String?)?.trim() ?? '';
    _whatsapp.text = (doc['whatsapp'] as String?)?.trim() ?? '';
    _address.text = (doc['addressLine'] as String?)?.trim() ?? '';
    _city.text = (doc['city'] as String?)?.trim() ?? '';
    final Map<String, dynamic>? oh =
        doc['openingHours'] as Map<String, dynamic>?;
    _open.text = (oh?['defaultOpen'] as String?)?.trim() ?? '';
    _close.text = (oh?['defaultClose'] as String?)?.trim() ?? '';
    _closedSunday = oh?['closedSunday'] == true;
    _openingNote.text = (oh?['note'] as String?)?.trim() ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final String? err = await ref
        .read(vendorProfileRepositoryProvider)
        .updateMyShopProfile(
          name: _name.text,
          description: _description.text,
          phone: _phone.text,
          whatsapp: _whatsapp.text,
          addressLine: _address.text,
          city: _city.text,
          openTime: _open.text,
          closeTime: _close.text,
          closedSunday: _closedSunday,
          openingNote: _openingNote.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              err,
              fallback: 'Could not save. Please try again.',
            ),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<Map<String, dynamic>?> vendorAsync = ref.watch(
      vendorAccountDocDataProvider,
    );
    final Map<String, dynamic>? doc = vendorAsync.valueOrNull;
    _hydrateFromDoc(doc);

    final bool active = doc?['active'] == true;
    final String email = (doc?['email'] as String?)?.trim().isNotEmpty == true
        ? (doc!['email'] as String).trim()
        : 'No email set';

    int profileScore = 0;
    if (_name.text.trim().isNotEmpty) {
      profileScore += 15;
    }
    if (_description.text.trim().isNotEmpty) {
      profileScore += 15;
    }
    if (_phone.text.trim().isNotEmpty) {
      profileScore += 15;
    }
    if (_address.text.trim().isNotEmpty) {
      profileScore += 15;
    }
    if (_city.text.trim().isNotEmpty) {
      profileScore += 10;
    }
    if (_open.text.trim().isNotEmpty && _close.text.trim().isNotEmpty) {
      profileScore += 15;
    }
    if (_whatsapp.text.trim().isNotEmpty) {
      profileScore += 5;
    }
    if (_openingNote.text.trim().isNotEmpty) {
      profileScore += 10;
    }
    if (profileScore > 100) {
      profileScore = 100;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shop profile')),
      body: vendorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load profile.\n\n${userFacingError(e, fallback: 'Please check your connection and try again.')}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (_) {
          return AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Shop Manager',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const VendorNotificationsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _name.text.trim().isEmpty ? 'Your Shop' : _name.text.trim(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _description.text.trim().isEmpty
                        ? 'Complete your profile details'
                        : _description.text.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.contact_mail_outlined,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Contact Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone number *',
                            ),
                            validator: (String? v) {
                              final String t = (v ?? '').trim();
                              if (t.length < 8) return 'Min 8 digits';
                              if (t.length > 32) return 'Max 32 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _whatsapp,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp (optional)',
                            ),
                            validator: (String? v) {
                              final String t = (v ?? '').trim();
                              if (t.length > 32) return 'Max 32 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Official email: $email',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.location_on_outlined,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Store Location',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _address,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Street / building / landmark *',
                            ),
                            validator: (String? v) =>
                                v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _city,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'City *',
                            ),
                            validator: (String? v) =>
                                v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.access_time_rounded,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Opening Hours',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFE5F7EA)
                                      : const Color(0xFFFBEAEA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  active ? 'OPEN NOW' : 'CLOSED',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: active
                                        ? const Color(0xFF2A7F3A)
                                        : const Color(0xFFB23B3B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              const Expanded(child: Text('Mon - Fri')),
                              Text(
                                '${_open.text.isEmpty ? '--:--' : _open.text} - ${_close.text.isEmpty ? '--:--' : _close.text}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: <Widget>[
                              const Expanded(child: Text('Sunday')),
                              Text(
                                _closedSunday ? 'Closed' : 'Open',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: _closedSunday ? cs.error : cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _open,
                            decoration: const InputDecoration(
                              labelText: 'Open (HH:MM) *',
                            ),
                            validator: (String? v) =>
                                (v ?? '').trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _close,
                            decoration: const InputDecoration(
                              labelText: 'Close (HH:MM) *',
                            ),
                            validator: (String? v) =>
                                (v ?? '').trim().isEmpty ? 'Required' : null,
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Closed on Sundays'),
                            value: _closedSunday,
                            onChanged: (bool v) =>
                                setState(() => _closedSunday = v),
                          ),
                          TextFormField(
                            controller: _openingNote,
                            maxLength: 80,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Opening note (optional)',
                              hintText: 'e.g. closes 3–5pm Fri',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF2E66DC), Color(0xFF2B57C3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Profile Strength',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Complete your profile to increase visibility.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                CircularProgressIndicator(
                                  value: profileScore / 100,
                                  strokeWidth: 5,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.35,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                                Center(
                                  child: Text(
                                    '$profileScore%',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Shop name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? v) {
                      final String t = (v ?? '').trim();
                      if (t.isEmpty) return 'Required';
                      if (t.length > 120) return 'Max 120 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (String? v) {
                      final String t = (v ?? '').trim();
                      if (t.isEmpty) return 'Required';
                      if (t.length < 10) return 'At least 10 characters';
                      if (t.length > 200) return 'Max 200 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save profile'),
          ),
        ),
      ),
    );
  }
}
