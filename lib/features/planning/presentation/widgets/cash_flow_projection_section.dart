import 'package:flutter/material.dart';

import '../../../accounts/application/accounts_store.dart';
import '../../../transactions/application/transactions_store.dart';
import '../../application/planning_store.dart';
import '../../domain/entities/cash_flow_projection.dart';
import '../../domain/services/cash_flow_service.dart';

class CashFlowProjectionSection extends StatefulWidget {
  final AccountsStore accountsStore;
  final TransactionsStore transactionsStore;
  final PlanningStore planningStore;

  const CashFlowProjectionSection({
    super.key,
    required this.accountsStore,
    required this.transactionsStore,
    required this.planningStore,
  });

  @override
  State<CashFlowProjectionSection> createState() =>
      _CashFlowProjectionSectionState();
}

class _CashFlowProjectionSectionState extends State<CashFlowProjectionSection> {
  final CashFlowService _service = CashFlowService();

  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();

    widget.accountsStore.addListener(_refresh);
    widget.transactionsStore.addListener(_refresh);
    widget.planningStore.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.accountsStore.removeListener(_refresh);
    widget.transactionsStore.removeListener(_refresh);
    widget.planningStore.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double get _currentBalance {
    return widget.accountsStore.accounts.fold(0.0, (total, account) {
      return total +
          widget.transactionsStore.balanceForAccount(
            accountId: account.id,
            initialBalance: account.initialBalance,
          );
    });
  }

  CashFlowProjection get _projection {
    return _service.project(
      currentBalance: _currentBalance,
      transactions: widget.transactionsStore.transactions,
      bills: widget.planningStore.bills,
      days: _selectedDays,
    );
  }

  String _currency(double value) {
    final formatted = value.abs().toStringAsFixed(2).replaceAll('.', ',');
    final parts = formatted.split(',');

    final integer = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    final prefix = value < 0 ? '-R\$ ' : 'R\$ ';

    return '$prefix$integer,${parts[1]}';
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projection = _projection;

    final isNegative = projection.hasNegativeBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projeção de fluxo de caixa',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Antecipe seu saldo e identifique possíveis riscos financeiros.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 dias')),
            ButtonSegment(value: 15, label: Text('15 dias')),
            ButtonSegment(value: 30, label: Text('30 dias')),
          ],
          selected: {_selectedDays},
          onSelectionChanged: (selection) {
            setState(() {
              _selectedDays = selection.first;
            });
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo projetado', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  _currency(projection.projectedBalance),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: projection.projectedBalance < 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Saldo estimado ao final dos $_selectedDays dias',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricItem(
                        label: 'Receitas previstas',
                        value: _currency(projection.totalIncome),
                        color: Colors.green,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricItem(
                        label: 'Despesas previstas',
                        value: _currency(projection.totalExpenses),
                        color: theme.colorScheme.error,
                        icon: Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: theme.dividerColor),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menor saldo previsto',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      _currency(projection.lowestBalance),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: projection.lowestBalance < 0
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isNegative) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risco de saldo negativo',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A projeção identifica ${projection.negativeDaysCount} '
                          'dia(s) com saldo negativo. Revise seus compromissos '
                          'e receitas previstas.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Evolução do saldo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _CashFlowChartPainter(
                      days: projection.days,
                      initialBalance: projection.initialBalance,
                      lineColor: theme.colorScheme.primary,
                      negativeColor: theme.colorScheme.error,
                      gridColor: theme.dividerColor,
                      textColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hoje', style: theme.textTheme.bodySmall),
                    Text(
                      _date(projection.days.last.date),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _ChartLegend(
                      color: theme.colorScheme.primary,
                      label: 'Saldo positivo',
                    ),
                    _ChartLegend(
                      color: theme.colorScheme.error,
                      label: 'Saldo negativo',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Movimentações previstas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...projection.days
            .where((day) => day.income > 0 || day.expenses > 0)
            .map(
              (day) => _DailyProjectionTile(
                day: day,
                currency: _currency,
                date: _date,
              ),
            ),
        if (projection.days.every(
          (day) => day.income == 0 && day.expenses == 0,
        ))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Nenhuma movimentação prevista neste período.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DailyProjectionTile extends StatelessWidget {
  final CashFlowDay day;
  final String Function(double) currency;
  final String Function(DateTime) date;

  const _DailyProjectionTile({
    required this.day,
    required this.currency,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date(day.date),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Saldo: ${currency(day.closingBalance)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: day.isNegative ? theme.colorScheme.error : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (day.income > 0)
              _DailyAmount(
                label: 'Receitas',
                value: currency(day.income),
                color: Colors.green,
              ),
            if (day.expenses > 0)
              _DailyAmount(
                label: 'Despesas',
                value: currency(day.expenses),
                color: theme.colorScheme.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyAmount extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DailyAmount({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CashFlowChartPainter extends CustomPainter {
  final List<CashFlowDay> days;
  final double initialBalance;
  final Color lineColor;
  final Color negativeColor;
  final Color gridColor;
  final Color textColor;

  _CashFlowChartPainter({
    required this.days,
    required this.initialBalance,
    required this.lineColor,
    required this.negativeColor,
    required this.gridColor,
    required this.textColor,
  });

  String _axisCurrency(double value) {
    final absoluteValue = value.abs();

    String formatted;

    if (absoluteValue >= 1000000) {
      formatted = '${(absoluteValue / 1000000).toStringAsFixed(1)} mi';
    } else if (absoluteValue >= 1000) {
      formatted = '${(absoluteValue / 1000).toStringAsFixed(1)} mil';
    } else {
      formatted = absoluteValue.toStringAsFixed(0);
    }

    final prefix = value < 0 ? '-R\$ ' : 'R\$ ';

    return '$prefix$formatted';
  }

  void _drawLabel(Canvas canvas, String value, Offset position) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    painter.layout();

    painter.paint(
      canvas,
      Offset(position.dx - painter.width, position.dy - painter.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.width <= 80 || size.height <= 30) {
      return;
    }

    const leftPadding = 70.0;
    const rightPadding = 10.0;
    const topPadding = 14.0;
    const bottomPadding = 12.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final balances = [initialBalance, ...days.map((day) => day.closingBalance)];

    var minBalance = balances.reduce((a, b) => a < b ? a : b);
    var maxBalance = balances.reduce((a, b) => a > b ? a : b);

    if (minBalance == maxBalance) {
      minBalance -= 100;
      maxBalance += 100;
    }

    final range = maxBalance - minBalance;

    minBalance -= range * 0.12;
    maxBalance += range * 0.12;

    final adjustedRange = maxBalance - minBalance;

    double xPosition(int index) {
      if (balances.length == 1) {
        return leftPadding + chartWidth / 2;
      }

      return leftPadding + chartWidth * index / (balances.length - 1);
    }

    double yPosition(double value) {
      return topPadding + chartHeight * (maxBalance - value) / adjustedRange;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index++) {
      final fraction = index / 4;
      final y = topPadding + chartHeight * fraction;
      final value = maxBalance - adjustedRange * fraction;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      _drawLabel(canvas, _axisCurrency(value), Offset(leftPadding - 8, y));
    }

    if (minBalance < 0 && maxBalance > 0) {
      final zeroY = yPosition(0);

      final zeroPaint = Paint()
        ..color = negativeColor.withValues(alpha: 0.65)
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(leftPadding, zeroY),
        Offset(size.width - rightPadding, zeroY),
        zeroPaint,
      );
    }

    final path = Path();

    for (var index = 0; index < balances.length; index++) {
      final point = Offset(xPosition(index), yPosition(balances[index]));

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (var index = 0; index < balances.length; index++) {
      final isNegative = balances[index] < 0;

      dotPaint.color = isNegative ? negativeColor : lineColor;

      canvas.drawCircle(
        Offset(xPosition(index), yPosition(balances[index])),
        balances.length > 20 ? 2.5 : 4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CashFlowChartPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.initialBalance != initialBalance ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}
