import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/app/providers/vendor_shell_tab_provider.dart';
import 'package:mnd_shop/core/notifications/shop_push_message.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

class ShopPushNotificationBootstrap extends ConsumerStatefulWidget {
  const ShopPushNotificationBootstrap({super.key});

  @override
  ConsumerState<ShopPushNotificationBootstrap> createState() =>
      _ShopPushNotificationBootstrapState();
}

class _ShopPushNotificationBootstrapState
    extends ConsumerState<ShopPushNotificationBootstrap> {
  String _initializedStoreId = '';

  @override
  Widget build(BuildContext context) {
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    if (storeId.isNotEmpty && storeId != _initializedStoreId) {
      _initializedStoreId = storeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(shopFirebaseMessagingServiceProvider).initialize(
              vendorId: storeId,
              onNotificationTap: _handleNotificationTap,
            );
      });
    }
    return const SizedBox.shrink();
  }

  void _handleNotificationTap(ShopPushMessage message) {
    switch (message.type) {
      case ShopPushType.newOrder:
      case ShopPushType.orderReminder:
      case ShopPushType.orderCancelled:
        ref.read(vendorShellTabIndexProvider.notifier).state = 2;
      case ShopPushType.approval:
        ref.read(vendorShellTabIndexProvider.notifier).state = 4;
      case ShopPushType.unknown:
        break;
    }
  }
}
