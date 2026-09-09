import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_cancellation.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

Future<void> showRequestRefundBottomSheet({
  required BuildContext pageContext,
  required CustomerOrderDetail detail,
}) async {
  await showModalBottomSheet<void>(
    context: pageContext,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return _RequestRefundSheet(
        pageContext: pageContext,
        sheetContext: sheetContext,
        detail: detail,
      );
    },
  );
}

class _RequestRefundSheet extends ConsumerStatefulWidget {
  const _RequestRefundSheet({
    required this.pageContext,
    required this.sheetContext,
    required this.detail,
  });

  final BuildContext pageContext;
  final BuildContext sheetContext;
  final CustomerOrderDetail detail;

  @override
  ConsumerState<_RequestRefundSheet> createState() => _RequestRefundSheetState();
}

class _RequestRefundSheetState extends ConsumerState<_RequestRefundSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(widget.pageContext);
    setState(() => _submitting = true);
    final RefundRequestResult result =
        await ref.read(customerOrdersRepositoryProvider).requestOrderRefund(
              orderId: widget.detail.id,
              reason: _reasonController.text,
            );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (widget.sheetContext.mounted) {
      Navigator.of(widget.sheetContext).pop();
    }

    if (!result.isSuccess) {
      showMndSnackBar(
        widget.pageContext,
        result.errorMessage ?? l10n.orderRefundRequestFailedFallback,
        variant: MndSnackBarVariant.error,
      );
      return;
    }

    switch (result.outcome!) {
      case RefundRequestOutcome.refunded:
        showMndSnackBar(
          widget.pageContext,
          l10n.orderRefundProcessedMessage,
          variant: MndSnackBarVariant.success,
        );
        break;
      case RefundRequestOutcome.pendingReview:
        showMndSnackBar(
          widget.pageContext,
          l10n.orderRefundPendingReviewMessage,
          variant: MndSnackBarVariant.success,
        );
        break;
      case RefundRequestOutcome.alreadyRefunded:
        showMndSnackBar(
          widget.pageContext,
          l10n.orderRefundAlreadyRefundedMessage,
          variant: MndSnackBarVariant.warning,
        );
        break;
      case RefundRequestOutcome.alreadyPending:
        showMndSnackBar(
          widget.pageContext,
          l10n.orderRefundAlreadyPendingMessage,
          variant: MndSnackBarVariant.warning,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: bottomInset + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.orderRefundRequestSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.orderRefundRequestSheetBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reasonController,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 240,
              decoration: InputDecoration(
                hintText: l10n.orderRefundRequestReasonHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(widget.sheetContext).pop(),
                    child: Text(l10n.orderRefundRequestCancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.orderRefundRequestSubmit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
