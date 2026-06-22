import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/Services/firebase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Soft Clarity – Subcategory row palette
//  Each entry: [iconColor, chipBackground]
// ─────────────────────────────────────────────────────────────
const List<List<Color>> _kSubPalette = [
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

List<Color> _subPaletteFor(int index) =>
    _kSubPalette[index % _kSubPalette.length];

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
    
    // Check if subcategories are already provided in the category object
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

    // Otherwise fetch from Firestore
    try {
      final subcategories = await FirebaseService.getSubcategoriesForCategory(widget.selectedCategory.id);
      
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
          .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
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
            backgroundColor: const Color(0xFFF5F4F0),
            appBar: _buildAppBar(lang),
            body: _isLoading
                ? const LoadingWidget()
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Search ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildSearchField(lang),
                ),
                // ── Count label ─────────────────────
                if (_filteredSubCategories.isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                // ── List or empty ───────────────────
                Expanded(
                  child: _filteredSubCategories.isEmpty
                      ? _buildEmptyState(lang)
                      : _buildTwoColumnList(lang),
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
        color: const Color(0xFFFAFAF8),
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
          hintText: lang.tr('search_services', category: 'subcategories_page'),
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

  // ── Two-column row list ───────────────────────────────────
  Widget _buildTwoColumnList(LanguageProvider lang) {
    final int half = (_filteredSubCategories.length / 2).ceil();
    final left = _filteredSubCategories.sublist(0, half);
    final right = _filteredSubCategories.sublist(half);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                  child: _buildSubRow(i * 2, left[i], lang),
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
                  child: _buildSubRow(i * 2 + 1, right[i], lang),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Single subcategory row pill ───────────────────────────
  Widget _buildSubRow(
      int index, SubcategoryModel subCategory, LanguageProvider lang) {
    final palette = _subPaletteFor(index);
    final iconColor = palette[0];
    final chipBg = palette[1];

    return GestureDetector(
      onTap: () => _onSubCategorySelected(subCategory),
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
              child: Icon(subCategory.icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Text(
                subCategory.getTranslatedName(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                  height: 1.3,
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
            child: const Icon(Icons.search_off_rounded,
                size: 36, color: Color(0xFF2C5F8A)),
          ),
          const SizedBox(height: 16),
          Text(
            lang.tr('no_services_found', category: 'subcategories_page'),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EEF6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  lang.tr('clear_search', category: 'subcategories_page'),
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
