import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/uac/uac_permission_matrix.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../wallet/domain/models/wallet_ledger_models.dart';
import '../../domain/services/admin_command_service.dart';

/// Rio & Aqeelah's Master Admin Command Centre:
/// 1. Data & Financial Telemetry + SARS CSV Export
/// 2. Dynamic UAC & Access Groups Manager + 1-Click Revocation + Immutable Staff Audit Log
/// 3. Coupon & Voucher Manager
class MasterAdminCommandCentreScreen extends StatefulWidget {
  const MasterAdminCommandCentreScreen({
    super.key,
    required this.actorId,
    required this.adminService,
    this.onBack,
    this.onOpenDisputeQueue,
  });

  final String actorId;
  final AdminCommandService adminService;
  final VoidCallback? onBack;
  final VoidCallback? onOpenDisputeQueue;

  @override
  State<MasterAdminCommandCentreScreen> createState() =>
      _MasterAdminCommandCentreScreenState();
}

class _MasterAdminCommandCentreScreenState
    extends State<MasterAdminCommandCentreScreen> {
  int _selectedSection = 0; // 0: Telemetry, 1: UAC, 2: Vouchers
  String? _statusBanner;
  bool _isErrorBanner = false;
  String? _exportedCsvPreview;
  String _selectedGroupId = AbeUacGroupId.supportAgent.code;

  final TextEditingController _customGroupNameController =
      TextEditingController();
  final TextEditingController _inviteNameController = TextEditingController();
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _couponCodeController = TextEditingController();
  final TextEditingController _couponValueController =
      TextEditingController(text: '100');

  @override
  void dispose() {
    _customGroupNameController.dispose();
    _inviteNameController.dispose();
    _inviteEmailController.dispose();
    _couponCodeController.dispose();
    _couponValueController.dispose();
    super.dispose();
  }

  void _setFeedback(String message, {bool isError = false}) {
    setState(() {
      _statusBanner = message;
      _isErrorBanner = isError;
    });
  }

  void _handleExportCsv() {
    try {
      final csv = widget.adminService.exportSarsLedgerCsv(actorId: widget.actorId);
      setState(() {
        _exportedCsvPreview = csv;
        _statusBanner = 'SARS / Accountant CSV ledger generated.';
        _isErrorBanner = false;
      });
    } catch (e) {
      _setFeedback('Export blocked: lacks ledger.export permission.', isError: true);
    }
  }

  void _handleCreateCustomGroup() {
    final name = InputSanitiser.sanitiseText(
      _customGroupNameController.text,
      maxLength: 80,
    );
    if (name.isEmpty) {
      _setFeedback('Enter a name for the custom UAC group.', isError: true);
      return;
    }
    final groupId = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    try {
      final created = widget.adminService.createCustomUacGroup(
        actorId: widget.actorId,
        groupId: groupId,
        displayName: name,
        permissions: const <String>[AbePermissions.disputesView],
      );
      _customGroupNameController.clear();
      setState(() {
        _selectedGroupId = created.groupId;
      });
      _setFeedback('Created custom UAC group "${created.displayName}".');
    } catch (e) {
      _setFeedback('Could not create custom UAC group.', isError: true);
    }
  }

  void _handleInviteStaff() {
    final name = InputSanitiser.sanitiseText(
      _inviteNameController.text,
      maxLength: 80,
    );
    final email = InputSanitiser.sanitiseText(
      _inviteEmailController.text,
      maxLength: 160,
    );
    if (name.isEmpty || email.isEmpty) {
      _setFeedback('Enter staff name and email address.', isError: true);
      return;
    }
    try {
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final userId =
          'staff_${slug.isEmpty ? 'member' : slug}_${DateTime.now().millisecondsSinceEpoch}';
      final invited = widget.adminService.inviteStaffMember(
        actorId: widget.actorId,
        userId: userId,
        displayName: name,
        email: email,
        uacGroupId: _selectedGroupId,
        city: 'CPT',
      );
      _inviteNameController.clear();
      _inviteEmailController.clear();
      _setFeedback('Invited ${invited.displayName} into $_selectedGroupId.');
    } catch (_) {
      _setFeedback('Could not invite staff member.', isError: true);
    }
  }

  void _handleCreateCoupon() {
    final rawCode = _couponCodeController.text.trim();
    final value = int.tryParse(_couponValueController.text.trim()) ?? 0;
    if (rawCode.isEmpty || value <= 0) {
      _setFeedback('Enter a valid promo code and positive ZAR discount.', isError: true);
      return;
    }
    try {
      final coupon = PromoCouponRecord(
        id: 'vch_${DateTime.now().millisecondsSinceEpoch}',
        code: rawCode,
        discountType: VoucherDiscountType.fixedZar,
        discountValue: value,
        minSpendZar: 200,
        maxRedemptions: 250,
        perUserLimit: 1,
        issuedForReason: 'admin_campaign',
      );
      widget.adminService.createCoupon(actorId: widget.actorId, coupon: coupon);
      _couponCodeController.clear();
      _setFeedback('Created promo code ${coupon.code} (R${coupon.discountValue} off).');
    } catch (_) {
      _setFeedback('Could not create coupon code.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasAccess = widget.adminService.isStaffMember(widget.actorId) &&
        (widget.adminService.hasActivePermission(
              widget.actorId,
              AbePermissions.uacManageRoles,
            ) ||
            widget.adminService.hasActivePermission(
              widget.actorId,
              AbePermissions.ledgerExport,
            ) ||
            widget.adminService.hasActivePermission(
              widget.actorId,
              AbePermissions.vouchersManage,
            ));

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('admin_centre_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Admin Command'),
        actions: <Widget>[
          if (widget.onOpenDisputeQueue != null)
            TextButton.icon(
              key: const Key('admin_open_disputes_button'),
              style: TextButton.styleFrom(
                foregroundColor: BrandConfig.espresso,
              ),
              onPressed: widget.onOpenDisputeQueue,
              icon: const Icon(Icons.gavel_outlined, size: 18),
              label: const Text('Disputes'),
            ),
        ],
      ),
      body: SafeArea(
        child: !hasAccess
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BrandConfig.errorSoft,
                      borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                      border: Border.all(color: BrandConfig.errorTerracotta),
                    ),
                    child: Text(
                      'Access denied: active administrator privileges are required.',
                      key: const Key('admin_access_denied_text'),
                      style: textTheme.titleMedium?.copyWith(
                        color: BrandConfig.espresso,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            : ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            _buildSectionTabs(),
            if (_statusBanner != null) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('admin_status_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isErrorBanner
                        ? BrandConfig.errorSoft
                        : BrandConfig.sageSoft,
                    borderRadius:
                        BorderRadius.circular(BrandConfig.inputRadius),
                    border: Border.all(
                      color: _isErrorBanner
                          ? BrandConfig.errorTerracotta
                          : BrandConfig.sageSuccess,
                    ),
                  ),
                  child: Text(
                    _statusBanner!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandConfig.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_selectedSection == 0)
              _buildTelemetrySection(textTheme)
            else if (_selectedSection == 1)
              _buildUacSection(textTheme)
            else
              _buildVouchersSection(textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ChoiceChip(
          key: const Key('admin_tab_telemetry'),
          label: const Text('Telemetry & SARS'),
          selected: _selectedSection == 0,
          onSelected: (_) => setState(() => _selectedSection = 0),
        ),
        ChoiceChip(
          key: const Key('admin_tab_uac'),
          label: const Text('Dynamic UAC & Staff'),
          selected: _selectedSection == 1,
          onSelected: (_) => setState(() => _selectedSection = 1),
        ),
        ChoiceChip(
          key: const Key('admin_tab_vouchers'),
          label: const Text('Coupons & Vouchers'),
          selected: _selectedSection == 2,
          onSelected: (_) => setState(() => _selectedSection = 2),
        ),
      ],
    );
  }

  Widget _buildTelemetrySection(TextTheme textTheme) {
    final telemetry = widget.adminService.buildTelemetrySnapshot();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Financial & City Telemetry', style: textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                label: 'Total Float Held',
                value: 'R${telemetry.totalFloatZar.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Total GMV',
                value: 'R${telemetry.totalGmvZar.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                label: '15% Platform Revenue',
                value: 'R${telemetry.platformRevenueZar.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Chair Turnover Rate',
                value: '${telemetry.chairTurnoverRate.toStringAsFixed(1)} / day',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'CPT vs. JHB Bookings',
          value:
              'Cape Town: ${telemetry.cptBookingsCount} • Johannesburg: ${telemetry.jhbBookingsCount}',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('admin_export_csv_button'),
            onPressed: _handleExportCsv,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export SARS / Accountant CSV Ledger'),
          ),
        ),
        if (_exportedCsvPreview != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            key: const Key('admin_csv_preview_box'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrandConfig.surfaceCard,
              borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
              border: Border.all(color: BrandConfig.borderWarm),
            ),
            child: Text(
              _exportedCsvPreview!,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUacSection(TextTheme textTheme) {
    final groups = widget.adminService.groups;
    final staff = widget.adminService.staffMembers;
    final logs = widget.adminService.auditLogs.reversed.toList();
    final activeGroupPerms =
        widget.adminService.uacMatrix.permissionsForGroup(_selectedGroupId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Dynamic UAC Groups & Matrix', style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final group in groups)
              ChoiceChip(
                key: Key('uac_group_chip_${group.groupId}'),
                label: Text(group.displayName),
                selected: _selectedGroupId == group.groupId,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) =>
                    setState(() => _selectedGroupId = group.groupId),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BrandConfig.surfaceCard,
            borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
            border: Border.all(color: BrandConfig.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Permissions for $_selectedGroupId',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final perm in AbePermissions.allKeys)
                    FilterChip(
                      key: Key('perm_toggle_${_selectedGroupId}_$perm'),
                      label: Text(perm),
                      selected: activeGroupPerms.contains(perm),
                      onSelected: (enabled) {
                        try {
                          widget.adminService.toggleGroupPermission(
                            actorId: widget.actorId,
                            groupId: _selectedGroupId,
                            permissionKey: perm,
                            enabled: enabled,
                          );
                          _setFeedback(
                            '${enabled ? 'Granted' : 'Revoked'} $perm on $_selectedGroupId.',
                          );
                        } catch (_) {
                          _setFeedback(
                            'Access denied: uac.manage_roles required.',
                            isError: true,
                          );
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final groupField = TextField(
              key: const Key('admin_custom_group_input'),
              controller: _customGroupNameController,
              decoration: const InputDecoration(
                labelText: 'New Custom UAC Group Name',
              ),
            );
            final addBtn = ElevatedButton(
              key: const Key('admin_create_uac_group_button'),
              onPressed: _handleCreateCustomGroup,
              child: const Text('Add Group'),
            );
            if (constraints.maxWidth < 460) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  groupField,
                  const SizedBox(height: 8),
                  addBtn,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: groupField),
                const SizedBox(width: 10),
                addBtn,
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Staff & Partner Access Control', style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final nameField = TextField(
              key: const Key('admin_invite_name_input'),
              controller: _inviteNameController,
              decoration: const InputDecoration(labelText: 'Staff Name'),
            );
            final emailField = TextField(
              key: const Key('admin_invite_email_input'),
              controller: _inviteEmailController,
              decoration: const InputDecoration(labelText: 'Staff Email'),
            );
            final inviteBtn = ElevatedButton(
              key: const Key('admin_invite_staff_button'),
              onPressed: _handleInviteStaff,
              child: const Text('Invite'),
            );
            if (constraints.maxWidth < 500) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  nameField,
                  const SizedBox(height: 8),
                  emailField,
                  const SizedBox(height: 8),
                  inviteBtn,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: nameField),
                const SizedBox(width: 8),
                Expanded(child: emailField),
                const SizedBox(width: 8),
                inviteBtn,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        for (final member in staff)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BrandConfig.surfaceCard,
              borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
              border: Border.all(
                color: member.isActive
                    ? BrandConfig.borderWarm
                    : BrandConfig.errorTerracotta,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(member.displayName, style: textTheme.titleSmall),
                      Text(
                        '${member.uacGroupId} • ${member.city} • ${member.isActive ? 'Active' : 'Revoked'}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (member.isActive && member.userId != widget.actorId)
                  OutlinedButton(
                    key: Key('revoke_staff_${member.userId}'),
                    onPressed: () {
                      try {
                        widget.adminService.revokeStaffAccess(
                          actorId: widget.actorId,
                          targetUserId: member.userId,
                        );
                        _setFeedback('Revoked access for ${member.displayName}.');
                      } catch (_) {
                        _setFeedback(
                          'Could not revoke access.',
                          isError: true,
                        );
                      }
                    },
                    child: const Text('Revoke'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Text('Immutable Staff Audit Log', style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          Text('No administrative actions logged yet.', style: textTheme.bodyMedium)
        else
          for (final log in logs.take(8))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BrandConfig.surfaceCard,
                borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
                border: Border.all(color: BrandConfig.borderWarm),
              ),
              child: Text(
                '${log.action} • target: ${log.targetId} • by ${log.actorId}',
                style: textTheme.bodySmall?.copyWith(color: BrandConfig.espresso),
              ),
            ),
      ],
    );
  }

  Widget _buildVouchersSection(TextTheme textTheme) {
    final coupons = widget.adminService.voucherService.allCoupons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Coupon & Voucher Manager', style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final codeField = TextField(
              key: const Key('admin_coupon_code_input'),
              controller: _couponCodeController,
              decoration: const InputDecoration(labelText: 'Promo Code'),
            );
            final valueField = TextField(
              key: const Key('admin_coupon_value_input'),
              controller: _couponValueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ZAR Off'),
            );
            final createBtn = ElevatedButton(
              key: const Key('admin_create_coupon_button'),
              onPressed: _handleCreateCoupon,
              child: const Text('Create'),
            );
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  codeField,
                  const SizedBox(height: 8),
                  valueField,
                  const SizedBox(height: 8),
                  createBtn,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(flex: 2, child: codeField),
                const SizedBox(width: 8),
                Expanded(child: valueField),
                const SizedBox(width: 8),
                createBtn,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        for (final coupon in coupons)
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(coupon.code, style: textTheme.titleSmall),
                      Text(
                        '${coupon.discountType == VoucherDiscountType.fixedZar ? 'R${coupon.discountValue}' : '${coupon.discountValue}%'} off • '
                        'Used ${coupon.currentRedemptions}/${coupon.maxRedemptions}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Toggle promo code ${coupon.code}',
                  toggled: coupon.isActive,
                  child: Switch(
                    key: Key('coupon_active_switch_${coupon.code}'),
                    value: coupon.isActive,
                    onChanged: (next) {
                      try {
                        widget.adminService.toggleCouponActive(
                          actorId: widget.actorId,
                          code: coupon.code,
                          isActive: next,
                        );
                        _setFeedback(
                          '${next ? 'Activated' : 'Paused'} ${coupon.code}.',
                        );
                      } catch (_) {
                        _setFeedback('Could not update coupon.', isError: true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrandConfig.surfaceCard,
          borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
          border: Border.all(color: BrandConfig.borderWarm),
          boxShadow: BrandConfig.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
