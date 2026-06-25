import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'home_constants.dart';

class SubcategoriesPage extends StatefulWidget {
  final CategoryModel selectedCategory;
  final VoidCallback onBackPressed;

  const SubcategoriesPage({
    super.key,
    required this.selectedCategory,
    required this.onBackPressed,
  });

  @override
  State<SubcategoriesPage> createState() => _SubcategoriesPageState();
}

class _SubcategoriesPageState extends State<SubcategoriesPage> {
  final TextEditingController _searchController = TextEditingController();

  List<SubcategoryModel> _subCategories = [];
  List<SubcategoryModel> _filteredSubCategories = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSubCategories() async {
    setState(() => _isLoading = true);

    if (widget.selectedCategory.subcategories.isNotEmpty) {
      if (mounted) {
        setState(() {
          _subCategories = widget.selectedCategory.subcategories;
          _filteredSubCategories = List.from(_subCategories);
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final subcategories = await FirebaseService.getSubcategoriesForCategory(
          widget.selectedCategory.id);
      if (mounted) {
        setState(() {
          _subCategories = subcategories;
          _filteredSubCategories = List.from(_subCategories);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subcategories: $e');
      if (mounted) {
        setState(() {
          _subCategories = [];
          _filteredSubCategories = [];
          _isLoading = false;
        });
      }
    }
  }

  void _filterSubCategories(String query) {
    setState(() {
      _searchQuery = query;
      _filteredSubCategories = query.isEmpty
          ? List.from(_subCategories)
          : _subCategories
          .where(
              (e) => e.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _onSubCategorySelected(SubcategoryModel subCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProvidersListPage(
          categoryName: widget.selectedCategory.name,
          subCategoryName: subCategory.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Directionality(
          textDirection:
          lang.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: _buildAppBar(lang),
            body: _isLoading
                ? const LoadingWidget()
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildSearchField(lang),
                ),
                // Count label
                if (_filteredSubCategories.isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text(
                      lang.trParams(
                        'services_count',
                        category: 'subcategories_page',
                        params: {
                          'count': _filteredSubCategories.length
                              .toString()
                        },
                      ),
                      style: const TextStyle(
                        color: Color(0xFF9B9B9B),
                        fontSize: 12,
                        fontFamily: 'Exo2',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Grid or empty
                Expanded(
                  child: _filteredSubCategories.isEmpty
                      ? _buildEmptyState(lang)
                      : _buildGrid(lang),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  AppBar _buildAppBar(LanguageProvider lang) {
    return AppBar(
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
        onPressed: widget.onBackPressed,
      ),
      title: Text(
        widget.selectedCategory.getTranslatedName(lang),
        style: const TextStyle(
          color: Color(0xFF2D2D2D),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Exo2',
        ),
      ),
    );
  }

  // ── Search field ──────────────────────────────────────────
  Widget _buildSearchField(LanguageProvider lang) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252529)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E0DA), width: 0.5),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterSubCategories,
        style: const TextStyle(
          color: Color(0xFF2D2D2D),
          fontSize: 14,
          fontFamily: 'Exo2',
        ),
        decoration: InputDecoration(
          hintText:
          lang.tr('search_services', category: 'subcategories_page'),
          hintStyle: const TextStyle(
            color: Color(0xFF9B9B9B),
            fontSize: 14,
            fontFamily: 'Exo2',
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF9B9B9B), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear,
                color: Color(0xFF9B9B9B), size: 18),
            onPressed: () {
              _searchController.clear();
              _filterSubCategories('');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────
  Widget _buildGrid(LanguageProvider lang) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredSubCategories.length,
      itemBuilder: (context, index) {
        final sub = _filteredSubCategories[index];
        return _SubGridCard(
          subCategory: sub,
          index: index,
          lang: lang,
          onTap: () => _onSubCategorySelected(sub),
        );
      },
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
            child: const Icon(Icons.search_off_rounded,
                size: 36, color: Color(0xFF2C5F8A)),
          ),
          const SizedBox(height: 16),
          Text(
            lang.tr('no_services_found',
                category: 'subcategories_page'),
            style: const TextStyle(
              color: Color(0xFF9B9B9B),
              fontSize: 15,
              fontFamily: 'Exo2',
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _filterSubCategories('');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EEF6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  lang.tr('clear_search',
                      category: 'subcategories_page'),
                  style: const TextStyle(
                    color: Color(0xFF2C5F8A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Sub-category grid card
// ──────────────────────────────────────────────────────────────
class _SubGridCard extends StatelessWidget {
  final SubcategoryModel subCategory;
  final int index;
  final LanguageProvider lang;
  final VoidCallback onTap;

  const _SubGridCard({
    required this.subCategory,
    required this.index,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = getColorForCategory(subCategory.name, index);
    final cardBg = isDark ? const Color(0xFF252529) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black26
                  : Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildVisual(color, isDark),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(
                subCategory.getTranslatedName(lang),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF2D2D2D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Exo2',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisual(Color color, bool isDark) {
    if (subCategory.imageUrl != null && subCategory.imageUrl!.isNotEmpty) {
      if (ImageUtils.isBase64Image(subCategory.imageUrl)) {
        final bytes = ImageUtils.decodeBase64Image(subCategory.imageUrl);
        if (bytes != null) {
          return Image.memory(bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _fallbackIcon(color, isDark));
        }
      } else {
        return CachedNetworkImage(
          imageUrl: subCategory.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => Container(color: const Color(0xFFE8E8E8)),
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
      child: Icon(subCategory.icon, color: color, size: 36),
    );
  }
}