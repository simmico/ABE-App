import 'package:abe_app/core/uac/uac_permission_matrix.dart';
import 'package:abe_app/core/utils/input_sanitiser.dart';
import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/auth/domain/models/uac_group.dart';
import 'package:abe_app/features/disputes/domain/models/dispute_and_audit_models.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/store/domain/models/store_models.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputSanitiser', () {
    test('strips script tags, style blocks, HTML tags, inline events, and dangerous URI schemes', () {
      const raw =
          '<script>alert("xss")</script>'
          '<style>body { display: none; }</style>'
          '<div onclick="stealToken()" onmouseover=\'evil()\'>'
          'Luxury BIAB Gel javascript:void(0) data:text/html'
          '</div>';

      final cleaned = InputSanitiser.sanitiseText(raw);
      expect(cleaned.contains('<script'), isFalse);
      expect(cleaned.contains('alert'), isFalse);
      expect(cleaned.contains('<style'), isFalse);
      expect(cleaned.contains('onclick'), isFalse);
      expect(cleaned.contains('onmouseover'), isFalse);
      expect(cleaned.contains('<div'), isFalse);
      expect(cleaned.contains('javascript:'), isFalse);
      expect(cleaned.contains('data:'), isFalse);
      expect(cleaned, contains('Luxury BIAB Gel'));
    });

    test('replaces forbidden em-dash characters with standard hyphens', () {
      const rawWithEmDash = 'Cape Town Studio \u2014 Sea Point';
      final cleaned = InputSanitiser.sanitiseText(rawWithEmDash);
      expect(cleaned.contains('\u2014'), isFalse);
      expect(cleaned, equals('Cape Town Studio - Sea Point'));
    });

    test('enforces maxLength truncation cleanly', () {
      const raw = 'Aqeelah Beauty Empire Luxury Nail Studio';
      final cleaned = InputSanitiser.sanitiseText(raw, maxLength: 14);
      expect(cleaned, equals('Aqeelah Beauty'));
    });

    test('sanitiseVoucherCode normalises to uppercase alphanumeric and rejects empty codes', () {
      expect(
        InputSanitiser.sanitiseVoucherCode('abe-tech_cancel 100!@#'),
        equals('ABE-TECH_CANCEL100'),
      );
      expect(
        () => InputSanitiser.sanitiseVoucherCode('!@#\$%^&*()'),
        throwsArgumentError,
      );
    });

    test('validateCityCode accepts only CPT and JHB', () {
      expect(InputSanitiser.validateCityCode('cpt'), equals('CPT'));
      expect(InputSanitiser.validateCityCode(' JHB '), equals('JHB'));
      expect(() => InputSanitiser.validateCityCode('DBN'), throwsArgumentError);
      expect(() => InputSanitiser.validateCityCode(''), throwsArgumentError);
    });

    test('requireNonNegativeInt and requireNonNegativeDouble reject negative, zero when strictlyPositive, and non-finite numbers', () {
      expect(
        InputSanitiser.requireNonNegativeInt(0, fieldName: 'fee'),
        equals(0),
      );
      expect(
        InputSanitiser.requireNonNegativeInt(
          450,
          fieldName: 'price',
          strictlyPositive: true,
        ),
        equals(450),
      );
      expect(
        () => InputSanitiser.requireNonNegativeInt(-1, fieldName: 'price'),
        throwsArgumentError,
      );
      expect(
        () => InputSanitiser.requireNonNegativeInt(
          0,
          fieldName: 'price',
          strictlyPositive: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => InputSanitiser.requireNonNegativeInt(
          double.nan,
          fieldName: 'price',
        ),
        throwsArgumentError,
      );

      expect(
        InputSanitiser.requireNonNegativeDouble(125.50, fieldName: 'wallet'),
        equals(125.50),
      );
      expect(
        () => InputSanitiser.requireNonNegativeDouble(-0.01, fieldName: 'wallet'),
        throwsArgumentError,
      );
      expect(
        () => InputSanitiser.requireNonNegativeDouble(
          0.0,
          fieldName: 'wallet',
          strictlyPositive: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => InputSanitiser.requireNonNegativeDouble(
          double.infinity,
          fieldName: 'wallet',
        ),
        throwsArgumentError,
      );
    });
  });

  group('UacPermissionMatrix & 7 UAC Groups', () {
    test('verifies default permissions across all 7 UAC groups', () {
      final matrix = UacPermissionMatrix();

      // 1. super_admin (Rio) holds all 10 permissions
      for (final perm in AbePermissions.allKeys) {
        expect(
          matrix.hasPermission(
            userId: 'rio_1',
            uacGroupId: AbeUacGroupId.superAdmin.code,
            permissionKey: perm,
          ),
          isTrue,
          reason: 'super_admin should hold $perm',
        );
      }

      // 2. ops_admin (Aqeelah) holds operational permissions but not uac.manage_roles or ledger.export
      expect(
        matrix.hasPermission(
          userId: 'aqeelah_1',
          uacGroupId: AbeUacGroupId.opsAdmin.code,
          permissionKey: AbePermissions.techsAwardPro,
        ),
        isTrue,
      );
      expect(
        matrix.hasPermission(
          userId: 'aqeelah_1',
          uacGroupId: AbeUacGroupId.opsAdmin.code,
          permissionKey: AbePermissions.disputesResolve,
        ),
        isTrue,
      );
      expect(
        matrix.hasPermission(
          userId: 'aqeelah_1',
          uacGroupId: AbeUacGroupId.opsAdmin.code,
          permissionKey: AbePermissions.uacManageRoles,
        ),
        isFalse,
      );
      expect(
        matrix.hasPermission(
          userId: 'aqeelah_1',
          uacGroupId: AbeUacGroupId.opsAdmin.code,
          permissionKey: AbePermissions.ledgerExport,
        ),
        isFalse,
      );

      // 3. support_agent holds disputes and client wallet credit permissions only
      expect(
        matrix.hasPermission(
          userId: 'agent_1',
          uacGroupId: AbeUacGroupId.supportAgent.code,
          permissionKey: AbePermissions.disputesView,
        ),
        isTrue,
      );
      expect(
        matrix.hasPermission(
          userId: 'agent_1',
          uacGroupId: AbeUacGroupId.supportAgent.code,
          permissionKey: AbePermissions.walletCreditClient,
        ),
        isTrue,
      );
      expect(
        matrix.hasPermission(
          userId: 'agent_1',
          uacGroupId: AbeUacGroupId.supportAgent.code,
          permissionKey: AbePermissions.techsApprove,
        ),
        isFalse,
      );

      // 4. supplier_partner holds store inventory and order fulfilment permissions only
      expect(
        matrix.hasPermission(
          userId: 'supplier_1',
          uacGroupId: AbeUacGroupId.supplierPartner.code,
          permissionKey: AbePermissions.storeManageInventory,
        ),
        isTrue,
      );
      expect(
        matrix.hasPermission(
          userId: 'supplier_1',
          uacGroupId: AbeUacGroupId.supplierPartner.code,
          permissionKey: AbePermissions.storeFulfilOrders,
        ),
        isTrue,
      );
      expect(
        matrix.hasPermission(
          userId: 'supplier_1',
          uacGroupId: AbeUacGroupId.supplierPartner.code,
          permissionKey: AbePermissions.disputesView,
        ),
        isFalse,
      );

      // 5. salon_partner, 6. tech, 7. client hold zero administrative permissions by default
      for (final group in <AbeUacGroupId>[
        AbeUacGroupId.salonPartner,
        AbeUacGroupId.tech,
        AbeUacGroupId.client,
      ]) {
        for (final perm in AbePermissions.allKeys) {
          expect(
            matrix.hasPermission(
              userId: 'user_${group.code}',
              uacGroupId: group.code,
              permissionKey: perm,
            ),
            isFalse,
            reason: '${group.code} must not hold admin permission $perm',
          );
        }
      }
    });

    test('enforces instant revocation when isActive is false or deactivated in live matrix', () {
      final matrix = UacPermissionMatrix();

      // Passing isActive: false directly
      expect(
        matrix.hasPermission(
          userId: 'admin_deactivated',
          uacGroupId: AbeUacGroupId.superAdmin.code,
          permissionKey: AbePermissions.uacManageRoles,
          isActive: false,
        ),
        isFalse,
      );

      // Live deactivation via setUserActiveStatus overrides active flag
      matrix.setUserActiveStatus('ops_live', isActive: false);
      expect(
        matrix.hasPermission(
          userId: 'ops_live',
          uacGroupId: AbeUacGroupId.opsAdmin.code,
          permissionKey: AbePermissions.disputesView,
          isActive: true,
        ),
        isFalse,
      );

      // Re-activating restores group permissions
      matrix.setUserActiveStatus('ops_live', isActive: true);
      expect(
        matrix.hasPermission(
          userId: 'ops_live',
          uacGroupId: AbeUacGroupId.opsAdmin.code,
          permissionKey: AbePermissions.disputesView,
        ),
        isTrue,
      );
    });

    test('supports dynamic group permission grant/revoke, live group reassignment, and per-user revocation', () {
      final matrix = UacPermissionMatrix();

      matrix.grantPermissionToGroup(
        AbeUacGroupId.salonPartner.code,
        AbePermissions.vouchersManage,
      );
      expect(
        matrix.hasPermission(
          userId: 'salon_1',
          uacGroupId: AbeUacGroupId.salonPartner.code,
          permissionKey: AbePermissions.vouchersManage,
        ),
        isTrue,
      );

      matrix.revokePermissionFromGroup(
        AbeUacGroupId.salonPartner.code,
        AbePermissions.vouchersManage,
      );
      expect(
        matrix.hasPermission(
          userId: 'salon_1',
          uacGroupId: AbeUacGroupId.salonPartner.code,
          permissionKey: AbePermissions.vouchersManage,
        ),
        isFalse,
      );

      // Live group reassignment
      matrix.assignUserGroup('user_promoted', AbeUacGroupId.supportAgent.code);
      expect(
        matrix.hasPermission(
          userId: 'user_promoted',
          uacGroupId: AbeUacGroupId.client.code,
          permissionKey: AbePermissions.disputesView,
        ),
        isTrue,
      );

      // Explicit per-user revocation
      matrix.revokePermissionForUser(
        'user_promoted',
        AbePermissions.disputesView,
      );
      expect(
        matrix.hasPermission(
          userId: 'user_promoted',
          uacGroupId: AbeUacGroupId.supportAgent.code,
          permissionKey: AbePermissions.disputesView,
        ),
        isFalse,
      );
    });
  });

  group('Domain Models Serialisation & Business Invariants', () {
    test('UacGroup and AbeUser serialise to/from JSON and enforce sanitisation & active checks', () {
      final group = UacGroup.fromJson(<String, dynamic>{
        'id': 'ops_admin',
        'name': 'Operations & Brand Admin \u2014 CPT',
        'permissions': <String>[
          AbePermissions.techsAwardPro,
          AbePermissions.disputesResolve,
        ],
        'isActive': true,
      });

      expect(group.id, equals('ops_admin'));
      expect(group.name, equals('Operations & Brand Admin - CPT'));
      expect(group.hasPermission(AbePermissions.techsAwardPro), isTrue);
      expect(group.toJson()['permissions'], hasLength(2));

      final inactiveGroup = UacGroup(
        id: 'ops_admin',
        name: 'Inactive Ops',
        permissions: <String>[AbePermissions.techsAwardPro],
        isActive: false,
      );
      expect(inactiveGroup.hasPermission(AbePermissions.techsAwardPro), isFalse);

      final user = AbeUser.fromJson(<String, dynamic>{
        'id': 'user_aqeelah',
        'name': 'Aqeelah <script>evil()</script>',
        'email': 'aqeelah@abe.co.za',
        'uacGroupId': 'ops_admin',
        'city': 'cpt',
        'permissions': <String>[AbePermissions.ledgerExport],
        'isActive': true,
        'walletBalanceZar': 350.0,
      });

      expect(user.name, equals('Aqeelah'));
      expect(user.city, equals('CPT'));
      expect(user.parsedGroup, equals(AbeUacGroupId.opsAdmin));
      expect(user.hasPermission(AbePermissions.techsAwardPro), isTrue);
      expect(user.hasPermission(AbePermissions.ledgerExport), isTrue);

      final roundTrip = AbeUser.fromJson(user.toJson());
      expect(roundTrip.id, equals(user.id));
      expect(roundTrip.walletBalanceZar, equals(350.0));
    });

    test('TechProfile serialises cleanly and enforces non-empty verifiedStudioId', () {
      final tech = TechProfile.fromJson(<String, dynamic>{
        'userId': 'tech_01',
        'displayName': 'Zanele Nails \u2014 Rosebank',
        'tierBadge': 'certified_pro',
        'verifiedStudioId': 'studio_jhb_01',
        'city': 'JHB',
        'bio': 'Specialising in structured BIAB.',
        'pendingStoreCreditZar': 1200.50,
        'rating': 4.95,
        'completedBookingsCount': 42,
        'isApproved': true,
      });

      expect(tech.displayName, equals('Zanele Nails - Rosebank'));
      expect(tech.tierBadge, equals(TechTierBadge.certifiedPro));
      expect(tech.city, equals('JHB'));
      expect(TechProfile.fromJson(tech.toJson()).verifiedStudioId, equals('studio_jhb_01'));

      expect(
        () => TechProfile(
          userId: 'tech_02',
          displayName: 'Unverified Mobile Tech',
          tierBadge: TechTierBadge.rising,
          verifiedStudioId: '   ',
          city: 'CPT',
        ),
        throwsArgumentError,
      );
    });

    test('CommercialVenue enforces Strict Venue-Only Policy and rejects house calls', () {
      final studio = CommercialVenue.fromJson(<String, dynamic>{
        'id': 'venue_cpt_1',
        'name': 'Blush Atelier Studio',
        'city': 'CPT',
        'suburb': 'Sea Point',
        'address': '142 Main Road, Sea Point',
        'type': 'verified_studio',
        'isVerified': true,
        'emptyChairFeeZar': 0,
      });

      expect(studio.type, equals(CommercialVenueType.verifiedStudio));
      expect(CommercialVenue.fromJson(studio.toJson()).name, equals('Blush Atelier Studio'));

      // Rejects invalid venue type (such as house_call)
      expect(
        () => CommercialVenueType.fromCode('house_call'),
        throwsArgumentError,
      );

      // Rejects house call / home visit / mobile tech keywords in name or address
      expect(
        () => CommercialVenue(
          id: 'venue_bad_1',
          name: 'Luxury House Call Nails',
          city: 'CPT',
          suburb: 'Claremont',
          address: '12 Grove Ave',
          type: CommercialVenueType.verifiedStudio,
          isVerified: false,
        ),
        throwsArgumentError,
      );

      expect(
        () => CommercialVenue(
          id: 'venue_bad_2',
          name: 'Glow Studio',
          city: 'JHB',
          suburb: 'Sandton',
          address: 'Available for home visit appointments',
          type: CommercialVenueType.partnerSalon,
          isVerified: false,
        ),
        throwsArgumentError,
      );
    });

    test('VisualContractItem calculates modifier price and duration accurately', () {
      final item = VisualContractItem.fromJson(<String, dynamic>{
        'id': 'vc_101',
        'techId': 'tech_01',
        'techDisplayName': 'Naledi Studio',
        'techTierBadge': 'certified_pro',
        'photoUrl': 'https://cdn.abe.co.za/looks/biab_french.jpg',
        'title': 'Sheer Milky BIAB & Micro French',
        'basePriceZar': 480,
        'baseDurationMinutes': 90,
        'city': 'CPT',
        'venueId': 'venue_cpt_1',
        'venueName': 'Blush Atelier Studio',
        'venueType': 'verified_studio',
        'allowedModifiers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'mod_soak_off',
            'name': 'Soak-Off / Removal',
            'additionalPriceZar': 90,
            'additionalDurationMinutes': 30,
          },
          <String, dynamic>{
            'id': 'mod_extra_length',
            'name': 'Extra Length Sculpt',
            'additionalPriceZar': 120,
            'additionalDurationMinutes': 25,
          },
          <String, dynamic>{
            'id': 'mod_repair',
            'name': 'Single Nail Repair',
            'additionalPriceZar': 40,
            'additionalDurationMinutes': 15,
          },
        ],
      });

      expect(item.formattedBasePrice, equals('R480'));
      expect(item.formattedBaseDuration, equals('90 mins'));
      expect(item.calculateTotalPriceZar(<String>{}), equals(480));
      expect(item.calculateTotalDurationMinutes(<String>{}), equals(90));

      final selected = <String>{'mod_soak_off', 'mod_extra_length'};
      expect(item.calculateTotalPriceZar(selected), equals(480 + 90 + 120));
      expect(item.calculateTotalDurationMinutes(selected), equals(90 + 30 + 25));

      final roundTrip = VisualContractItem.fromJson(item.toJson());
      expect(roundTrip.allowedModifiers, hasLength(3));
      expect(roundTrip.calculateTotalPriceZar(selected), equals(690));
    });

    test('VoucherCode, StoreProduct, and StoreOrder serialise and enforce positive invariants', () {
      final voucher = VoucherCode.fromJson(<String, dynamic>{
        'id': 'vouch_1',
        'code': 'tech-cancel-100',
        'discountAmountZar': 100,
        'minSpendZar': 350,
        'maxUses': 1,
        'currentUses': 0,
        'isActive': true,
        'issuedForReason': 'tech_cancellation',
      });

      expect(voucher.code, equals('TECH-CANCEL-100'));
      expect(voucher.canRedeem, isTrue);
      expect(VoucherCode.fromJson(voucher.toJson()).discountAmountZar, equals(100));

      final exhaustedVoucher = VoucherCode(
        id: 'vouch_2',
        code: 'USED100',
        discountAmountZar: 100,
        minSpendZar: 0,
        maxUses: 1,
        currentUses: 1,
      );
      expect(exhaustedVoucher.canRedeem, isFalse);

      final product = StoreProduct.fromJson(<String, dynamic>{
        'id': 'prod_biab_01',
        'sku': 'ABE-BIAB-ROSE-50ML',
        'name': 'Dusty Rose Builder Gel 50ml',
        'category': 'Gel & BIAB',
        'priceZar': 320,
        'stockQuantity': 25,
        'syncSource': 'supplier_api',
        'isAvailable': true,
      });

      expect(product.syncSource, equals(StoreInventorySyncSource.supplierApi));
      expect(StoreProduct.fromJson(product.toJson()).priceZar, equals(320));

      final order = StoreOrder.fromJson(<String, dynamic>{
        'id': 'ord_901',
        'techUserId': 'tech_01',
        'productIds': <String>['prod_biab_01'],
        'totalAmountZar': 320,
        'status': 'pending_fulfilment',
        'pargoPickupPointCode': 'PARGO-CPT-SEAPOINT-04',
      });

      expect(order.productIds, contains('prod_biab_01'));
      expect(
        StoreOrder.fromJson(order.toJson()).pargoPickupPointCode,
        equals('PARGO-CPT-SEAPOINT-04'),
      );
    });

    test('DisputeTicket and StaffAuditLog serialise 3-photo evidence and immutable audit fields', () {
      final dispute = DisputeTicket.fromJson(<String, dynamic>{
        'id': 'disp_01',
        'bookingId': 'book_550',
        'clientId': 'client_12',
        'techId': 'tech_01',
        'portfolioPhotoUrl': 'https://cdn.abe.co.za/portfolio/look1.jpg',
        'techLiveCompletionPhotoUrl': 'https://cdn.abe.co.za/live/complete1.jpg',
        'clientComplaintPhotoUrl': 'https://cdn.abe.co.za/disputes/complaint1.jpg',
        'clientReason': 'Shape differed from booked almond look \u2014 requested review.',
        'status': 'open',
        'resolutionNotes': 'Comparing 3-photo evidence in Admin portal.',
      });

      expect(dispute.clientReason.contains('\u2014'), isFalse);
      expect(
        DisputeTicket.fromJson(dispute.toJson()).techLiveCompletionPhotoUrl,
        equals('https://cdn.abe.co.za/live/complete1.jpg'),
      );

      final audit = StaffAuditLog.fromJson(<String, dynamic>{
        'id': 'audit_1001',
        'actorId': 'aqeelah_1',
        'actorUacGroup': 'ops_admin',
        'action': 'techs.award_pro',
        'targetId': 'tech_01',
        'timestampIso': '2026-11-14T18:00:00Z',
        'notes': 'Passed live Certified Pro assessment in Cape Town.',
      });

      expect(audit.action, equals('techs.award_pro'));
      expect(StaffAuditLog.fromJson(audit.toJson()).actorId, equals('aqeelah_1'));
    });
  });
}
