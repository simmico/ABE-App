import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/wallet_ledger_models.dart';
import '../../domain/services/wallet_and_ledger_service.dart';

/// Client Closed-Loop ABE Wallet screen.
///
/// Displays non-withdrawable wallet credits (automatically applied at checkout),
/// active apology/promo vouchers, and immutable wallet ledger activity.
class ClientWalletScreen extends StatelessWidget {
  const ClientWalletScreen({
    super.key,
    required this.clientId,
    required this.walletService,
    this.onBack,
    this.onBrowseLooks,
  });

  final String clientId;
  final WalletAndLedgerService walletService;
  final VoidCallback? onBack;
  final VoidCallback? onBrowseLooks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wallet = walletService.getClientWallet(clientId);
    final entries = walletService.ledgerEntries
        .where((e) => e.userId == clientId)
        .toList()
        .reversed
        .toList();
    final now = DateTime.now().toUtc();
    final clientVouchers = walletService.voucherService.allCoupons
        .where(
          (v) =>
              v.isActive &&
              v.currentRedemptions < v.maxRedemptions &&
              (v.expiresAtUtc == null || !now.isAfter(v.expiresAtUtc!)) &&
              (v.assignedToUserId == null || v.assignedToUserId == clientId),
        )
        .toList();

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(
                key: const Key('client_wallet_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        title: const Text('My ABE Wallet'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            _buildBalanceCard(textTheme, wallet),
            const SizedBox(height: 16),
            _buildVouchersSection(textTheme, clientVouchers),
            const SizedBox(height: 18),
            Text('Wallet Activity', style: textTheme.headlineMedium),
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
                  'No wallet credits or redemptions recorded yet.',
                  style: textTheme.bodyMedium,
                ),
              )
            else
              for (final entry in entries) ...<Widget>[
                _LedgerTile(entry: entry),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    TextTheme textTheme,
    ClosedLoopClientWallet wallet,
  ) {
    return Container(
      key: const Key('client_wallet_balance_card'),
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
                  color: BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  'Closed-Loop Beauty Credit',
                  style: textTheme.labelMedium?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: BrandConfig.roseDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'R${wallet.balanceZar.toStringAsFixed(2)}',
            key: const Key('client_wallet_balance_value'),
            style: textTheme.displayLarge?.copyWith(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your ABE Wallet balance is applied automatically at checkout on your next Cape Town or Johannesburg booking. Wallet credits are non-withdrawable.',
            style: textTheme.bodyMedium,
          ),
          if (onBrowseLooks != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wallet_browse_looks_button'),
                onPressed: onBrowseLooks,
                child: const Text('Book a Look with Wallet Credit'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVouchersSection(
    TextTheme textTheme,
    List<PromoCouponRecord> vouchers,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Available Vouchers', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          if (vouchers.isEmpty)
            Text(
              'No active vouchers on your account right now.',
              style: textTheme.bodyMedium,
            )
          else
            for (final v in vouchers) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BrandConfig.bgCream,
                  borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
                  border: Border.all(color: BrandConfig.borderWarm),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BrandConfig.sageSoft,
                        borderRadius: BorderRadius.circular(
                          BrandConfig.pillRadius,
                        ),
                      ),
                      child: Text(
                        v.code,
                        style: textTheme.labelMedium?.copyWith(
                          color: BrandConfig.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        v.discountType == VoucherDiscountType.fixedZar
                            ? 'R${v.discountValue} off (minimum spend R${v.minSpendZar})'
                            : '${v.discountValue}% off (minimum spend R${v.minSpendZar})',
                        style: textTheme.bodySmall?.copyWith(
                          color: BrandConfig.espresso,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final FinancialLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCredit = entry.direction == 'credit';

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrandConfig.surfaceCard,
          borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
          border: Border.all(color: BrandConfig.borderWarm),
        ),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                isCredit
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
                color: isCredit ? BrandConfig.sageSuccess : BrandConfig.roseDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.description,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.entryType.label,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}R${entry.amountZar.toStringAsFixed(2)}',
              style: textTheme.labelLarge?.copyWith(
                color: BrandConfig.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
