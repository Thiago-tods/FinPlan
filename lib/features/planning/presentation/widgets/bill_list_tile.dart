import 'package:flutter/material.dart';

import '../../domain/entities/payable_bill.dart';

class BillListTile extends StatelessWidget {
  final PayableBill bill;
  final VoidCallback? onEdit;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const BillListTile({
    super.key,
    required this.bill,
    this.onEdit,
    this.onPay,
    this.onCancel,
    this.onDelete,
  });

  String _currency(double value) {
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    final parts = formatted.split(',');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'R\$ $integer,${parts[1]}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = switch (bill.status) {
      BillStatus.paid => Colors.green,
      BillStatus.cancelled => colors.onSurfaceVariant,
      BillStatus.pending when bill.isOverdue => colors.error,
      BillStatus.pending => colors.primary,
    };

    final statusLabel = bill.isOverdue
        ? 'Vencida'
        : bill.status.label;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    bill.status == BillStatus.paid
                        ? Icons.check_rounded
                        : bill.isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.receipt_long_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.description,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bill.category.label} • Vence em ${_formatDate(bill.dueDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currency(bill.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (bill.hasDiscount) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Desconto: ${_currency(bill.discountAmount!)} '
                  'até ${_formatDate(bill.discountDeadline!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (onPay != null)
                  TextButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Pagar'),
                  ),
                if (onCancel != null)
                  IconButton(
                    tooltip: 'Cancelar conta',
                    onPressed: onCancel,
                    icon: const Icon(Icons.block_outlined),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Excluir',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}