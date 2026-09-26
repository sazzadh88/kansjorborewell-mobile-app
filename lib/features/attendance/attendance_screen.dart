import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(attendanceTeamProvider);

    return FactoryShell(
      currentIndex: 0,
      title: 'Attendance',
      action: IconButton(
        tooltip: 'Refresh team',
        onPressed: () => ref.invalidate(attendanceTeamProvider),
        icon: const Icon(Icons.sync_rounded),
      ),
      child: SafeArea(
        top: false,
        child: team.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(
            message: apiErrorMessage(error),
            onRetry: () => ref.invalidate(attendanceTeamProvider),
          ),
          data: (members) => members.isEmpty
              ? const Center(
                  child: EmptyState(
                    title: 'No staff found',
                    message:
                        'Staff accounts will appear here once they are created.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final name =
                        member['name']?.toString() ?? 'Unnamed staff';
                    final mobile = member['mobile']?.toString() ?? '';
                    final role =
                        (member['role'] as Map?)?['name']?.toString() ?? '';
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push(
                          '/attendance/detail',
                          extra: (
                            userId: (member['id'] as num).toInt(),
                            name: name,
                            mobile: mobile,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.accentTint,
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.accentDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    role.isNotEmpty
                                        ? '$mobile · $role'
                                        : mobile,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
