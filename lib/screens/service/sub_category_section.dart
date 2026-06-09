import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';

class SubcategorySection extends StatefulWidget {
  final CategoryModel? selectedCategory;
  final Function(SubcategoryModel) onSubcategorySelected;

  const SubcategorySection({
    super.key,
    required this.selectedCategory,
    required this.onSubcategorySelected,
  });

  @override
  State<SubcategorySection> createState() => _SubcategorySectionState();
}

class _SubcategorySectionState extends State<SubcategorySection> {
  String? _selectedSubcategoryId;

  @override
  void didUpdateWidget(SubcategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection when category changes
    if (widget.selectedCategory?.id != oldWidget.selectedCategory?.id) {
      setState(() {
        _selectedSubcategoryId = null;
      });
    }
  }

  void _selectSubcategory(SubcategoryModel subcategory) {
    setState(() {
      _selectedSubcategoryId = subcategory.id;
    });
    widget.onSubcategorySelected(subcategory);
  }

  Widget _buildHeader(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.tr('service_subcategory', category: 'service'),
              style: const TextStyle(
                color: kDarkTextColor,
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
                  color: kPrimaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryBlue.withOpacity(0.2)),
                ),
                child: Text(
                  lang.trParams('subcategory_count',
                      category: 'service',
                      params: {
                        'count': widget.selectedCategory!.subcategories.length
                            .toString()
                      }),
                  style: const TextStyle(
                    color: kPrimaryBlue,
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
          style: const TextStyle(
            color: kMutedTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Exo2',
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategoriesList(LanguageProvider lang) {
    if (widget.selectedCategory == null) {
      return _buildEmptyState(
        icon: CupertinoIcons.square_grid_2x2,
        title: lang.tr('select_category', category: 'service'),
        message: lang.tr('select_category_desc', category: 'service'),
      );
    }

    final subcategories = widget.selectedCategory!.subcategories;

    if (subcategories.isEmpty) {
      return _buildEmptyState(
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
        itemCount: subcategories.length,
        itemBuilder: (context, index) {
          final subcategory = subcategories[index];
          final isSelected = _selectedSubcategoryId == subcategory.id;
          final colors = _getSubcategoryColors(index);

          return Container(
            margin: EdgeInsets.only(
              right: 16,
              left: index == 0 ? 0 : 0,
            ),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: kLightBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: kMutedTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: kDarkTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kMutedTextColor,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isSelected ? 100 : 90,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _selectSubcategory(subcategory),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 70 : 64,
              height: isSelected ? 70 : 64,
              decoration: BoxDecoration(
                color: isSelected ? colors[0] : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors[0] : Colors.grey.shade300,
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
                      color: Colors.black.withOpacity(0.1),
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
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              subcategory.nameKey.isNotEmpty
                  ? subcategory.getTranslatedName(lang)
                  : (subcategory.name.length > 12
                      ? '${subcategory.name.substring(0, 10)}...'
                      : subcategory.name),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? colors[0] : kDarkTextColor,
                fontSize: isSelected ? 13 : 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontFamily: 'Exo2',
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedIndicator(LanguageProvider lang) {
    if (widget.selectedCategory == null || _selectedSubcategoryId == null) {
      return const SizedBox.shrink();
    }

    try {
      final selectedSubcategory = widget.selectedCategory!.subcategories
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
              child: Icon(
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kSuccessGreen,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedSubcategory.nameKey.isNotEmpty
                        ? selectedSubcategory.getTranslatedName(lang)
                        : selectedSubcategory.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kDarkTextColor,
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
