import '../../../../core/uac/uac_permission_matrix.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../admin/domain/services/admin_command_service.dart';
import '../../../wallet/domain/services/wallet_and_ledger_service.dart';
import '../models/dispute_and_audit_models.dart';

/// Built-In 3-Photo Dispute Support Queue service.
///
/// Accessible to staff holding `disputes.view` / `disputes.resolve` permissions,
/// presenting side-by-side:
/// 1. Booked Visual Contract Portfolio Photo
/// 2. Tech's Live In-App Completion Photo
/// 3. Client's Dispute Photo
class DisputeResolutionService {
  DisputeResolutionService({
    required this.uacMatrix,
    required this.walletService,
    this.adminCommandService,
    List<DisputeTicket>? seedTickets,
  }) {
    final seed = seedTickets ?? _buildDefaultDemoTickets();
    for (final ticket in seed) {
      _tickets[ticket.id] = ticket;
    }
  }

  final UacPermissionMatrix uacMatrix;
  final WalletAndLedgerService walletService;
  final AdminCommandService? adminCommandService;

  final Map<String, DisputeTicket> _tickets = <String, DisputeTicket>{};
  final Map<String, int> _ticketAmountsCents = <String, int>{
    'disp_01': 45000,
    'disp_02': 52000,
  };

  List<DisputeTicket> getTicketsForStaff({
    required String actorId,
    required String actorUacGroup,
    bool isActive = true,
  }) {
    final canView = _hasAuthorisedPermission(
          actorId: actorId,
          actorUacGroup: actorUacGroup,
          actorIsActive: isActive,
          permissionKey: AbePermissions.disputesView,
        ) ||
        _hasAuthorisedPermission(
          actorId: actorId,
          actorUacGroup: actorUacGroup,
          actorIsActive: isActive,
          permissionKey: AbePermissions.disputesResolve,
        );
    if (!canView) {
      throw StateError(
        'Access denied: actor $actorId lacks disputes.view permission.',
      );
    }
    return List<DisputeTicket>.unmodifiable(_tickets.values);
  }

  void registerTicket(DisputeTicket ticket, {required int bookingAmountCents}) {
    _tickets[ticket.id] = ticket;
    _ticketAmountsCents[ticket.id] = InputSanitiser.requireNonNegativeInt(
      bookingAmountCents,
      fieldName: 'bookingAmountCents',
      strictlyPositive: true,
    );
  }

  /// 1-click resolution: credits the client's closed-loop ABE Wallet idempotently.
  DisputeTicket resolveCreditClientWallet({
    required String ticketId,
    required String actorId,
    required String actorUacGroup,
    required String idempotencyKey,
    bool actorIsActive = true,
    String notes = 'Quality mismatch verified across 3-photo review; credited client wallet.',
  }) {
    _requireResolvePermissions(
      actorId: actorId,
      actorUacGroup: actorUacGroup,
      actorIsActive: actorIsActive,
      requireWalletCredit: true,
    );

    final ticket = _requireOpenTicket(ticketId);
    final amountCents = _ticketAmountsCents[ticket.id] ?? 45000;

    walletService.creditClientWallet(
      clientId: ticket.clientId,
      amountCents: amountCents,
      idempotencyKey: idempotencyKey,
      reason: 'Dispute ${ticket.id} wallet credit',
      bookingId: ticket.bookingId,
    );

    final resolved = DisputeTicket(
      id: ticket.id,
      bookingId: ticket.bookingId,
      clientId: ticket.clientId,
      techId: ticket.techId,
      portfolioPhotoUrl: ticket.portfolioPhotoUrl,
      techLiveCompletionPhotoUrl: ticket.techLiveCompletionPhotoUrl,
      clientComplaintPhotoUrl: ticket.clientComplaintPhotoUrl,
      clientReason: ticket.clientReason,
      status: 'resolved_refund_client',
      resolutionNotes: notes,
    );
    _tickets[ticket.id] = resolved;

    adminCommandService?.recordAuditLog(
      actorId: actorId,
      action: 'dispute.resolve_refund_client',
      targetId: ticket.id,
      notes: notes,
    );
    return resolved;
  }

  /// 1-click resolution: releases payout to the nail technician.
  DisputeTicket resolveReleasePayoutToTech({
    required String ticketId,
    required String actorId,
    required String actorUacGroup,
    required String idempotencyKey,
    bool actorIsActive = true,
    String notes = 'Live completion photo matches Visual Contract; payout released to tech.',
  }) {
    _requireResolvePermissions(
      actorId: actorId,
      actorUacGroup: actorUacGroup,
      actorIsActive: actorIsActive,
      requireWalletCredit: false,
    );

    final ticket = _requireOpenTicket(ticketId);
    final amountCents = _ticketAmountsCents[ticket.id] ?? 45000;

    if (!walletService.isBookingSettled(ticket.bookingId)) {
      walletService.recordCompletedBookingSettlement(
        bookingId: ticket.bookingId,
        techId: ticket.techId,
        grossAmountCents: amountCents,
        completionPhotoUrl: ticket.techLiveCompletionPhotoUrl,
        idempotencyKey: idempotencyKey,
      );
    }

    final resolved = DisputeTicket(
      id: ticket.id,
      bookingId: ticket.bookingId,
      clientId: ticket.clientId,
      techId: ticket.techId,
      portfolioPhotoUrl: ticket.portfolioPhotoUrl,
      techLiveCompletionPhotoUrl: ticket.techLiveCompletionPhotoUrl,
      clientComplaintPhotoUrl: ticket.clientComplaintPhotoUrl,
      clientReason: ticket.clientReason,
      status: 'resolved_payout_tech',
      resolutionNotes: notes,
    );
    _tickets[ticket.id] = resolved;

    adminCommandService?.recordAuditLog(
      actorId: actorId,
      action: 'dispute.resolve_payout_tech',
      targetId: ticket.id,
      notes: notes,
    );
    return resolved;
  }

  bool _hasAuthorisedPermission({
    required String actorId,
    required String actorUacGroup,
    required bool actorIsActive,
    required String permissionKey,
  }) {
    if (adminCommandService != null) {
      return adminCommandService!.hasActivePermission(actorId, permissionKey);
    }
    // Without an authoritative directory wired, reject self-asserted admin roles.
    if (actorUacGroup == AbeUacGroupId.superAdmin.code ||
        actorUacGroup == AbeUacGroupId.opsAdmin.code) {
      return false;
    }
    return uacMatrix.hasPermission(
      userId: actorId,
      uacGroupId: actorUacGroup,
      permissionKey: permissionKey,
      isActive: actorIsActive,
    );
  }

  void _requireResolvePermissions({
    required String actorId,
    required String actorUacGroup,
    required bool actorIsActive,
    required bool requireWalletCredit,
  }) {
    final canResolve = _hasAuthorisedPermission(
      actorId: actorId,
      actorUacGroup: actorUacGroup,
      actorIsActive: actorIsActive,
      permissionKey: AbePermissions.disputesResolve,
    );
    if (!canResolve) {
      throw StateError(
        'Access denied: actor $actorId lacks disputes.resolve permission.',
      );
    }
    if (requireWalletCredit &&
        !_hasAuthorisedPermission(
          actorId: actorId,
          actorUacGroup: actorUacGroup,
          actorIsActive: actorIsActive,
          permissionKey: AbePermissions.walletCreditClient,
        )) {
      throw StateError(
        'Access denied: actor $actorId lacks wallet.credit_client permission.',
      );
    }
  }

  DisputeTicket _requireOpenTicket(String ticketId) {
    final ticket = _tickets[ticketId];
    if (ticket == null) {
      throw StateError('Dispute ticket $ticketId not found.');
    }
    if (ticket.status.startsWith('resolved_')) {
      throw StateError('Dispute ticket $ticketId has already been resolved.');
    }
    return ticket;
  }

  static List<DisputeTicket> _buildDefaultDemoTickets() {
    return <DisputeTicket>[
      DisputeTicket(
        id: 'disp_01',
        bookingId: 'bk_disp_901',
        clientId: 'client_naledi',
        techId: 'tech_cpt_01',
        portfolioPhotoUrl:
            'https://assets.abe.co.za/cpt/nadia_biab_french.jpg',
        techLiveCompletionPhotoUrl:
            'https://storage.abe.co.za/completions/bk_disp_901_live.jpg',
        clientComplaintPhotoUrl:
            'https://storage.abe.co.za/disputes/bk_disp_901_client.jpg',
        clientReason:
            'French tip thickness on thumb differs from the booked Visual Contract photo.',
        status: 'open',
      ),
      DisputeTicket(
        id: 'disp_02',
        bookingId: 'bk_disp_902',
        clientId: 'client_taryn',
        techId: 'tech_jhb_01',
        portfolioPhotoUrl:
            'https://assets.abe.co.za/jhb/lerato_glazed_gelx.jpg',
        techLiveCompletionPhotoUrl:
            'https://storage.abe.co.za/completions/bk_disp_902_live.jpg',
        clientComplaintPhotoUrl:
            'https://storage.abe.co.za/disputes/bk_disp_902_client.jpg',
        clientReason: 'Chrome glaze chipped on index nail within 24 hours.',
        status: 'under_review',
      ),
    ];
  }
}
