import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_settings_actions.dart';
import 'package:mnd_shop/features/support/data/vendor_support_repository.dart';
import 'package:mnd_shop/features/support/domain/vendor_support_message.dart';
import 'package:mnd_shop/features/support/presentation/providers/vendor_support_providers.dart';

/// One-on-one chat between the signed-in vendor and MND support, backed by
/// `vendor_support_threads/{uid}/messages`. Staff reply from the Firebase
/// console (no admin app yet) — see `functions/src/supportChat.ts`.
class VendorSupportChatPage extends ConsumerStatefulWidget {
  const VendorSupportChatPage({super.key});

  @override
  ConsumerState<VendorSupportChatPage> createState() => _VendorSupportChatPageState();
}

class _VendorSupportChatPageState extends ConsumerState<VendorSupportChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vendorSupportRepositoryProvider).markThreadRead();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    _controller.clear();
    final String? error = await ref.read(vendorSupportRepositoryProvider).sendMessage(text);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Support', si: 'සහාය')),
        actions: <Widget>[
          IconButton(
            tooltip: _vTxt(context, en: 'Call support', si: 'Call support'),
            icon: const Icon(Icons.call_outlined),
            onPressed: () => VendorSettingsActions.launchSupportPhone(context),
          ),
        ],
      ),
      body: _buildChat(context),
    );
  }

  Widget _buildChat(BuildContext context) {
    final AsyncValue<List<VendorSupportMessage>> async =
        ref.watch(vendorSupportMessagesProvider);

    return Column(
      children: <Widget>[
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (Object e, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userFacingError(e, fallback: 'Could not load messages. Please try again.'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (List<VendorSupportMessage> messages) {
              if (messages.length != _lastMessageCount) {
                _lastMessageCount = messages.length;
                _scrollToBottomSoon();
              }
              if (messages.isEmpty) {
                return _buildEmpty(context);
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int i) =>
                    _MessageBubble(message: messages[i]),
              );
            },
          ),
        ),
        _buildComposer(context),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.support_agent_rounded,
              size: 56,
              color: AppColors.vendorHeroBlue.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              _vTxt(context, en: 'How can we help?', si: 'අපිට උදව් කරන්න පුළුවන් කොහොමද?'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _vTxt(
                context,
                en:
                    'Send us a message about an order, payout, or your shop account and our team will reply here.',
                si:
                    'Order, payout, හෝ ඔබේ shop account එක ගැන message එකක් යවන්න, අපේ team එක මෙතන reply කරයි.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 8, 10 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _vTxt(context, en: 'Type a message…', si: 'Message එකක් type කරන්න…'),
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.vendorHeroBlue,
                disabledBackgroundColor: AppColors.vendorHeroBlue.withValues(alpha: 0.4),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final VendorSupportMessage message;

  static String _formatTime(DateTime? d) {
    if (d == null) {
      return '';
    }
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month} · ${d.hour}:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool fromVendor = message.sender == VendorSupportSender.vendor;

    return Align(
      alignment: fromVendor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Column(
          crossAxisAlignment: fromVendor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            if (!fromVendor)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  'Support',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fromVendor ? AppColors.vendorHeroBlue : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(fromVendor ? 14 : 4),
                  bottomRight: Radius.circular(fromVendor ? 4 : 14),
                ),
                border: fromVendor ? null : Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fromVendor ? Colors.white : AppColors.textCharcoal,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') {
    return si;
  }
  if (languageCode == 'ta') {
    return ta ?? vendorTamilFallback(en);
  }
  return en;
}
