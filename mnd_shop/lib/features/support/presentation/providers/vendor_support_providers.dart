import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/features/support/data/vendor_support_repository.dart';
import 'package:mnd_shop/features/support/domain/vendor_support_message.dart';

final StreamProvider<List<VendorSupportMessage>> vendorSupportMessagesProvider =
    StreamProvider<List<VendorSupportMessage>>((Ref ref) {
  ref.watch(shopAuthStateProvider);
  return ref.watch(vendorSupportRepositoryProvider).watchMessages();
});

final StreamProvider<int> vendorSupportUnreadCountProvider =
    StreamProvider<int>((Ref ref) {
  ref.watch(shopAuthStateProvider);
  return ref.watch(vendorSupportRepositoryProvider).watchUnreadCount();
});
