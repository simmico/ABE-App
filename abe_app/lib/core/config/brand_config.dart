import 'package:material_ui/material_ui.dart';

/// Central brand and aesthetic configuration for Aqeelah's Beauty Empire (ABE).
///
/// Holds the brand name, tagline, launch cities, asset paths, typography families,
/// and the official Warm Luxury ("Dusty Rose & Alabaster Studio") colour palette
/// so they can be managed from a single source of truth.
abstract final class BrandConfig {
  /// Full official brand name.
  static const String appName = "Aqeelah's Beauty Empire";

  /// Short brand monogram for compact badges and headers.
  static const String shortName = 'ABE';

  /// Official brand tagline in UK/South African English (zero em-dashes).
  static const String tagline =
      'Book the exact nail look you love. Verified studios in Cape Town and Johannesburg.';

  /// Venue safety statement displayed on discovery and booking screens.
  static const String venueSafetyStatement =
      'Every appointment takes place at a verified commercial studio or partner salon. '
      'No residential house calls are permitted.';

  /// Co-founder names for internal admin and brand credits.
  static const String founderBrandAndCptOps = 'Aqeelah';
  static const String founderTechAndJhbOps = 'Rio';

  /// Supported launch city codes and labels.
  static const List<String> launchCityCodes = <String>['CPT', 'JHB'];

  static const Map<String, String> cityDisplayNames = <String, String>{
    'CPT': 'Cape Town (CPT)',
    'JHB': 'Johannesburg (JHB)',
  };

  /// Asset paths (swappable in one place).
  static const String logoPrimaryAsset = 'assets/branding/abe_logo_primary.svg';
  static const String logoMonogramAsset = 'assets/branding/abe_monogram.svg';
  static const String certifiedProSealAsset =
      'assets/branding/certified_pro_seal.svg';

  /// Typography families.
  static const String headingFontFamily = 'Cormorant Garamond';
  static const String bodyFontFamily = 'Plus Jakarta Sans';

  // ---------------------------------------------------------------------------
  // Official ABE Colour Tokens ("Dusty Rose & Alabaster Studio")
  // ---------------------------------------------------------------------------

  /// Primary app scaffold background (warm alabaster cream, `#FAF6F5`).
  static const Color bgCream = Color(0xFFFAF6F5);

  /// Pure elevated card and sheet surface (`#FFFFFF`).
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Highlight backgrounds, active selection pills, and soft badges (`#F5E6E8`).
  static const Color blushSoft = Color(0xFFF5E6E8);

  /// Primary CTA buttons, active toggles, and progress fills (`#C87D87`).
  static const Color rosePrimary = Color(0xFFC87D87);

  /// Pressed states, high-contrast badge text, and interactive links (`#A65E68`).
  static const Color roseDark = Color(0xFFA65E68);

  /// Secondary accents, Certified Pro seal borders, and Salon Partner tags (`#B89278`).
  static const Color champagne = Color(0xFFB89278);

  /// Primary typography and contrast pills (`#2B2123`).
  static const Color espresso = Color(0xFF2B2123);

  /// Subtitles, durations, and secondary metadata (`#6E5A5D`).
  static const Color textMuted = Color(0xFF6E5A5D);

  /// 1px card borders and warm hairline dividers (`#EADCD9`).
  static const Color borderWarm = Color(0xFFEADCD9);

  /// Verified badges, PIN confirmation, and completed states (`#5E8C76`).
  static const Color sageSuccess = Color(0xFF5E8C76);

  /// Warm terracotta error colour for validation and dispute alerts (`#B85450`).
  static const Color errorTerracotta = Color(0xFFB85450);

  // ---------------------------------------------------------------------------
  // Component Radii & Shadows
  // ---------------------------------------------------------------------------

  static const double cardRadius = 18.0;
  static const double largeCardRadius = 22.0;
  static const double inputRadius = 14.0;
  static const double pillRadius = 999.0;

  /// Soft espresso elevation shadow (`rgba(43, 33, 35, 0.05)`).
  static const List<BoxShadow> softCardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D2B2123),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Platform fee percentage (15%) and cancellation split constants.
  static const double platformFeeRate = 0.15;
  static const double clientLateCancelWalletRefundRate = 0.75;
  static const double clientLateCancelTechCompensationRate = 0.25;
  static const double techCancelClientWalletRefundRate = 1.00;
}
