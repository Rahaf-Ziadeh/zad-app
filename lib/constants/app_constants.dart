class AppConstants {
  /// Fallback image for mystery packages when no custom image is uploaded.
  static const String defaultMysteryPackageImageUrl =
      'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da'
      '?w=800&auto=format&fit=crop&q=75';

  static const List<String> allergenOptions = [
    'حليب',
    'بيض',
    'مكسرات',
    'سمسم',
    'غلوتين',
    'فول سوداني',
    'أسماك',
    'محار',
    'صويا',
    'لا يحتوي على مسببات حساسية معروفة',
  ];

  static const String noKnownAllergens =
      'لا يحتوي على مسببات حساسية معروفة';

  /// Parses allergyInfo from any Firestore format into a displayable list.
  /// Handles `List<dynamic>` (new format) and `String` (legacy).
  static List<String> parseAllergyInfo(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return [];
  }

  /// Returns only allergens that match known checkbox options — used for
  /// pre-populating the checkbox panel in EditOfferScreen.
  static Set<String> parseAllergyCheckboxes(dynamic raw) {
    final all = parseAllergyInfo(raw);
    final known = allergenOptions.toSet();
    return all.where(known.contains).toSet();
  }

  static const List<String> foodCategories = [
    'وجبات',
    'مخبوزات',
    'خضار وفواكه',
    'معلبات',
    'حلويات',
    'أخرى',
  ];
}
