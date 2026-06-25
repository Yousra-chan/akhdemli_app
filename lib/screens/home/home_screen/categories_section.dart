import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/image_utils.dart';
import 'home_constants.dart';
import 'dart:ui' as ui;

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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    if (categories.isEmpty) return _buildEmptyState(context, lang);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryGridCard(
          category: category,
          index: index,
          lang: lang,
          onTap: () => _navigateToProviders(context, category, lang),
        );
      },
    );
  }

  // ── Empty state ───────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, LanguageProvider lang) {
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

// ──────────────────────────────────────────────────────────────
//  Category Grid Card — matches reference image
// ──────────────────────────────────────────────────────────────
class _CategoryGridCard extends StatelessWidget {
  final CategoryModel category;
  final int index;
  final LanguageProvider lang;
  final VoidCallback onTap;

  const _CategoryGridCard({
    required this.category,
    required this.index,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = getColorForCategory(category.name, index);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildVisual(color, isDark),
            ),
          ),
          const SizedBox(height: 8),
          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              category.getTranslatedName(lang),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF2D2D2D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisual(Color color, bool isDark) {
    if (category.iconUrl != null && category.iconUrl!.isNotEmpty) {
      if (ImageUtils.isBase64Image(category.iconUrl)) {
        final bytes = ImageUtils.decodeBase64Image(category.iconUrl);
        if (bytes != null) {
          return Image.memory(bytes,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _fallbackIcon(color, isDark));
        }
      } else {
        return CachedNetworkImage(
          imageUrl: category.iconUrl!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => _shimmer(),
          errorWidget: (_, __, ___) => _fallbackIcon(color, isDark),
        );
      }
    }
    return _fallbackIcon(color, isDark);
  }

  Widget _fallbackIcon(Color color, bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(category.icon, color: color, size: 36),
    );
  }

  Widget _shimmer() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE8E8E8),
    );
  }
}