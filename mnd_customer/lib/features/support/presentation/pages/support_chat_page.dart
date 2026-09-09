import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/features/support/data/support_repository.dart';
import 'package:mnd_delivery_app/features/support/domain/entities/support_message.dart';

/// One-on-one chat between the signed-in customer and MND support, backed by
/// `support_threads/{uid}/messages`. Staff currently reply from the Firebase
/// console (no admin app yet) — see `functions/src/supportChat.ts`.
class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportRepositoryProvider).markThreadRead();
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
    final String? error =
        await ref.read(supportRepositoryProvider).sendMessage(text);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (error != null) {
      showMndSnackBar(context, error, variant: MndSnackBarVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool signedIn = ref.watch(authStateUserProvider).valueOrNull != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'Support'),
      body: signedIn ? _buildChat(context) : _buildSignedOut(),
    );
  }

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SignInRequiredBanner(
          message: 'Sign in to chat with our support team.',
          redirectTo: AppRoutes.customerSupport,
        ),
      ),
    );
  }

  Widget _buildChat(BuildContext context) {
    final AsyncValue<List<SupportMessage>> async =
        ref.watch(supportMessagesProvider);

    return Column(
      children: <Widget>[
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (Object e, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  userFacingError(
                    e,
                    fallback: 'Could not load messages. Please try again.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (List<SupportMessage> messages) {
              if (messages.length != _lastMessageCount) {
                _lastMessageCount = messages.length;
                _scrollToBottomSoon();
              }
              if (messages.isEmpty) {
                return _buildEmpty(context);
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
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
              color: AppColors.brandPrimary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'How can we help?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send us a message about an order, ride, or your account and '
              'our team will get back to you here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
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
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm + bottomInset,
        ),
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
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: AppColors.homeMutedFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                disabledBackgroundColor:
                    AppColors.brandPrimary.withValues(alpha: 0.4),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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

  final SupportMessage message;

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
    final bool fromCustomer = message.sender == SupportSender.customer;

    return Align(
      alignment: fromCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              fromCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            if (!fromCustomer)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  'Support',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: fromCustomer
                    ? AppColors.brandPrimary
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppColors.cardRadiusMd),
                  topRight: const Radius.circular(AppColors.cardRadiusMd),
                  bottomLeft: Radius.circular(fromCustomer ? AppColors.cardRadiusMd : 4),
                  bottomRight: Radius.circular(fromCustomer ? 4 : AppColors.cardRadiusMd),
                ),
                border: fromCustomer
                    ? null
                    : Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fromCustomer ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
