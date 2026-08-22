import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchListState();
}

class _DispatchListState extends ConsumerState<DispatchScreen> {
  DateTimeRange? _range;
  int _page = 1;

  bool get _canCreate =>
      ref.read(authProvider).value?.hasPermission('dispatch.create') ?? false;
  bool get _canEdit =>
      ref.read(authProvider).value?.hasPermission('dispatch.edit') ?? false;
  bool get _canDelete =>
      ref.read(authProvider).value?.hasPermission('dispatch.delete') ?? false;
  bool get _canExport =>
      ref.read(authProvider).value?.hasPermission('dispatch.export') ?? false;

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
  ({String? from, String? to, int page}) get query => (
    from: _range == null ? null : _date(_range!.start),
    to: _range == null ? null : _date(_range!.end),
    page: _page,
  );
  String get rangeLabel => _range == null
      ? 'All records'
      : '${_date(_range!.start)} → ${_date(_range!.end)}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Select up to 30 days',
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays > 29) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a range of 30 days or less.')),
        );
      }
      return;
    }
    setState(() {
      _range = picked;
      _page = 1;
    });
  }

  Future<void> _export() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Select export range, up to 30 days',
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays > 29) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose an export range of 30 days or less.'),
          ),
        );
      }
      return;
    }
    final from = _date(picked.start);
    final to = _date(picked.end);
    try {
      final csv = await ref
          .read(apiClientProvider)
          .exportCsv('dispatches', from: from, to: to);
      final path = await ref
          .read(apiClientProvider)
          .saveCsvToDownloads('dispatch-$from-$to.csv', csv);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV saved to $path')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  Future<void> _delete(DispatchRecord item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete dispatch?'),
        content: Text(
          '${item.product} · ${item.quantity} pcs will be removed and stock will be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteDispatch(item.id);
      ref.invalidate(dispatchRecordsProvider(query));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dispatch deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  Widget _recordTile(DispatchRecord item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF315A99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.party} · ${item.vehicle}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.date}${item.driver == null ? '' : ' · ${item.driver}'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.isPaid ? 'Paid' : 'Due'} · ₹${item.paidAmount} / ₹${item.freightAmount ?? 0}',
                  style: TextStyle(
                    color: item.isPaid ? AppColors.success : AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text(
                'pcs',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          if (_canEdit || _canDelete)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') context.push('/dispatch/new', extra: item);
                if (value == 'delete') _delete(item);
              },
              itemBuilder: (_) => [
                if (_canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (_canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(dispatchRecordsProvider(query));
    return FactoryShell(
      currentIndex: 2,
      title: 'Dispatch',
      action: Row(
        children: [
          IconButton(
            tooltip: 'Filter range',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          if (_canExport)
            IconButton(
              tooltip: 'Export CSV',
              onPressed: _export,
              icon: const Icon(Icons.file_download_outlined),
            ),
          if (_canCreate)
            IconButton(
              onPressed: () async {
                await context.push('/dispatch/new');
                if (!mounted) return;
                ref.invalidate(dispatchRecordsProvider(query));
                await ref.read(dispatchRecordsProvider(query).future);
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dispatchRecordsProvider(query));
            await ref.read(dispatchRecordsProvider(query).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Dispatch register',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                'Newest 20 records by default.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              records.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => ErrorState(
                  message: apiErrorMessage(error),
                  onRetry: () => ref.invalidate(dispatchRecordsProvider(query)),
                ),
                data: (result) => Column(
                  children: [
                    if (result.items.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          title: 'No dispatch entries',
                          message: 'Use the plus button to create a load.',
                        ),
                      )
                    else
                      ...result.items.map(_recordTile),
                    if (result.lastPage > 1)
                      _PaginationBar(
                        currentPage: result.currentPage,
                        lastPage: result.lastPage,
                        onPrevious: result.currentPage > 1
                            ? () => setState(() => _page--)
                            : null,
                        onNext: result.currentPage < result.lastPage
                            ? () => setState(() => _page++)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.lastPage,
    required this.onPrevious,
    required this.onNext,
  });
  final int currentPage;
  final int lastPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Text(
          'Page $currentPage of $lastPage',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}
