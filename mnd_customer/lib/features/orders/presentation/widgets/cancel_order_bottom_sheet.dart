import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_cancellation.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

Future<void> showCancelOrderBottomSheet({
  required BuildContext pageContext,
  required CustomerOrderDetail detail,
}) async {
  await showModalBottomSheet<void>(
    context: pageContext,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return _CancelOrderSheet(
        pageContext: pageContext,
        sheetContext: sheetContext,
        detail: detail,
      );
    },
  );
}

class _CancelOrderSheet extends ConsumerStatefulWidget {
  const _CancelOrderSheet({
    required this.pageContext,
    required this.sheetContext,
    required this.detail,
  });

  final BuildContext pageContext;
  final BuildContext sheetContext;
  final CustomerOrderDetail detail;

  @override
  ConsumerState<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends ConsumerState<_CancelOrderSheet> {
  late String _selectedReasonId;
  final TextEditingController _otherDetailController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReasonId = OrderCancellationReason.customerOptions.first.id;
  }

  @override
  void dispose() {
    _otherDetailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String otherText = _otherDetailController.text.trim();
    if (_selectedReasonId == 'other' && otherText.isEmpty) {
      showMndSnackBar(widget.pageContext, 'Please describe your reason.', variant: MndSnackBarVariant.warning);
      return;
    }

    setState(() => _submitting = true);
    final OrderCancellationResult result =
        await ref.read(customerOrdersRepositoryProvider).cancelOrderByCustomer(
              orderId: widget.detail.id,
              reasonId: _selectedReasonId,
              otherDetail: _selectedReasonId == 'other' ? otherText : null,
            );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);

    if (result.isSuccess) {
      if (widget.sheetContext.mounted) {
        Navigator.of(widget.sheetContext).pop();
      }
      showMndSnackBar(widget.pageContext, 'Your order has been cancelled.', variant: MndSnackBarVariant.success);
      return;
    }

    showMndSnackBar(widget.pageContext, result.errorMessage ?? 'Could not cancel order.', variant: MndSnackBarVariant.error);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
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
              'Cancel order',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.detail.storeName,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Why are you cancelling?',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...OrderCancellationReason.customerOptions.map(
              (OrderCancellationReason r) {
                final bool selected = _selectedReasonId == r.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? scheme.primary : Colors.black45,
                  ),
                  title: Text(r.label),
                  onTap: _submitting
                      ? null
                      : () => setState(() => _selectedReasonId = r.id),
                );
              },
            ),
            if (_selectedReasonId == 'other') ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _otherDetailController,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 240,
                decoration: const InputDecoration(
                  hintText: 'Tell us more…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(widget.sheetContext).pop(),
                    child: const Text('Keep order'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cancel order'),
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
