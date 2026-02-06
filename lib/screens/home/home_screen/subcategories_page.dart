import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
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
    return List.generate(6, (index) {
      final names = [
        'Basic Service',
        'Premium Service',
        'Emergency Service',
        'Advanced Service',
        'Standard Package',
        'Custom Service'
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
        description:
            '${widget.selectedCategory.name} ${names[index].toLowerCase()}',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: kDarkTextColor, size: 20),
          onPressed: widget.onBackPressed,
        ),
        title: Text(
          widget.selectedCategory.name,
          style: TextStyle(
              color: kDarkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2'),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSubCategories,
              decoration: InputDecoration(
                hintText: 'Search services...',
                prefixIcon:
                    Icon(Icons.search_rounded, color: Colors.grey.shade500),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20),
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kDarkTextColor))
          : _filteredSubCategories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 60, color: Colors.grey.shade300),
                      SizedBox(height: 16),
                      Text('No services found',
                          style: TextStyle(color: kMutedTextColor)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _filteredSubCategories.length,
                  itemBuilder: (context, index) {
                    final subCategory = _filteredSubCategories[index];
                    final colors = [
                      [Color(0xFF667EEA), Color(0xFF764BA2)],
                      [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                      [Color(0xFF43E97B), Color(0xFF38F9D7)],
                      [Color(0xFFFA709A), Color(0xFFFEE140)],
                      [Color(0xFFA8C0FF), Color(0xFF3F2B96)],
                      [Color(0xFFFD746C), Color(0xFFFF9068)],
                    ][index % 6];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: InkWell(
                        onTap: () => _onSubCategorySelected(subCategory),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: colors),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors[0].withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(subCategory.icon,
                                    color: Colors.white, size: 24),
                              ),
                              SizedBox(height: 12),
                              Text(
                                subCategory.name,
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
