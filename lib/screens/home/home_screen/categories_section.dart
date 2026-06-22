import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/providers/language_provider.dart';
import 'dart:ui' as ui;

// ─────────────────────────────────────────────────────────────
//  Soft Clarity – Category row palette
//  Each entry: [iconColor, chipBackground]
// ─────────────────────────────────────────────────────────────
const List<List<Color>> _kCategoryPalette = [
  [Color(0xFF2C5F8A), Color(0xFFE4EEF6)],
  [Color(0xFF3A7C6E), Color(0xFFE2F2EE)],
  [Color(0xFF6B4FA0), Color(0xFFEEEAF7)],
  [Color(0xFF9A5D1E), Color(0xFFF7EDE0)],
  [Color(0xFF963550), Color(0xFFF7E8ED)],
  [Color(0xFF3D7030), Color(0xFFE6F2E2)],
  [Color(0xFF2C6B8A), Color(0xFFE2EEF6)],
  [Color(0xFF7A4A1E), Color(0xFFF5EBDF)],
  [Color(0xFF1E6B6B), Color(0xFFDFF2F2)],
  [Color(0xFF4A6B1E), Color(0xFFEAF2DF)],
  [Color(0xFF8A2C2C), Color(0xFFF6E4E4)],
  [Color(0xFF7A5A1E), Color(0xFFF5EDE0)],
  [Color(0xFF2C4A8A), Color(0xFFE2E8F6)],
  [Color(0xFF1E6B4A), Color(0xFFDFF2EA)],
  [Color(0xFF8A5A1E), Color(0xFFF6EDE0)],
  [Color(0xFF5A5A5A), Color(0xFFEDEDED)],
];

List<Color> _paletteFor(int index) =>
    _kCategoryPalette[index % _kCategoryPalette.length];

class CategoriesPage extends StatelessWidget {
  final List<CategoryModel> categories;
  final UserModel? currentUser;

  const CategoriesPage({
    super.key,
    required this.categories,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F4F0),
            appBar: _buildAppBar(context, languageProvider),
            body: _buildBody(context, languageProvider),
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context, LanguageProvider lang) {
    return AppBar(
      title: Text(
        lang.tr('all_categories', category: 'home_categories'),
        style: const TextStyle(
          color: Color(0xFF2D2D2D),
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: 'Exo2',
        ),
      ),
      backgroundColor: const Color(0xFFFAFAF8),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFE2E0DA)),
      ),
      leading: IconButton(
        icon: Icon(
          lang.isRtl
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_rounded,
          color: const Color(0xFF2D2D2D),
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, LanguageProvider lang) {
    if (categories.isEmpty) {
      return _buildEmptyState(lang);
    }

    // Two-column row grid — each column is a vertical list of rows
    // We split the categories into two columns
    final int half = (categories.length / 2).ceil();
    final left = categories.sublist(0, half);
    final right = categories.sublist(half);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column
          Expanded(
            child: Column(
              children: List.generate(
                left.length,
                    (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCategoryRow(
                      context, left[i], i * 2, lang),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right column
          Expanded(
            child: Column(
              children: List.generate(
                right.length,
                    (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCategoryRow(
                      context, right[i], i * 2 + 1, lang),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Single category row pill ──────────────────────────────
  Widget _buildCategoryRow(
      BuildContext context,
      CategoryModel category,
      int index,
      LanguageProvider lang,
      ) {
    final palette = _paletteFor(index);
    final iconColor = palette[0];
    final chipBg = palette[1];

    return GestureDetector(
      onTap: () => _navigateToProviders(context, category, lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E0DA), width: 0.5),
        ),
        child: Row(
          children: [
            // Icon chip
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Text(
                category.getTranslatedName(lang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            // Chevron
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: Color(0xFFB0B0B0),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────
  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE4EEF6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.category_outlined,
                size: 36, color: Color(0xFF2C5F8A)),
          ),
          const SizedBox(height: 16),
          Text(
            lang.tr('no_categories_found', category: 'home_categories'),
            style: const TextStyle(
              color: Color(0xFF9B9B9B),
              fontSize: 15,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProviders(
      BuildContext context, CategoryModel category, LanguageProvider lang) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(
          categoryName: category.name,
          subCategoryName:
          lang.tr('all_services', category: 'home_categories'),
        ),
      ),
    );
  }
}
