import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'dart:ui' as ui;

class CategoriesPage extends StatelessWidget {
  static const double _gridSpacing = 16;
  static const int _crossAxisCount = 3;
  static const double _childAspectRatio = 0.9;
  static const double _iconContainerSize = 56;
  static const double _iconSize = 24;
  static const double _categoryNameFontSize = 12;

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
            appBar: _buildAppBar(context, languageProvider),
            body: _buildCategoriesGrid(context, languageProvider),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, LanguageProvider lang) {
    return AppBar(
      title: Text(
        lang.tr('all_categories', category: 'home_categories'),
        style: TextStyle(
          color: kDarkTextColor,
          fontWeight: FontWeight.w700,
          fontFamily: 'Exo2',
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(lang.isRtl ? Icons.arrow_forward : Icons.arrow_back,
            color: kDarkTextColor),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context, LanguageProvider lang) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: kMutedTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              lang.tr('no_categories_found', category: 'home_categories'),
              style: TextStyle(
                color: kMutedTextColor,
                fontSize: 16,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(_gridSpacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        childAspectRatio: _childAspectRatio,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) => _buildCategoryCard(
        context,
        categories[index],
        index,
        lang,
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    CategoryModel category,
    int index,
    LanguageProvider lang,
  ) {
    return GestureDetector(
      onTap: () => _navigateToProviders(context, category, lang),
      child: Container(
        decoration: _categoryCardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCategoryIcon(category, index),
            const SizedBox(height: 12),
            _buildCategoryName(category.name),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  BoxDecoration _categoryCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildCategoryIcon(CategoryModel category, int index) {
    return Container(
      width: _iconContainerSize,
      height: _iconContainerSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getCategoryColors(index),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        category.icon,
        color: Colors.white,
        size: _iconSize,
      ),
    );
  }

  Widget _buildCategoryName(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: kDarkTextColor,
          fontSize: _categoryNameFontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'Exo2',
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
          subCategoryName: lang.tr('all_services', category: 'home_categories'),
        ),
      ),
    );
  }

  List<Color> _getCategoryColors(int index) {
    const colorSchemes = [
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      [Color(0xFF43E97B), Color(0xFF38F9D7)],
      [Color(0xFFFA709A), Color(0xFFFEE140)],
      [Color(0xFFF093FB), Color(0xFFF5576C)],
    ];
    return colorSchemes[index % colorSchemes.length];
  }
}
