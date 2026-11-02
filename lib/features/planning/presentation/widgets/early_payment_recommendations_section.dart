
import 'package:flutter/material.dart';

import '../../domain/entities/early_payment_recommendation.dart';

class EarlyPaymentRecommendationsSection extends StatelessWidget {
  final List<EarlyPaymentRecommendation> recommendations;
  final ValueChanged<String> onPayBill;

  const EarlyPaymentRecommendationsSection({
    super.key,
    required this.recommendations,
    required this.onPayBill,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.savings_outlined,
              color: colors.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Oportunidades de economia',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Contas que podem ser pagas antecipadamente sem comprometer '
          'sua reserva de segurança.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (recommendations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 30,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nenhuma oportunidade encontrada',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quando houver descontos vantajosos que '
                          'preservem sua reserva, eles aparecerão aqui.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recommendations.map(
            (recommendation) => _RecommendationCard(
              recommendation: recommendation,
              onPay: () => onPayBill(recommendation.billId),
              currency: _currency,
              formatDate: _formatDate,
            ),
          ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final EarlyPaymentRecommendation recommendation;
  final VoidCallback onPay;
  final String Function(double) currency;
  final String Function(DateTime) formatDate;

  const _RecommendationCard({
    required this.recommendation,
    required this.onPay,
    required this.currency,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.trending_down_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.billDescription,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Desconto disponível até '
                        '${formatDate(recommendation.discountDeadline)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency(recommendation.savings),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'de economia',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _ValueRow(
                    label: 'Valor original',
                    value: currency(recommendation.originalAmount),
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  _ValueRow(
                    label: 'Desconto',
                    value: '- ${currency(recommendation.discountAmount)}',
                    color: Colors.green,
                  ),
                  const Divider(height: 20),
                  _ValueRow(
                    label: 'Valor para pagamento',
                    value: currency(recommendation.paymentAmount),
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Impacto no seu saldo projetado',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _ValueRow(
              label: 'Saldo antes do pagamento',
              value: currency(
                recommendation.projectedBalanceBeforePayment,
              ),
            ),
            const SizedBox(height: 6),
            _ValueRow(
              label: 'Saldo após o pagamento',
              value: currency(
                recommendation.projectedBalanceAfterPayment,
              ),
              bold: true,
            ),
            const SizedBox(height: 6),
            _ValueRow(
              label: 'Reserva mínima preservada',
              value: currency(recommendation.minimumReserve),
              color: colors.primary,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pagamento compatível com sua reserva de segurança.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Aproveitar desconto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _ValueRow({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
