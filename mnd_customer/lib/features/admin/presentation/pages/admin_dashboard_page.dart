import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_job_approvals_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_jobs_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_riders_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/widgets/admin_dashboard_job_approvals_section.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int pendingCount =
        ref.watch(pendingJobsAdminProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                'Admin dashboard',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Approve listings, manage orders, and support the MND platform.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const AdminDashboardJobApprovalsSection(),
              const SizedBox(height: 20),
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
              if (pendingCount > 0) const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.customer),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Open customer app'),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
