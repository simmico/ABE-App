import '../../../../core/utils/input_sanitiser.dart';

/// Immutable specification for a cropped and compressed `4:5` (`0.80` aspect ratio)
/// nail portfolio photograph prepared for `TechPortfolioUploadScreen`.
class CroppedPortfolioImageSpec {
  const CroppedPortfolioImageSpec({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
    required this.targetWidth,
    required this.targetHeight,
    required this.recommendedQualityPercent,
    required this.recommendedFormat,
  });

  /// Original width of the uploaded photograph in pixels.
  final int sourceWidth;

  /// Original height of the uploaded photograph in pixels.
  final int sourceHeight;

  /// Horizontal origin of the centred `4:5` crop rectangle in source pixels.
  final int cropX;

  /// Vertical origin of the centred `4:5` crop rectangle in source pixels.
  final int cropY;

  /// Width of the centred `4:5` crop rectangle in source pixels.
  final int cropWidth;

  /// Height of the centred `4:5` crop rectangle in source pixels.
  final int cropHeight;

  /// Output width in pixels after scaling (capped at `1080px`).
  final int targetWidth;

  /// Output height in pixels after scaling (capped at `1350px`).
  final int targetHeight;

  /// Recommended JPEG/WebP quality percentage (`1` to `100`) for crisp nail detail.
  final int recommendedQualityPercent;

  /// Recommended output image encoding format (for example `'webp'` or `'jpeg'`).
  final String recommendedFormat;

  /// Computed aspect ratio (`cropWidth / cropHeight`), targeting `0.80` (`4:5`).
  double get aspectRatio => cropHeight == 0 ? 0.0 : cropWidth / cropHeight;

  /// True when the source image required no cropping (`cropX == 0 && cropY == 0`).
  bool get wasAlreadyFourByFive =>
      cropX == 0 &&
      cropY == 0 &&
      cropWidth == sourceWidth &&
      cropHeight == sourceHeight;

  /// True when the cropped rectangle was downscaled to fit within `1080x1350`.
  bool get wasDownscaled =>
      targetWidth < cropWidth || targetHeight < cropHeight;

  /// Human-readable summary written in UK/South African English for UI badges.
  String get formattedSummary =>
      '4:5 Studio Crop ($targetWidth×${targetHeight}px • $recommendedQualityPercent% $recommendedFormat)';
}

/// Deterministic client-side `4:5` (`0.80` aspect ratio) image cropping and
/// compression metadata helper for `TechPortfolioUploadScreen`.
///
/// Guarantees that any uploaded nail photograph (portrait `9:16`, square `1:1`,
/// landscape `4:3`, or native `4:5`) is centred and cropped cleanly to fit the
/// signature ABE Visual Contract card frame without geometric distortion.
abstract final class PortfolioImageCropHelper {
  /// Signature Visual Contract aspect ratio (`4 / 5 = 0.80`).
  static const double targetAspectRatio = 4.0 / 5.0;

  /// Maximum output width in pixels for uploaded portfolio photos.
  static const int maxTargetWidthPx = 1080;

  /// Maximum output height in pixels for uploaded portfolio photos (`1080 * 5 / 4 = 1350`).
  static const int maxTargetHeightPx = 1350;

  /// Calculates the centred `4:5` crop rectangle, capped output dimensions
  /// (`<= 1080x1350`), and recommended compression quality for any valid source
  /// image width and height.
  ///
  /// Throws an [ArgumentError] via [InputSanitiser] if [sourceWidth] or
  /// [sourceHeight] is zero, negative, NaN, or infinite, or if either dimension
  /// is smaller than `5` pixels (minimum required for an exact `4:5` integer grid).
  static CroppedPortfolioImageSpec calculateFourByFiveCrop({
    required num sourceWidth,
    required num sourceHeight,
    String preferredFormat = 'webp',
  }) {
    final validWidth = InputSanitiser.requireNonNegativeInt(
      sourceWidth,
      fieldName: 'sourceWidth',
      strictlyPositive: true,
    );
    final validHeight = InputSanitiser.requireNonNegativeInt(
      sourceHeight,
      fieldName: 'sourceHeight',
      strictlyPositive: true,
    );

    if (validWidth < 4 || validHeight < 5) {
      throw ArgumentError(
        'Source image dimensions (${validWidth}x$validHeight) are too small for a 4:5 studio crop.',
      );
    }

    final sanitisedFormat = InputSanitiser.sanitiseText(
      preferredFormat,
      maxLength: 16,
    ).toLowerCase();
    final resolvedFormat =
        (sanitisedFormat == 'jpeg' || sanitisedFormat == 'jpg')
            ? 'jpeg'
            : 'webp';

    // Determine the largest 4:5 integer rectangle (4k x 5k) that fits inside
    // validWidth x validHeight so that aspect ratio is strictly 4:5 (0.80).
    // Compare sourceWidth * 5 vs sourceHeight * 4 to avoid floating-point drift.
    final int cropWidth;
    final int cropHeight;

    if (validWidth * 5 == validHeight * 4) {
      // Already exact 4:5 aspect ratio
      cropWidth = validWidth;
      cropHeight = validHeight;
    } else if (validWidth * 5 > validHeight * 4) {
      // Source is wider than 4:5 (e.g. square 1:1 or landscape 4:3).
      // Constrain by height, rounding down to a multiple of 5 so width is an exact integer.
      final scaleUnit = validHeight ~/ 5;
      cropHeight = scaleUnit * 5;
      cropWidth = scaleUnit * 4;
    } else {
      // Source is taller/narrower than 4:5 (e.g. portrait 9:16).
      // Constrain by width, rounding down to a multiple of 4 so height is an exact integer.
      final scaleUnit = validWidth ~/ 4;
      cropWidth = scaleUnit * 4;
      cropHeight = scaleUnit * 5;
    }

    // Centre the crop box inside the source frame.
    final cropX = (validWidth - cropWidth) ~/ 2;
    final cropY = (validHeight - cropHeight) ~/ 2;

    // Cap output dimensions at 1080x1350 whilst preserving the exact 4:5 ratio.
    final int targetWidth;
    final int targetHeight;
    if (cropWidth > maxTargetWidthPx || cropHeight > maxTargetHeightPx) {
      targetWidth = maxTargetWidthPx;
      targetHeight = maxTargetHeightPx;
    } else {
      targetWidth = cropWidth;
      targetHeight = cropHeight;
    }

    final quality = _recommendQualityPercent(
      cropWidth: cropWidth,
      cropHeight: cropHeight,
    );

    return CroppedPortfolioImageSpec(
      sourceWidth: validWidth,
      sourceHeight: validHeight,
      cropX: cropX,
      cropY: cropY,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      recommendedQualityPercent: quality,
      recommendedFormat: resolvedFormat,
    );
  }

  /// Selects an adaptive compression quality percentage based on cropped pixel area:
  /// - High-resolution studio photos (`>= 1080x1350`): `82%` (balances crisp cuticle/art detail and fast feed loading).
  /// - Mid-resolution photos (`>= 720x900`): `86%`.
  /// - Smaller photos (`< 720x900`): `90%` (avoids compression artefacts on lower-pixel sources).
  static int _recommendQualityPercent({
    required int cropWidth,
    required int cropHeight,
  }) {
    final croppedPixels = cropWidth * cropHeight;
    if (croppedPixels >= maxTargetWidthPx * maxTargetHeightPx) {
      return 82;
    }
    if (croppedPixels >= 720 * 900) {
      return 86;
    }
    return 90;
  }
}
