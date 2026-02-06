import 'package:flutter/material.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';

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
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildCategoriesGrid(),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'All Categories',
        style: TextStyle(
          color: kDarkTextColor,
          fontWeight: FontWeight.w700,
          fontFamily: 'Exo2',
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: kDarkTextColor),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
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
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    CategoryModel category,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _navigateToProviders(context, category),
      child: Container(
        decoration: _categoryCardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCategoryIcon(category, index),
            const SizedBox(height: 12),
            _buildCategoryName(category.name),
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
      ),
    );
  }

  void _navigateToProviders(BuildContext context, CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(
          categoryName: category.name,
          subCategoryName: '',
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
