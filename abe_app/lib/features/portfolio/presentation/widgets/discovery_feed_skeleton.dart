import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';

/// Warm Luxury shimmer loading skeleton card for the Visual Contract Discovery Feed.
///
/// Mirrors the 4:5 aspect ratio and layout of `VisualContractCard` using the
/// Dusty Rose and Alabaster Studio palette (`BrandConfig.bgCream`,
/// `BrandConfig.surfaceCard`, `BrandConfig.blushSoft`, `BrandConfig.rosePrimary`,
/// and `BrandConfig.borderWarm`).
class DiscoveryFeedSkeletonCard extends StatefulWidget {
  const DiscoveryFeedSkeletonCard({
    super.key,
    this.shimmerCycles = 2,
  });

  /// Number of shimmer sweep cycles before settling so automated widget tests
  /// using `pumpAndSettle` complete deterministically without timing out.
  final int shimmerCycles;

  @override
  State<DiscoveryFeedSkeletonCard> createState() =>
      _DiscoveryFeedSkeletonCardState();
}

class _DiscoveryFeedSkeletonCardState extends State<DiscoveryFeedSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _completedCycles = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.shimmerCycles > 0) {
      _controller.addStatusListener(_handleAnimationStatus);
      _controller.forward();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      _completedCycles += 1;
      if (_completedCycles < widget.shimmerCycles) {
        _controller.reverse();
      }
    } else if (status == AnimationStatus.dismissed) {
      if (_completedCycles < widget.shimmerCycles) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading Visual Contract nail look card',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          final Color shimmerBase = Color.lerp(
            BrandConfig.blushSoft,
            BrandConfig.bgCream,
            t * 0.65,
          )!;
          final Color shimmerHighlight = Color.lerp(
            BrandConfig.bgCream,
            BrandConfig.rosePrimary.withValues(alpha: 0.22),
            t,
          )!;

          return Container(
            decoration: BoxDecoration(
              color: BrandConfig.surfaceCard,
              borderRadius: BorderRadius.circular(BrandConfig.largeCardRadius),
              border: Border.all(color: BrandConfig.borderWarm),
              boxShadow: BrandConfig.softCardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 4:5 Hero Photography Skeleton Area with Top Badge & Bottom Bar
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + (t * 0.8), -0.8),
                        end: Alignment(0.6 + (t * 0.8), 0.9),
                        colors: <Color>[
                          shimmerBase,
                          shimmerHighlight,
                          shimmerBase,
                        ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Top-left Tier Badge placeholder pill
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _SkeletonPill(
                            width: 108,
                            height: 26,
                            color: BrandConfig.surfaceCard.withValues(
                              alpha: 0.85,
                            ),
                            borderColor: BrandConfig.borderWarm,
                          ),
                        ),
                        // Top-right Style Category placeholder pill
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _SkeletonPill(
                            width: 68,
                            height: 24,
                            color: BrandConfig.surfaceCard.withValues(
                              alpha: 0.85,
                            ),
                            borderColor: BrandConfig.borderWarm,
                          ),
                        ),
                        // Bottom stamped Visual Contract bar placeholder
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: BrandConfig.bgCream.withValues(
                                alpha: 0.94,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: BrandConfig.borderWarm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    _SkeletonPill(
                                      width: 64,
                                      height: 18,
                                      color: shimmerHighlight,
                                    ),
                                    const SizedBox(height: 6),
                                    _SkeletonPill(
                                      width: 52,
                                      height: 12,
                                      color: shimmerBase,
                                    ),
                                  ],
                                ),
                                _SkeletonPill(
                                  width: 78,
                                  height: 24,
                                  color: BrandConfig.blushSoft,
                                  borderColor: BrandConfig.rosePrimary
                                      .withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Card Details Body Placeholder
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SkeletonPill(
                        width: 190,
                        height: 16,
                        color: shimmerHighlight,
                      ),
                      const SizedBox(height: 8),
                      _SkeletonPill(
                        width: 140,
                        height: 13,
                        color: shimmerBase,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _SkeletonPill(
                            width: 18,
                            height: 18,
                            color: BrandConfig.rosePrimary.withValues(
                              alpha: 0.28,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SkeletonPill(
                              width: double.infinity,
                              height: 12,
                              color: shimmerBase,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Responsive grid of [DiscoveryFeedSkeletonCard] widgets shown while the
/// Visual Contract Discovery Feed is fetching verified looks.
class DiscoveryFeedSkeletonGrid extends StatelessWidget {
  const DiscoveryFeedSkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.crossAxisCount = 2,
  });

  final int itemCount;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('discovery_feed_skeleton_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.56,
      ),
      itemBuilder: (BuildContext context, int index) {
        return DiscoveryFeedSkeletonCard(
          key: Key('discovery_feed_skeleton_card_$index'),
        );
      },
    );
  }
}

/// Editorial Warm Luxury empty-state illustration widget displayed when no
/// Visual Contract nail looks match the active city, style, or price filter.
class DiscoveryEmptyStateIllustration extends StatelessWidget {
  const DiscoveryEmptyStateIllustration({
    super.key,
    this.title = 'No matching nail looks found',
    this.message =
        'Try broadening your style or price filters to explore more verified studios in Cape Town and Johannesburg.',
    this.actionLabel = 'Reset All Filters',
    this.onResetFilters,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('discovery_empty_state_illustration'),
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: BrandConfig.surfaceCard,
          borderRadius: BorderRadius.circular(BrandConfig.largeCardRadius),
          border: Border.all(color: BrandConfig.borderWarm),
          boxShadow: BrandConfig.softCardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Editorial layered medallion illustration in Dusty Rose & Alabaster
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrandConfig.blushSoft,
                      border: Border.all(
                        color: BrandConfig.borderWarm,
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrandConfig.bgCream,
                      border: Border.all(
                        color: BrandConfig.rosePrimary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      size: 28,
                      color: BrandConfig.rosePrimary,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: BrandConfig.rosePrimary,
                        borderRadius: BorderRadius.circular(
                          BrandConfig.pillRadius,
                        ),
                      ),
                      child: const Text(
                        'CPT • JHB',
                        style: TextStyle(
                          fontFamily: BrandConfig.bodyFontFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: BrandConfig.surfaceCard,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: BrandConfig.headingFontFamily,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: BrandConfig.espresso,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: BrandConfig.bodyFontFamily,
                fontSize: 14,
                height: 1.5,
                color: BrandConfig.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BrandConfig.bgCream,
                borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                border: Border.all(color: BrandConfig.borderWarm),
              ),
              child: const Text(
                'Verified studio & partner salon bookings only',
                style: TextStyle(
                  fontFamily: BrandConfig.bodyFontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: BrandConfig.textMuted,
                ),
              ),
            ),
            if (onResetFilters != null) ...<Widget>[
              const SizedBox(height: 22),
              ElevatedButton(
                key: const Key('discovery_empty_state_reset_button'),
                onPressed: onResetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandConfig.rosePrimary,
                  foregroundColor: BrandConfig.surfaceCard,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontFamily: BrandConfig.bodyFontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({
    required this.width,
    required this.height,
    required this.color,
    this.borderColor,
  });

  final double width;
  final double height;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
    );
  }
}
