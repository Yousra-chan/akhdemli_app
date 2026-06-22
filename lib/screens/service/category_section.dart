import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/Services/firebase_service.dart';

class CategorySection extends StatefulWidget {
  final Function(CategoryModel) onCategorySelected;
  final String? initialCategoryId;

  const CategorySection({
    super.key,
    required this.onCategorySelected,
    this.initialCategoryId,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  String? _selectedCategoryId;
  List<CategoryModel> _categories = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _loadCategories();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadCategories() {
    _subscription = FirebaseService.getCategories().listen((categories) {
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
          
          if (_categories.isNotEmpty && _selectedCategoryId == null) {
            // Only auto-select if nothing is currently selected
            _selectedCategoryId = _categories.first.id;
            widget.onCategorySelected(_categories.first);
          } else if (_categories.isNotEmpty && _selectedCategoryId != null) {
            // If something was already selected, ensure we update the object from the new list
            try {
              final updatedCat = _categories.firstWhere((c) => c.id == _selectedCategoryId);
              widget.onCategorySelected(updatedCat);
            } catch (e) {
              // Selected category gone? Fallback
              _selectedCategoryId = _categories.first.id;
              widget.onCategorySelected(_categories.first);
            }
          }
        });
      }
    });
  }

  void _selectCategory(CategoryModel category) {
    if (_selectedCategoryId == category.id) return; // Already selected

    setState(() {
      _selectedCategoryId = category.id;
    });
    widget.onCategorySelected(category);
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
              lang.tr('category_section_title', category: 'service'),
              style: TextStyle(
                color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              ),
              child: Text(
                lang.trParams('total_categories',
                    category: 'service',
                    params: {'count': _categories.length.toString()}),
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
          lang.tr('category_section_desc', category: 'service'),
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

  Widget _buildCategoriesList(LanguageProvider lang) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_categories.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            lang.tr('no_categories_found', category: 'service'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategoryId == category.id;
          final color = getColorForCategory(category.name, index);

          return Container(
            margin: const EdgeInsetsDirectional.only(end: 16),
            child: _buildCategoryItem(category, color, isSelected, index, lang),
          );
        },
      ),
    );
  }

  Widget _buildCategoryItem(
    CategoryModel category,
    Color color,
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
        onTap: () => _selectCategory(category),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 70 : 64,
              height: isSelected ? 70 : 64,
              decoration: BoxDecoration(
                color: isSelected ? color : theme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: color.withOpacity(0.3),
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
                category.icon,
                color: isSelected ? Colors.white : color,
                size: isSelected ? 28 : 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.getTranslatedName(lang),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? color : theme.textTheme.bodyLarge?.color,
                fontSize: isSelected ? 13 : 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontFamily: 'Exo2',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
              _buildCategoriesList(languageProvider),
            ],
          ),
        );
      },
    );
  }
}
