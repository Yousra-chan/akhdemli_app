import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/providers/language_provider.dart';
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
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _subCategories = widget.selectedCategory.subcategories.isNotEmpty
          ? widget.selectedCategory.subcategories
          : _getDefaultSubCategories();
      _filteredSubCategories = List.from(_subCategories);
      _isLoading = false;
    });
  }

  List<SubcategoryModel> _getDefaultSubCategories() {
    // This should rarely be called now since we have proper subcategories
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    return List.generate(6, (index) {
      final names = [
        languageProvider.tr('basic_service', category: 'subcategories_page'),
        languageProvider.tr('premium_service', category: 'subcategories_page'),
        languageProvider.tr('emergency_service',
            category: 'subcategories_page'),
        languageProvider.tr('advanced_service', category: 'subcategories_page'),
        languageProvider.tr('standard_package', category: 'subcategories_page'),
        languageProvider.tr('custom_service', category: 'subcategories_page'),
      ];
      final icons = [
        CupertinoIcons.circle_fill,
        CupertinoIcons.star_fill,
        CupertinoIcons.exclamationmark_triangle_fill,
        CupertinoIcons.rocket_fill,
        CupertinoIcons.checkmark_seal_fill,
        CupertinoIcons.gear_alt_fill
      ];

      return SubcategoryModel(
        id: 'sub-$index',
        name: names[index],
        nameKey: '', // No translation key for defaults
        description: languageProvider.trParams(
          'service_description',
          category: 'subcategories_page',
          params: {
            'category':
                widget.selectedCategory.getTranslatedName(languageProvider),
            'service': names[index].toLowerCase()
          },
        ),
        descriptionKey: '',
        icon: icons[index],
        iconCode: icons[index].toString(),
      );
    });
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
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                    languageProvider.isRtl
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.arrow_back_ios_rounded,
                    color: kDarkTextColor,
                    size: 20),
                onPressed: widget.onBackPressed,
              ),
              title: Text(
                widget.selectedCategory.getTranslatedName(languageProvider),
                style: TextStyle(
                    color: kDarkTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2'),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterSubCategories,
                    decoration: InputDecoration(
                      hintText: languageProvider.tr('search_services',
                          category: 'subcategories_page'),
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontFamily: 'Exo2',
                      ),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Colors.grey.shade500),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  size: 20, color: Colors.grey.shade500),
                              onPressed: () {
                                _searchController.clear();
                                _filterSubCategories('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
            body: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: kPrimaryBlue,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          languageProvider.tr('loading_services',
                              category: 'subcategories_page'),
                          style: TextStyle(
                            color: kMutedTextColor,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredSubCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              languageProvider.tr('no_services_found',
                                  category: 'subcategories_page'),
                              style: TextStyle(
                                color: kMutedTextColor,
                                fontSize: 16,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _filterSubCategories('');
                                },
                                child: Text(
                                  languageProvider.tr('clear_search',
                                      category: 'subcategories_page'),
                                  style: TextStyle(
                                    color: kPrimaryBlue,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              languageProvider.trParams(
                                'services_count',
                                category: 'subcategories_page',
                                params: {
                                  'count':
                                      _filteredSubCategories.length.toString(),
                                },
                              ),
                              style: TextStyle(
                                color: kMutedTextColor,
                                fontSize: 13,
                                fontFamily: 'Exo2',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.all(20),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _filteredSubCategories.length,
                              itemBuilder: (context, index) {
                                final subCategory =
                                    _filteredSubCategories[index];

                                // Expanded color schemes to match all categories
                                final colorSchemes = [
                                  [
                                    const Color(0xFF667EEA),
                                    const Color(0xFF764BA2)
                                  ], // Cleaning/Purple
                                  [
                                    const Color(0xFF4FACFE),
                                    const Color(0xFF00F2FE)
                                  ], // Plumbing/Blue
                                  [
                                    const Color(0xFF43E97B),
                                    const Color(0xFF38F9D7)
                                  ], // Electrical/Green
                                  [
                                    const Color(0xFFFA709A),
                                    const Color(0xFFFEE140)
                                  ], // Carpentry/Pink
                                  [
                                    const Color(0xFFF093FB),
                                    const Color(0xFFF5576C)
                                  ], // Painting/Light Purple
                                  [
                                    const Color(0xFF38F9D7),
                                    const Color(0xFF43E97B)
                                  ], // Gardening/Teal
                                  [
                                    const Color(0xFFFF9068),
                                    const Color(0xFFFD746C)
                                  ], // Moving/Orange
                                  [
                                    const Color(0xFF764BA2),
                                    const Color(0xFF667EEA)
                                  ], // Repair/Deep Purple
                                  [
                                    const Color(0xFF00F2FE),
                                    const Color(0xFF4FACFE)
                                  ], // Installation/Cyan
                                  [
                                    const Color(0xFF38C97B),
                                    const Color(0xFF43E97B)
                                  ], // Tutoring/Mint
                                  [
                                    const Color(0xFFF5576C),
                                    const Color(0xFFFA709A)
                                  ], // Health/Red
                                  [
                                    const Color(0xFFFFC107),
                                    const Color(0xFFFEE140)
                                  ], // Beauty/Yellow
                                  [
                                    const Color(0xFFA8C0FF),
                                    const Color(0xFF3F2B96)
                                  ], // Home/Purple Blue
                                  [
                                    const Color(0xFF4CAF50),
                                    const Color(0xFF8BC34A)
                                  ], // Tech/Green
                                  [
                                    const Color(0xFFFF9800),
                                    const Color(0xFFFFA726)
                                  ], // Food/Orange
                                  [
                                    const Color(0xFF969696),
                                    const Color(0xFFBDBDBD)
                                  ], // Other/Grey
                                ];

                                final colors =
                                    colorSchemes[index % colorSchemes.length];

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: Colors.grey.shade100, width: 1),
                                  ),
                                  child: InkWell(
                                    onTap: () =>
                                        _onSubCategorySelected(subCategory),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  colors: colors),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: colors[0]
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Icon(subCategory.icon,
                                                color: Colors.white, size: 24),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            subCategory.nameKey.isNotEmpty
                                                ? subCategory.getTranslatedName(
                                                    languageProvider)
                                                : subCategory.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Exo2',
                                              color: kDarkTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            languageProvider.tr(
                                                'view_providers',
                                                category: 'subcategories_page'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: kPrimaryBlue,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Exo2',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }
}
