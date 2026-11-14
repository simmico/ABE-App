import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/wallet_ledger_models.dart';
import '../../domain/services/wallet_and_ledger_service.dart';

/// Nail Technician Earnings, Payouts, Instant Cash-Out, and Stock-Up Credit screen.
class TechEarningsScreen extends StatefulWidget {
  const TechEarningsScreen({
    super.key,
    required this.techId,
    required this.walletService,
    this.onBack,
  });

  final String techId;
  final WalletAndLedgerService walletService;
  final VoidCallback? onBack;

  @override
  State<TechEarningsScreen> createState() => _TechEarningsScreenState();
}

class _TechEarningsScreenState extends State<TechEarningsScreen> {
  String? _statusMessage;
  bool _isError = false;
  int _cashOutCounter = 0;

  void _triggerInstantCashOut(TechEarningsLedgerAccount acct) {
    final availableCents = acct.availableStoreCreditCents;
    if (availableCents <= WalletAndLedgerService.minimumInstantCashOutFeeCents) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Available balance must exceed the R10.00 Instant Cash-Out fee.';
      });
      return;
    }

    try {
      _cashOutCounter++;
      final payout = widget.walletService.requestInstantCashOut(
        techId: widget.techId,
        requestedAmountCents: availableCents,
        idempotencyKey:
            'ui_instant_${widget.techId}_${DateTime.now().microsecondsSinceEpoch}_$_cashOutCounter',
      );
      setState(() {
        _isError = false;
        _statusMessage =
            'Instant Cash-Out sent: R${(payout.netPayoutCents / 100).toStringAsFixed(2)} net (fee R${(payout.convenienceFeeCents / 100).toStringAsFixed(2)}).';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = 'Could not process Instant Cash-Out right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final acct = widget.walletService.getTechAccount(widget.techId);
    final entries = widget.walletService.ledgerEntries
        .where((e) => e.userId == widget.techId)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('tech_earnings_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Earnings & Payouts'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            _buildSummaryCard(textTheme, acct),
            const SizedBox(height: 16),
            _buildStoreAllowanceCard(textTheme, acct),
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('tech_earnings_status_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError
                        ? BrandConfig.errorSoft
                        : BrandConfig.sageSoft,
                    borderRadius:
                        BorderRadius.circular(BrandConfig.inputRadius),
                    border: Border.all(
                      color: _isError
                          ? BrandConfig.errorTerracotta
                          : BrandConfig.sageSuccess,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandConfig.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('Earnings Ledger', style: textTheme.headlineMedium),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: BrandConfig.surfaceCard,
                  borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                  border: Border.all(color: BrandConfig.borderWarm),
                ),
                child: Text(
                  'Complete appointments with live camera proof to build your pending payout ledger.',
                  style: textTheme.bodyMedium,
                ),
              )
            else
              for (final entry in entries) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BrandConfig.surfaceCard,
                    borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                    border: Border.all(color: BrandConfig.borderWarm),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        entry.direction == 'credit'
                            ? Icons.trending_up_rounded
                            : Icons.payments_outlined,
                        color: entry.direction == 'credit'
                            ? BrandConfig.sageSuccess
                            : BrandConfig.roseDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.description, style: textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(entry.entryType.label, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Text(
                        '${entry.direction == 'credit' ? '+' : '-'}R${entry.amountZar.toStringAsFixed(2)}',
                        style: textTheme.labelLarge?.copyWith(
                          color: BrandConfig.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    TextTheme textTheme,
    TechEarningsLedgerAccount acct,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.largeCardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandConfig.sageSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  '85% Net After 15% Platform Fee',
                  style: textTheme.labelMedium?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                acct.payoutCadence.label,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'R${acct.unpaidNetEarningsZar.toStringAsFixed(2)}',
            key: const Key('tech_pending_payout_value'),
            style: textTheme.displayLarge?.copyWith(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unpaid Net Earnings • Total paid out: R${acct.paidOutTotalZar.toStringAsFixed(2)}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('tech_instant_cashout_button'),
              onPressed: acct.availableStoreCreditCents >
                      WalletAndLedgerService.minimumInstantCashOutFeeCents
                  ? () => _triggerInstantCashOut(acct)
                  : null,
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text('Instant Cash-Out (2.5% fee, minimum R10)'),
            ),
          ),
          if (acct.availableStoreCreditCents <=
              WalletAndLedgerService.minimumInstantCashOutFeeCents) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Available balance must exceed the R10.00 Instant Cash-Out fee.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreAllowanceCard(
    TextTheme textTheme,
    TechEarningsLedgerAccount acct,
  ) {
    return Container(
      key: const Key('tech_store_allowance_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.champagne),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pending Payout Store Allowance',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Available Store Credit', style: textTheme.bodyMedium),
              Text(
                'R${acct.availableStoreCreditZar.toStringAsFixed(2)}',
                key: const Key('tech_available_store_credit_value'),
                style: textTheme.titleMedium?.copyWith(
                  color: BrandConfig.espresso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Open Stock-Up Store Orders', style: textTheme.bodySmall),
              Text(
                'R${acct.openStoreOrdersZar.toStringAsFixed(2)}',
                style: textTheme.bodySmall?.copyWith(
                  color: BrandConfig.espresso,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
