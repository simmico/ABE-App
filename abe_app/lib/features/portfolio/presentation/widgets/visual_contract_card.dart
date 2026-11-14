import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../domain/models/visual_contract_item.dart';

/// Signature ABE "Visual Contract" Card Widget.
///
/// Displays:
/// 1. Crisp `4:5` aspect-ratio nail photography (with graceful warm studio artwork fallback).
/// 2. Top-left Merit Badge pill (*Rising Tech*, *Verified Tech*, or *Certified Pro ★*
///    in Champagne / Rose Gold).
/// 3. Bottom cream/glass contract bar with hard-coded **Base Price (`R450`)**,
///    **Exact Duration (`90 mins`)**, and **Verified Salon Venue tag**.
class VisualContractCard extends StatelessWidget {
  const VisualContractCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final VisualContractItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      label:
          '${item.title} by ${item.techDisplayName}, ${item.techTierBadge.label}, '
          'base price ${item.formattedBasePrice}, duration ${item.formattedBaseDuration}, '
          'at ${item.venueName} (${item.city})',
      child: Container(
        decoration: BoxDecoration(
          color: BrandConfig.surfaceCard,
          borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
          border: Border.all(color: BrandConfig.borderWarm),
          boxShadow: BrandConfig.softCardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _NailPhotographyCanvas(item: item),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _MeritTierBadgePill(
                          badge: item.techTierBadge,
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _CityPill(cityCode: item.city),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: _BottomVisualContractBar(item: item),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: BrandConfig.headingFontFamily,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: BrandConfig.espresso,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: BrandConfig.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.techDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BrandConfig.espresso,
                              ),
                            ),
                          ),
                          if (item.allowedModifiers.isNotEmpty)
                            Text(
                              '+${item.allowedModifiers.length} add-ons',
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BrandConfig.roseDark,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeritTierBadgePill extends StatelessWidget {
  const _MeritTierBadgePill({required this.badge});

  final TechTierBadge badge;

  @override
  Widget build(BuildContext context) {
    final bool isCertifiedPro = badge == TechTierBadge.certifiedPro;
    final bool isVerified = badge == TechTierBadge.verified;

    final Color bgColor = isCertifiedPro
        ? BrandConfig.espresso
        : (isVerified ? BrandConfig.surfaceCard : BrandConfig.blushSoft);
    final Color borderColor = isCertifiedPro
        ? BrandConfig.champagne
        : (isVerified ? BrandConfig.sageSuccess : BrandConfig.borderWarm);
    final Color textColor =
        isCertifiedPro ? BrandConfig.surfaceCard : BrandConfig.espresso;

    return Container(
      key: Key('merit_badge_${badge.code}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
        border: Border.all(
          color: borderColor,
          width: isCertifiedPro ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isCertifiedPro
                ? Icons.workspace_premium
                : (isVerified ? Icons.verified : Icons.auto_awesome),
            size: 13,
            color: isCertifiedPro
                ? BrandConfig.champagne
                : (isVerified ? BrandConfig.sageSuccess : BrandConfig.roseDark),
          ),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityPill extends StatelessWidget {
  const _CityPill({required this.cityCode});

  final String cityCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEBFAF6F5),
        borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Text(
        cityCode,
        style: const TextStyle(
          fontFamily: BrandConfig.bodyFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: BrandConfig.espresso,
        ),
      ),
    );
  }
}

class _BottomVisualContractBar extends StatelessWidget {
  const _BottomVisualContractBar({required this.item});

  final VisualContractItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('visual_contract_bottom_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF5FAF6F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BrandConfig.espresso,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  item.formattedBasePrice,
                  key: const Key('contract_base_price'),
                  style: const TextStyle(
                    fontFamily: BrandConfig.bodyFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BrandConfig.surfaceCard,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: BrandConfig.espresso,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.formattedBaseDuration,
                    key: const Key('contract_base_duration'),
                    style: const TextStyle(
                      fontFamily: BrandConfig.bodyFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BrandConfig.espresso,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(
                Icons.storefront_outlined,
                size: 13,
                color: BrandConfig.sageSuccess,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${item.venueName} • ${item.venueType.label}',
                  key: const Key('contract_venue_tag'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: BrandConfig.bodyFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BrandConfig.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NailPhotographyCanvas extends StatelessWidget {
  const _NailPhotographyCanvas({required this.item});

  final VisualContractItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            BrandConfig.blushSoft,
            Color(0xFFEED5D9),
            Color(0xFFE5C8C0),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xD9FFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: BrandConfig.borderWarm),
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: BrandConfig.roseDark,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                item.styleCategory,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: BrandConfig.bodyFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: BrandConfig.espresso,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
