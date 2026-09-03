import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/create_order/data/vendor_manual_order_repository.dart';

class CreateOrderDraft {
  const CreateOrderDraft({
    this.step = 0,
    this.phoneInput = '',
    this.phoneE164 = '',
    this.customerName = '',
    this.lookupDone = false,
    this.isGuest = true,
    this.foundCustomerId,
    this.packagePriceInput = '',
    this.packageDescription = '',
    this.line1 = '',
    this.line2 = '',
    this.city = '',
    this.addressPhone = '',
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.deliveryNote = '',
    this.productsPaid = false,
    this.submitting = false,
    this.errorMessage,
  });

  final int step;
  final String phoneInput;
  final String phoneE164;
  final String customerName;
  final bool lookupDone;
  final bool isGuest;
  final String? foundCustomerId;

  /// Raw text the vendor typed for the package price (Rs.).
  final String packagePriceInput;
  final String packageDescription;

  final String line1;
  final String line2;
  final String city;
  final String addressPhone;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String deliveryNote;
  /// Customer already paid the shop for the package (rider collects delivery only).
  final bool productsPaid;
  final bool submitting;
  final String? errorMessage;

  int get packagePriceLkr {
    final double? parsed = double.tryParse(packagePriceInput.trim());
    if (parsed == null || parsed <= 0) {
      return 0;
    }
    return parsed.round();
  }

  bool get hasDropoff =>
      dropoffLatitude != null && dropoffLongitude != null;

  CreateOrderDraft copyWith({
    int? step,
    String? phoneInput,
    String? phoneE164,
    String? customerName,
    bool? lookupDone,
    bool? isGuest,
    String? foundCustomerId,
    bool clearFoundCustomerId = false,
    String? packagePriceInput,
    String? packageDescription,
    String? line1,
    String? line2,
    String? city,
    String? addressPhone,
    double? dropoffLatitude,
    double? dropoffLongitude,
    bool clearDropoff = false,
    String? deliveryNote,
    bool? productsPaid,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateOrderDraft(
      step: step ?? this.step,
      phoneInput: phoneInput ?? this.phoneInput,
      phoneE164: phoneE164 ?? this.phoneE164,
      customerName: customerName ?? this.customerName,
      lookupDone: lookupDone ?? this.lookupDone,
      isGuest: isGuest ?? this.isGuest,
      foundCustomerId: clearFoundCustomerId
          ? null
          : (foundCustomerId ?? this.foundCustomerId),
      packagePriceInput: packagePriceInput ?? this.packagePriceInput,
      packageDescription: packageDescription ?? this.packageDescription,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      addressPhone: addressPhone ?? this.addressPhone,
      dropoffLatitude:
          clearDropoff ? null : (dropoffLatitude ?? this.dropoffLatitude),
      dropoffLongitude:
          clearDropoff ? null : (dropoffLongitude ?? this.dropoffLongitude),
      deliveryNote: deliveryNote ?? this.deliveryNote,
      productsPaid: productsPaid ?? this.productsPaid,
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final AutoDisposeNotifierProvider<CreateOrderDraftNotifier, CreateOrderDraft>
    createOrderDraftProvider =
    AutoDisposeNotifierProvider<CreateOrderDraftNotifier, CreateOrderDraft>(
  CreateOrderDraftNotifier.new,
);

class CreateOrderDraftNotifier extends AutoDisposeNotifier<CreateOrderDraft> {
  @override
  CreateOrderDraft build() => const CreateOrderDraft();

  void setPhoneInput(String value) {
    state = state.copyWith(
      phoneInput: value,
      lookupDone: false,
      clearError: true,
    );
  }

  void setCustomerName(String value) {
    state = state.copyWith(customerName: value, clearError: true);
  }

  void setPackagePriceInput(String value) {
    state = state.copyWith(packagePriceInput: value, clearError: true);
  }

  void setPackageDescription(String value) {
    state = state.copyWith(packageDescription: value, clearError: true);
  }

  void setAddress({
    String? line1,
    String? line2,
    String? city,
    String? addressPhone,
    String? deliveryNote,
  }) {
    state = state.copyWith(
      line1: line1,
      line2: line2,
      city: city,
      addressPhone: addressPhone,
      deliveryNote: deliveryNote,
      clearError: true,
    );
  }

  void setDropoff({
    required double latitude,
    required double longitude,
    String? suggestedLine1,
    String? suggestedCity,
  }) {
    state = state.copyWith(
      dropoffLatitude: latitude,
      dropoffLongitude: longitude,
      line1: (suggestedLine1 != null &&
              suggestedLine1.trim().isNotEmpty &&
              state.line1.trim().isEmpty)
          ? suggestedLine1.trim()
          : null,
      city: (suggestedCity != null &&
              suggestedCity.trim().isNotEmpty &&
              state.city.trim().isEmpty)
          ? suggestedCity.trim()
          : null,
      clearError: true,
    );
  }

  void setProductsPaid(bool value) {
    state = state.copyWith(productsPaid: value, clearError: true);
  }

  void goToStep(int step) {
    state = state.copyWith(step: step.clamp(0, 3), clearError: true);
  }

  Future<bool> lookupCustomer() async {
    final String phone = state.phoneInput.trim();
    if (phone.length < 8) {
      state = state.copyWith(errorMessage: 'Enter a valid phone number.');
      return false;
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final VendorCustomerLookupResult result =
          await ref.read(vendorManualOrderRepositoryProvider).lookupCustomer(phone);
      state = state.copyWith(
        submitting: false,
        lookupDone: true,
        isGuest: result.isGuest,
        foundCustomerId: result.customerId,
        clearFoundCustomerId: result.customerId == null,
        phoneE164: result.phoneE164,
        // Found accounts: always the account's own name (not editable in the
        // UI). Guest: keep whatever the vendor already typed, if anything.
        customerName: result.isGuest
            ? state.customerName
            : (result.displayName?.isNotEmpty == true
                ? result.displayName!
                : state.customerName),
        line1: result.suggestedLine1.isNotEmpty
            ? result.suggestedLine1
            : state.line1,
        line2: result.suggestedLine2.isNotEmpty
            ? result.suggestedLine2
            : state.line2,
        city: state.city.trim().isEmpty && result.suggestedCity.isNotEmpty
            ? result.suggestedCity
            : state.city,
        addressPhone: result.suggestedPhone.isNotEmpty
            ? result.suggestedPhone
            : result.phoneE164,
      );
      return true;
    } on VendorManualOrderException catch (e) {
      state = state.copyWith(
        submitting: false,
        errorMessage: userFacingError(
          e,
          fallback: 'Could not look up customer. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<VendorManualOrderResult?> submit() async {
    if (state.packagePriceLkr <= 0) {
      state = state.copyWith(errorMessage: 'Enter the package price.');
      return null;
    }
    if (state.line1.trim().isEmpty || state.city.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Delivery address is required.');
      return null;
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final VendorManualOrderResult result =
          await ref.read(vendorManualOrderRepositoryProvider).placeOrder(
                customerPhone: state.phoneE164.isNotEmpty
                    ? state.phoneE164
                    : state.phoneInput,
                customerName: state.customerName,
                packagePriceLkr: state.packagePriceLkr,
                packageDescription: state.packageDescription,
                line1: state.line1,
                line2: state.line2,
                city: state.city,
                addressPhone: state.addressPhone.isNotEmpty
                    ? state.addressPhone
                    : state.phoneE164,
                dropoffLatitude: state.dropoffLatitude,
                dropoffLongitude: state.dropoffLongitude,
                deliveryNote: state.deliveryNote,
                productsPaid: state.productsPaid,
              );
      state = state.copyWith(submitting: false);
      return result;
    } on VendorManualOrderException catch (e) {
      state = state.copyWith(
        submitting: false,
        errorMessage: userFacingError(
          e,
          fallback: 'Could not create order. Please try again.',
        ),
      );
      return null;
    }
  }
}
