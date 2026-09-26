import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/core.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DispatchDuesScreen extends ConsumerWidget {
  const DispatchDuesScreen({super.key});

  String _money(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dues = ref.watch(dispatchDuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch dues'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dispatchDuesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dispatchDuesProvider);
          await ref.read(dispatchDuesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Paid vs due',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Total freight, paid, and final due across all dispatches. Receipts clear the oldest dues first.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            dues.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => ErrorState(
                message: 'Dues summary unavailable.',
                onRetry: () => ref.invalidate(dispatchDuesProvider),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TotalCard(data: data),
                  const SizedBox(height: 18),
                  const SectionHeading(title: 'Party-wise dues'),
                  const SizedBox(height: 12),
                  if (data.parties.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        title: 'No dues',
                        message:
                            'Dispatch loads will appear here with their payment status.',
                      ),
                    )
                  else
                    ...data.parties.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.party,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${row.dispatches} loads',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (row.openingDue > 0)
                                _row(
                                  'Opening due',
                                  '₹ ${_money(row.openingDue)}',
                                ),
                              _row('Freight', '₹ ${_money(row.freightAmount)}'),
                              _row('Paid', '₹ ${_money(row.paidAmount)}'),
                              const Divider(height: 20),
                              _row(
                                'Due',
                                '₹ ${_money(row.dueAmount)}',
                                bold: true,
                                due: row.dueAmount > 0,
                              ),
                              const SizedBox(height: 12),
                              _ReceiveButton(row: row),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool due = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: due ? AppColors.warning : null,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    ),
  );
}

class _ReceiveButton extends ConsumerWidget {
  const _ReceiveButton({required this.row});

  final DispatchDueRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReceive =
        ref.watch(authProvider).value?.hasPermission('dispatch.edit') ??
        false;
    if (!canReceive) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ReceiveSheet(row: row),
        ),
        icon: const Icon(Icons.payments_outlined, size: 18),
        label: const Text('Receive payment'),
      ),
    );
  }
}

class _ReceiveSheet extends ConsumerStatefulWidget {
  const _ReceiveSheet({required this.row});

  final DispatchDueRow row;

  @override
  ConsumerState<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends ConsumerState<_ReceiveSheet> {
  final _amountController = TextEditingController();
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  String? _mode = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }
    if (amount - widget.row.dueAmount > 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ₹${widget.row.dueAmount.toStringAsFixed(2)} is outstanding for ${widget.row.party}.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .recordDuePayment(
            partyId: widget.row.partyId,
            amount: amount,
            date: _dateController.text.trim(),
            mode: _mode,
          );
      ref.invalidate(dispatchDuesProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Receive · ${widget.row.party}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Due ₹${widget.row.dueAmount.toStringAsFixed(2)} · clears oldest dues first',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            prefixIcon: Icon(Icons.currency_rupee_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dateController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              _dateController.text = picked.toIso8601String().substring(0, 10);
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Mode'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'online', child: Text('Online')),
          ],
          onChanged: (value) => setState(() => _mode = value),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving…' : 'Record payment'),
        ),
      ],
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.data});

  final DispatchDues data;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.ink,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FINAL DISPATCH DUES',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total freight',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '₹ ${data.freightAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Paid', style: TextStyle(color: Colors.white70)),
            Text(
              '₹ ${data.paidAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Final due',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '₹ ${data.dueAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
