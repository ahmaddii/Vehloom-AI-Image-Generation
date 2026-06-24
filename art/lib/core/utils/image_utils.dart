class ImageUtils {
  /// Returns a Supabase URL formatted to serve a smaller, optimized image.
  /// Note: This requires Supabase Image Transformations to be enabled.
  /// If it is not enabled, Supabase will fall back to returning the original image.
  static String getThumbnailUrl(String originalUrl, {int width = 400, int height = 400}) {
    if (originalUrl.contains('/storage/v1/object/public/')) {
      // Append Supabase transformation parameters
      return '$originalUrl?width=$width&height=$height&resize=cover';
    }
    return originalUrl;
  }
}
