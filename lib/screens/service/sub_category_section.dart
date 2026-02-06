import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:service_app/models/CategoryModel.dart';
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

  void _selectSubcategory(SubcategoryModel subcategory) {
    setState(() {
      _selectedSubcategoryId = subcategory.id;
    });
    widget.onSubcategorySelected(subcategory);
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Service Subcategory',
              style: TextStyle(
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
                  '${widget.selectedCategory!.subcategories.length}',
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
              ? 'Choose a specific ${widget.selectedCategory!.name.toLowerCase()} service'
              : 'Select a category first to see subcategories',
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

  Widget _buildSubcategoriesList() {
    if (widget.selectedCategory == null) {
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
                CupertinoIcons.square_grid_2x2,
                size: 64,
                color: kMutedTextColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a Category',
                style: TextStyle(
                  color: kDarkTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a category above to see available subcategories',
                textAlign: TextAlign.center,
                style: TextStyle(
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

    final subcategories = widget.selectedCategory!.subcategories;

    if (subcategories.isEmpty) {
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
                CupertinoIcons.infinite,
                size: 64,
                color: kMutedTextColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No Subcategories',
                style: TextStyle(
                  color: kDarkTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No subcategories available for ${widget.selectedCategory!.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
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

    // Using horizontal ListView like CategorySection
    return SizedBox(
      height:
          140, // Slightly taller than categories to accommodate longer names
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
            child:
                _buildSubcategoryItem(subcategory, colors, isSelected, index),
          );
        },
      ),
    );
  }

  Widget _buildSubcategoryItem(
    SubcategoryModel subcategory,
    List<Color> colors,
    bool isSelected,
    int index,
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
              subcategory.name.length > 12
                  ? '${subcategory.name.substring(0, 10)}...'
                  : subcategory.name,
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

  Widget _buildSelectedIndicator() {
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
                    'Subcategory Selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kSuccessGreen,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedSubcategory.name,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSubcategoriesList(),
          _buildSelectedIndicator(),
          // Add some bottom padding to ensure no overflow
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
