import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

const _statusLabels = {
  'A': 'Absent',
  'P': 'Present',
  'HD': 'Half day',
  'P_HD': 'Present + half (1.5)',
  'PP': 'Double present',
  'OT': 'Overtime',
  'PA': 'Paid leave',
};

String _shiftMonth(String month, int delta) {
  final parts = month.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta, 1);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String _money(double value) =>
    '₹ ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

/// Shows the friendly API message, plus the raw error in debug builds so
/// share/print failures report their real cause instead of a generic line.
String _errorText(Object e) {
  final friendly = apiErrorMessage(e);
  if (kDebugMode && '$e'.isNotEmpty && '$e' != friendly) {
    return '$friendly\n$e';
  }
  return friendly;
}

class AttendanceDetailScreen extends ConsumerStatefulWidget {
  const AttendanceDetailScreen({
    required this.userId,
    required this.name,
    required this.mobile,
    super.key,
  });

  final int userId;
  final String name;
  final String mobile;

  @override
  ConsumerState<AttendanceDetailScreen> createState() =>
      _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState
    extends ConsumerState<AttendanceDetailScreen> {
  late String _month;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  bool get _canManage =>
      ref.watch(authProvider).value?.hasPermission('attendance.manage') ??
      false;

  void _reload() =>
      ref.invalidate(attendanceMonthProvider((userId: widget.userId, month: _month)));

  Future<void> _openMarkDialog(AttendanceDay day) async {
    final bool extended = day.status != null &&
        day.status != 'A' &&
        day.status != 'P';
    String status = extended ? 'P' : (day.status ?? 'P');
    final advanceCtrl = TextEditingController(
      text: day.advanceAmount > 0 ? '${day.advanceAmount}' : '',
    );
    String mode = day.advanceMode ?? 'cash';
    final noteCtrl = TextEditingController(text: day.note ?? '');
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Mark · ${day.date}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (extended)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Marked ${day.status} earlier — saving here keeps that status; only advance and note change.',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _StatusButton(
                          label: 'P · Present',
                          selected: status == 'P',
                          onTap: () =>
                              setDialogState(() => status = 'P'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatusButton(
                          label: 'A · Absent',
                          selected: status == 'A',
                          absent: true,
                          onTap: () =>
                              setDialogState(() => status = 'A'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: advanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Advance (₹)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: mode,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Mode'),
                        items: const [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('Cash'),
                          ),
                          DropdownMenuItem(
                            value: 'online',
                            child: Text('Online'),
                          ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => mode = val ?? 'cash'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      final payload = <String, dynamic>{
                        'user_id': widget.userId,
                        'date': day.date,
                        'status': extended ? day.status : status,
                        if (extended) ...{
                          'ot_hours': day.otHours,
                          'ot_minutes': day.otMinutes,
                          'ot_rate': day.otRate,
                        },
                        'advance_amount':
                            double.tryParse(advanceCtrl.text.trim()) ?? 0,
                        'advance_mode': mode,
                        'note': noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      };
                      try {
                        await ref
                            .read(apiClientProvider)
                            .upsertAttendance(payload);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx, true);
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(_errorText(e)),
                            ),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved.')),
        );
      }
    }
  }

  Future<void> _clearDay(AttendanceDay day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear day?'),
        content: Text('Remove the attendance entry for ${day.date}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).upsertAttendance({
        'user_id': widget.userId,
        'date': day.date,
      });
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day cleared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  Future<void> _shareCurrentSheet() async {
    try {
      final sheet = await ref.read(
        attendanceMonthProvider((userId: widget.userId, month: _month)).future,
      );
      await _sharePdf(sheet);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  Future<void> _printCurrentSheet() async {
    try {
      final sheet = await ref.read(
        attendanceMonthProvider((userId: widget.userId, month: _month)).future,
      );
      await _printPdf(sheet);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  Future<void> _sharePdf(MonthlyAttendance sheet) async {
    setState(() => _sharing = true);
    try {
      final pdf = _buildPdf(sheet);
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/attendance-${sheet.userName.replaceAll(' ', '_')}-${sheet.month}.pdf',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Attendance ${sheet.monthLabel} · ${sheet.userName}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _printPdf(MonthlyAttendance sheet) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) => _buildPdf(sheet).save(),
        name: 'attendance-${sheet.month}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  pw.Document _buildPdf(MonthlyAttendance sheet) {
    final pdf = pw.Document();
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Attendance · ${sheet.userName} · ${sheet.monthLabel}',
            style: headerStyle,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Present ${sheet.overview.totalPresent} · Absent ${sheet.overview.totalAbsent} · Advance ${_money(sheet.overview.totalAdvance)} · Balance ${_money(sheet.overview.balanceAmount)}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Status', 'Advance', 'Note'],
            data: sheet.days
                .map((d) => [
                      d.date,
                      d.status ?? '—',
                      d.advanceAmount > 0
                          ? _money(d.advanceAmount)
                          : '—',
                      (d.note ?? '').isEmpty ? '—' : d.note!,
                    ])
                .toList(),
          ),
        ],
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    final sheet = ref.watch(
      attendanceMonthProvider((userId: widget.userId, month: _month)),
    );
    final hasSheet = sheet.hasValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            onPressed:
                (_sharing || !hasSheet) ? null : _shareCurrentSheet,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Print report',
            icon: const Icon(Icons.print_outlined),
            onPressed: hasSheet ? _printCurrentSheet : null,
          ),
          IconButton(
            tooltip: 'Refresh sheet',
            onPressed: _reload,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: sheet.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(
            message: apiErrorMessage(error),
            onRetry: _reload,
          ),
          data: (data) {
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () async {
                _reload();
                await ref.read(
                  attendanceMonthProvider(
                    (userId: widget.userId, month: _month),
                  ).future,
                );
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.monthLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.mobile,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => setState(
                            () => _month = _shiftMonth(_month, -1),
                          ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: () => setState(
                            () => _month = _shiftMonth(_month, 1),
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatChip(
                        label: 'Present',
                        value: '${data.overview.totalPresent}',
                        icon: Icons.check_circle_outline,
                      ),
                      _StatChip(
                        label: 'Absent',
                        value: '${data.overview.totalAbsent}',
                        icon: Icons.cancel_outlined,
                        warning: true,
                      ),
                      _StatChip(
                        label: 'Advance',
                        value: _money(data.overview.totalAdvance),
                        icon: Icons.account_balance_wallet_outlined,
                        warning: true,
                      ),
                      _StatChip(
                        label: 'Balance',
                        value: _money(data.overview.balanceAmount),
                        icon: Icons.savings_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionHeading(title: 'Daily sheet'),
                  const SizedBox(height: 10),
                  ...data.days.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.day,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    d.weekday,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (d.status != null)
                                    StatusBadge(
                                      label:
                                          '${d.status} · ${_statusLabels[d.status] ?? ''}',
                                      warning: d.status == 'A' ||
                                          d.status == 'HD',
                                    )
                                  else
                                    const Text(
                                      'Not marked',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (d.advanceAmount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        'Advance ${_money(d.advanceAmount)}${d.advanceMode != null ? ' · ${d.advanceMode}' : ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  if ((d.note ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        d.note!,
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_canManage) ...[
                              IconButton(
                                tooltip: 'Mark day',
                                onPressed: () => _openMarkDialog(
                                  d,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                              if (d.hasEntry)
                                IconButton(
                                  tooltip: 'Clear day',
                                  onPressed: () => _clearDay(
                                    d,
                                  ),
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 19,
                                    color: AppColors.danger,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 42) / 2,
        child: AppCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: warning
                      ? AppColors.warningTint
                      : AppColors.accentTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: warning ? AppColors.warning : AppColors.accentDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
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

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.absent = false,
  });

  final String label;
  final bool selected;
  final bool absent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color selectedBg =
        absent ? AppColors.danger : AppColors.accent;
    return SizedBox(
      height: 52,
      child: selected
          ? FilledButton(
              style: FilledButton.styleFrom(backgroundColor: selectedBg),
              onPressed: onTap,
              child: Text(label),
            )
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
