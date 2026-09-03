import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/media/offer_image_picker.dart';
import 'package:mnd_shop/core/media/offer_image_spec.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/offers/data/offer_image_storage.dart';
import 'package:mnd_shop/features/offers/data/vendor_offers_repository.dart';
import 'package:mnd_shop/features/offers/domain/vendor_offer.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';

class OfferFormPage extends ConsumerStatefulWidget {
  const OfferFormPage({super.key, required this.offer});

  final VendorOffer? offer;

  bool get isEdit => offer != null;

  @override
  ConsumerState<OfferFormPage> createState() => _OfferFormPageState();
}

class _OfferFormPageState extends ConsumerState<OfferFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;

  Uint8List? _pickedBytes;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final VendorOffer? o = widget.offer;
    _titleCtrl = TextEditingController(text: o?.title ?? '');
    _descCtrl = TextEditingController(text: o?.description ?? '');
    _priceCtrl = TextEditingController(
      text: o == null ? '' : o.priceLkr.toString(),
    );
    _endsAt = o?.endsAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _vTxt(BuildContext context, {required String en, required String si}) {
    final String languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'si') {
      return si;
    }
    if (languageCode == 'ta') {
      return vendorTamilFallback(en);
    }
    return en;
  }

  Future<void> _pickImage() async {
    final Uint8List? bytes =
        await OfferImagePicker.pickFromGalleryAndCrop(context);
    if (bytes == null || !mounted) {
      return;
    }
    setState(() {
      _pickedBytes = bytes;
    });
  }

  Future<void> _pickEndsAt() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _endsAt != null && _endsAt!.isAfter(now)
        ? _endsAt!
        : now.add(const Duration(days: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _endsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_endsAt == null || !_endsAt!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vTxt(
              context,
              en: 'Pick an offer end time in the future',
              si: 'අනාගත අවසන් වේලාවක් තෝරන්න',
            ),
          ),
        ),
      );
      return;
    }

    final bool hasExistingImage =
        widget.offer != null && widget.offer!.imageUrl.trim().isNotEmpty;
    if (_pickedBytes == null && !hasExistingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vTxt(
              context,
              en: 'Add an offer image',
              si: 'Offer රූපයක් එක් කරන්න',
            ),
          ),
        ),
      );
      return;
    }

    final String storeId = ref.read(vendorProductCatalogStoreIdProvider).trim();
    if (storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vTxt(
              context,
              en: 'Sign in again so your store can load',
              si: 'Store ලබා ගැනීමට නැවත sign in කරන්න',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final VendorOffersRepository repo =
          ref.read(vendorOffersRepositoryProvider);
      final OfferImageStorage storage = ref.read(offerImageStorageProvider);
      final String storeName = widget.offer?.storeName ??
          await repo.fetchVendorDisplayName(storeId);
      final int priceLkr = int.parse(_priceCtrl.text.trim());
      final String title = _titleCtrl.text.trim();
      final String description = _descCtrl.text.trim();

      if (widget.isEdit) {
        final VendorOffer existing = widget.offer!;
        String imageUrl = existing.imageUrl;
        if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
          await storage.deleteOfferImage(existing.imageUrl);
          imageUrl = await storage.uploadOfferImage(
            storeId: storeId,
            offerId: existing.id,
            bytes: _pickedBytes!,
            fileName: 'offer.jpg',
          );
        }
        await repo.updateOffer(
          existing: existing,
          storeName: storeName,
          title: title,
          description: description,
          imageUrl: imageUrl,
          priceLkr: priceLkr,
          endsAt: _endsAt!,
        );
      } else {
        final String offerId = repo.allocateOfferId();
        final String imageUrl = await storage.uploadOfferImage(
          storeId: storeId,
          offerId: offerId,
          bytes: _pickedBytes!,
          fileName: 'offer.jpg',
        );
        await repo.createOffer(
          offerId: offerId,
          storeId: storeId,
          storeName: storeName,
          title: title,
          description: description,
          imageUrl: imageUrl,
          priceLkr: priceLkr,
          endsAt: _endsAt!,
          createdBy: storeId,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vTxt(
              context,
              en: 'Saved. Waiting for admin approval.',
              si: 'සුරකින ලදී. Admin අනුමත කිරීම බලාපොරොත්තු වේ.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not save. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? existingImage = widget.offer?.imageUrl;
    final bool showPreview = _pickedBytes != null ||
        (existingImage != null && existingImage.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: VendorProductsTheme.canvas(context),
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? _vTxt(context, en: 'Edit offer', si: 'Offer සංස්කරණය')
              : _vTxt(context, en: 'Add offer', si: 'Offer එකතු කරන්න'),
        ),
      ),
      body: VendorResponsiveContent(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              InkWell(
                onTap: _saving ? null : _pickImage,
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: OfferImageSpec.previewAspectRatio,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: VendorProductsTheme.thumbPlaceholderFill(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: showPreview
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _pickedBytes != null
                                ? Image.memory(
                                    _pickedBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  )
                                : Image.network(
                                    existingImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.add_photo_alternate_outlined, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  _vTxt(
                                    context,
                                    en: 'Tap to add image',
                                    si: 'රූපය එක් කිරීමට tap කරන්න',
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _vTxt(context, en: 'Title', si: 'මාතෘකාව'),
                ),
                validator: (String? v) {
                  final String t = (v ?? '').trim();
                  if (t.isEmpty) {
                    return _vTxt(context, en: 'Required', si: 'අවශ්‍යයි');
                  }
                  if (t.length > 120) {
                    return _vTxt(context, en: 'Too long', si: 'දිග වැඩියි');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _vTxt(
                    context,
                    en: 'Description (optional)',
                    si: 'විස්තරය (විකල්ප)',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: _vTxt(context, en: 'Price (LKR)', si: 'මිල (LKR)'),
                  prefixText: 'Rs ',
                ),
                validator: (String? v) {
                  final int? n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 0) {
                    return _vTxt(
                      context,
                      en: 'Enter a valid price',
                      si: 'නිවැරදි මිලක් ඇතුල් කරන්න',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _vTxt(context, en: 'Offer end time', si: 'Offer අවසන් වේලාව'),
                ),
                subtitle: Text(
                  _endsAt == null
                      ? _vTxt(context, en: 'Not set', si: 'සකසා නැත')
                      : _endsAt!.toLocal().toString().substring(0, 16),
                ),
                trailing: const Icon(Icons.event_outlined),
                onTap: _saving ? null : _pickEndsAt,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _vTxt(context, en: 'Save offer', si: 'Offer සුරකින්න'),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                _vTxt(
                  context,
                  en: 'Offers go live on the customer app only after admin approval.',
                  si: 'Admin අනුමත කළ පසු පමණක් customer app එකේ පෙනේ.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
