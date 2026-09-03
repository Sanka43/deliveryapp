import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_job_approvals_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_jobs_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_product_cash_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_riders_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_withdrawals_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/widgets/admin_dashboard_job_approvals_section.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int pendingCount =
        ref.watch(pendingJobsAdminProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Admin',
        implyLeading: false,
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Text(
                'Admin dashboard',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Approve listings, manage orders, and support the MND platform.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AdminDashboardJobApprovalsSection(),
              const SizedBox(height: AppSpacing.md),
              if (pendingCount > 0)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminJobApprovalsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: Text('Approve $pendingCount job${pendingCount == 1 ? '' : 's'} now'),
                ),
              if (pendingCount > 0) const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.customer),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Open customer app'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminOrdersPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Orders & rider assignment'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminProductCashPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Product cash (rider → shop)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminWithdrawalsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Rider withdrawals'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminRidersPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.delivery_dining_outlined),
                label: const Text('Approve riders'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminJobsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.work_outline_rounded),
                label: const Text('All jobs (active, expired, reports)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
