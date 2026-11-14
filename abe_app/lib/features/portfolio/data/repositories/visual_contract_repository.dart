import '../../../../core/utils/input_sanitiser.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../../venue/domain/models/commercial_venue.dart';
import '../../domain/models/visual_contract_item.dart';
import '../../presentation/screens/discovery_feed_screen.dart';
import '../../presentation/screens/tech_portfolio_upload_screen.dart';

/// Repository layer for reading and publishing [VisualContractItem] records.
///
/// Enforces ABE business and security invariants:
/// 1. XSS and HTML tag sanitisation on all string inputs (zero em-dashes).
/// 2. Realistic price bounds (`R150` to `R5,000`) and duration bounds (`30` to `300 mins`).
/// 3. Strict Venue-Only Policy (Zero House Calls): every published Visual Contract
///    must reference an active, verified commercial studio or partner salon.
class VisualContractRepository {
  VisualContractRepository({
    List<VisualContractItem>? initialItems,
    List<CommercialVenue>? verifiedVenues,
  })  : _items = List<VisualContractItem>.of(
          initialItems ?? DiscoveryFeedScreen.buildDefaultSeedCatalog(),
        ),
        _venues = List<CommercialVenue>.of(
          verifiedVenues ?? TechPortfolioUploadScreen.defaultVerifiedVenues(),
        );

  static const int minBasePriceZar = 150;
  static const int maxBasePriceZar = 5000;
  static const int minBaseDurationMinutes = 30;
  static const int maxBaseDurationMinutes = 300;

  final List<VisualContractItem> _items;
  final List<CommercialVenue> _venues;

  /// Returns an unmodifiable snapshot of all published Visual Contracts.
  List<VisualContractItem> get items => List<VisualContractItem>.unmodifiable(_items);

  /// Returns an unmodifiable snapshot of all verified commercial venues.
  List<CommercialVenue> get verifiedVenues => List<CommercialVenue>.unmodifiable(
        _venues.where((v) => v.isVerified),
      );

  /// Validates, sanitises, and persists a new [VisualContractItem].
  ///
  /// Throws an [ArgumentError] if any business or security invariant is violated.
  VisualContractItem createVisualContract({
    String? id,
    required String techId,
    required String techDisplayName,
    required TechTierBadge techTierBadge,
    required String photoUrl,
    required String title,
    required num basePriceZar,
    required num baseDurationMinutes,
    required String venueId,
    String styleCategory = 'BIAB & Structured Gel',
    List<ContractModifier> allowedModifiers = const <ContractModifier>[],
  }) {
    final sanitisedTitle = InputSanitiser.sanitiseText(title, maxLength: 140);
    if (sanitisedTitle.length < 4) {
      throw ArgumentError.value(
        title,
        'title',
        'Visual Contract title must be at least 4 characters after sanitisation.',
      );
    }

    final sanitisedPhotoUrl =
        InputSanitiser.sanitiseText(photoUrl, maxLength: 500);
    if (sanitisedPhotoUrl.isEmpty) {
      throw ArgumentError.value(
        photoUrl,
        'photoUrl',
        'A valid studio photo URL is required.',
      );
    }

    final validPrice = InputSanitiser.requireNonNegativeInt(
      basePriceZar,
      fieldName: 'basePriceZar',
      strictlyPositive: true,
    );
    if (validPrice < minBasePriceZar || validPrice > maxBasePriceZar) {
      throw ArgumentError.value(
        basePriceZar,
        'basePriceZar',
        'Base price must be between R$minBasePriceZar and R$maxBasePriceZar.',
      );
    }

    final validDuration = InputSanitiser.requireNonNegativeInt(
      baseDurationMinutes,
      fieldName: 'baseDurationMinutes',
      strictlyPositive: true,
    );
    if (validDuration < minBaseDurationMinutes ||
        validDuration > maxBaseDurationMinutes) {
      throw ArgumentError.value(
        baseDurationMinutes,
        'baseDurationMinutes',
        'Base duration must be between $minBaseDurationMinutes and $maxBaseDurationMinutes minutes.',
      );
    }

    final sanitisedVenueId =
        InputSanitiser.sanitiseText(venueId, maxLength: 128);
    CommercialVenue? matchedVenue;
    for (final venue in _venues) {
      if (venue.id == sanitisedVenueId) {
        matchedVenue = venue;
        break;
      }
    }

    if (matchedVenue == null || !matchedVenue.isVerified) {
      throw ArgumentError.value(
        venueId,
        'venueId',
        'Strict Venue-Only Policy: Visual Contract must reference a verified commercial studio or partner salon. No residential house calls are permitted.',
      );
    }

    final lowerTitle = sanitisedTitle.toLowerCase();
    if (lowerTitle.contains('house call') ||
        lowerTitle.contains('home visit') ||
        lowerTitle.contains('mobile tech')) {
      throw ArgumentError.value(
        title,
        'title',
        'Strict Venue-Only Policy: House calls and home visits are not permitted on ABE.',
      );
    }

    final resolvedId = (id != null && id.trim().isNotEmpty)
        ? InputSanitiser.sanitiseText(id, maxLength: 128)
        : 'vc_${matchedVenue.city.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

    final item = VisualContractItem(
      id: resolvedId,
      techId: techId,
      techDisplayName: techDisplayName,
      techTierBadge: techTierBadge,
      photoUrl: sanitisedPhotoUrl,
      title: sanitisedTitle,
      basePriceZar: validPrice,
      baseDurationMinutes: validDuration,
      city: matchedVenue.city,
      venueId: matchedVenue.id,
      venueName: matchedVenue.name,
      venueType: matchedVenue.type,
      styleCategory: styleCategory,
      allowedModifiers: allowedModifiers,
    );

    _items.insert(0, item);
    return item;
  }
}
