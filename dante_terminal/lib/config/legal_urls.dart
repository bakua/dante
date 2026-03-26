/// Live URLs for privacy policy and terms of service (BL-197).
///
/// These pages are hosted on GitHub Pages from the `docs/` directory
/// and deployed automatically via `.github/workflows/deploy-pages.yml`
/// whenever files under `docs/` change on the main branch.
///
/// Both URLs are required by App Store Connect and Google Play Console
/// before store submission.
///
/// See also:
/// - BL-150: Privacy policy and terms of service HTML content
/// - BL-197: GitHub Pages deployment and URL verification
library;

/// Constants for legal document URLs used in store submissions and in-app links.
abstract final class LegalUrls {
  /// Base URL for the GitHub Pages site.
  static const String _baseUrl = 'https://bakua.github.io/dante';

  /// Privacy policy — required by both App Store and Google Play.
  static const String privacyPolicy = '$_baseUrl/privacy-policy.html';

  /// Terms of service — required by App Store, recommended by Google Play.
  static const String termsOfService = '$_baseUrl/terms-of-service.html';
}
