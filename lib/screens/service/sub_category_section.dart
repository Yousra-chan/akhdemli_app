import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/Services/firebase_service.dart';

class SubcategorySection extends StatefulWidget {
  final CategoryModel? selectedCategory;
  final Function(SubcategoryModel) onSubcategorySelected;
  final String? initialSubcategoryId;

  const SubcategorySection({
    super.key,
    required this.selectedCategory,
    required this.onSubcategorySelected,
    this.initialSubcategoryId,
  });

  @override
  State<SubcategorySection> createState() => _SubcategorySectionState();
}

class _SubcategorySectionState extends State<SubcategorySection> {
  String? _selectedSubcategoryId;
  List<SubcategoryModel> _subcategories = [];
  StreamSubscription? _subscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSubcategoryId = widget.initialSubcategoryId;
    _loadSubcategories();
  }

  @override
  void didUpdateWidget(SubcategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection and reload when category changes, UNLESS it's the first load with initial ID
    if (widget.selectedCategory?.id != oldWidget.selectedCategory?.id) {
      if (oldWidget.selectedCategory != null) {
        setState(() {
          _selectedSubcategoryId = null;
          _subcategories = [];
        });
      }
      _loadSubcategories();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadSubcategories() {
    _subscription?.cancel();
    if (widget.selectedCategory == null) return;

    setState(() => _isLoading = true);
    _subscription = FirebaseService.getSubCategories(widget.selectedCategory!.id)
        .listen((subcategories) {
      if (mounted) {
        setState(() {
          _subcategories = subcategories;
          _isLoading = false;
          
          if (_selectedSubcategoryId != null && _subcategories.isNotEmpty) {
            try {
              final initialSub = _subcategories.firstWhere((s) => s.id == _selectedSubcategoryId);
              widget.onSubcategorySelected(initialSub);
            } catch (e) {
              // Initial subcategory not found in this category's list
            }
          }
        });
      }
    });
  }

  void _selectSubcategory(SubcategoryModel subcategory) {
    setState(() {
      _selectedSubcategoryId = subcategory.id;
    });
    widget.onSubcategorySelected(subcategory);
  }

  Widget _buildHeader(LanguageProvider lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.tr('service_subcategory', category: 'service'),
              style: TextStyle(
                color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
                letterSpacing: -0.5,
              ),
            ),
            if (widget.selectedCategory != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                ),
                child: Text(
                  lang.trParams('subcategory_count',
                      category: 'service',
                      params: {
                        'count': _subcategories.length.toString()
                      }),
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.selectedCategory != null
              ? lang.trParams(
                  'service_subcategory_desc_select',
                  category: 'service',
                  params: {
                    'category': widget.selectedCategory!
                        .getTranslatedName(lang)
                        .toLowerCase()
                  },
                )
              : lang.tr('service_subcategory_desc_no_select',
                  category: 'service'),
          style: TextStyle(
            color: isDark ? Colors.white54 : kMutedTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Exo2',
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategoriesList(LanguageProvider lang) {
    final theme = Theme.of(context);
    if (widget.selectedCategory == null) {
      return _buildEmptyState(
        theme,
        icon: CupertinoIcons.square_grid_2x2,
        title: lang.tr('select_category', category: 'service'),
        message: lang.tr('select_category_desc', category: 'service'),
      );
    }

    if (_isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_subcategories.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: CupertinoIcons.infinite,
        title: lang.tr('no_subcategories', category: 'service'),
        message: lang.trParams(
          'no_subcategories_desc',
          category: 'service',
          params: {
            'category': widget.selectedCategory!.getTranslatedName(lang)
          },
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _subcategories.length,
        itemBuilder: (context, index) {
          final subcategory = _subcategories[index];
          final isSelected = _selectedSubcategoryId == subcategory.id;
          final colors = _getSubcategoryColors(index);

          return Container(
            margin: const EdgeInsetsDirectional.only(end: 16),
            child: _buildSubcategoryItem(
              subcategory,
              colors,
              isSelected,
              index,
              lang,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: isDark ? Colors.white24 : kMutedTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: theme.textTheme.titleMedium?.color ?? kDarkTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white54 : kMutedTextColor,
                fontSize: 14,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryItem(
    SubcategoryModel subcategory,
    List<Color> colors,
    bool isSelected,
    int index,
    LanguageProvider lang,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isSelected ? 100 : 90,
      child: GestureDetector(
        onTap: () => _selectSubcategory(subcategory),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 70 : 64,
              height: isSelected ? 70 : 64,
              decoration: BoxDecoration(
                color: isSelected ? colors[0] : theme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors[0] : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: colors[0].withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Icon(
                subcategory.icon,
                color: isSelected ? Colors.white : colors[0],
                size: isSelected ? 28 : 24,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                subcategory.getTranslatedName(lang),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colors[0] : theme.textTheme.bodyLarge?.color,
                  fontSize: isSelected ? 13 : 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedIndicator(LanguageProvider lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (widget.selectedCategory == null || _selectedSubcategoryId == null) {
      return const SizedBox.shrink();
    }

    try {
      final selectedSubcategory = _subcategories
          .firstWhere((sub) => sub.id == _selectedSubcategoryId);

      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSuccessGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kSuccessGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kSuccessGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: kSuccessGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('subcategory_selected', category: 'service'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kSuccessGreen,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedSubcategory.getTranslatedName(lang),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedSubcategoryId = null;
          });
        }
      });
      return const SizedBox.shrink();
    }
  }

  List<Color> _getSubcategoryColors(int index) {
    const colorSchemes = [
      [Color(0xFF667EEA)], // Purple
      [Color(0xFF4FACFE)], // Blue
      [Color(0xFF43E97B)], // Green
      [Color(0xFFFA709A)], // Pink
      [Color(0xFFF093FB)], // Magenta
      [Color(0xFFA8C0FF)], // Light Blue
      [Color(0xFFFD746C)], // Orange
      [Color(0xFF42E695)], // Teal
    ];
    return colorSchemes[index % colorSchemes.length];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(languageProvider),
              const SizedBox(height: 24),
              _buildSubcategoriesList(languageProvider),
              _buildSelectedIndicator(languageProvider),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
