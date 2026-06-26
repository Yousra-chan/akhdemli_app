import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/home_screen/create_service_button.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/screens/search/search_screen.dart';
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:service_app/screens/service/create_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'home_constants.dart';
import 'home_header_widget.dart';
import 'categories_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  UserModel? _currentUser;
  int _notificationCount = 0;
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  List<SubcategoryModel> _subcategories = [];

  bool _isLoadingCategories = true;
  bool _isLoadingSubcategories = false;

  StreamSubscription? _notificationCountSubscription;
  StreamSubscription? _userDataSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _subcategoriesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animationController.forward();
    });
  }

  void _loadInitialData() {
    _loadUserData();
    _loadCategories();
    _loadNotificationCount();
  }

  void _loadUserData() {
    final user = FirebaseService.currentUser;
    if (user != null) {
      _userDataSubscription?.cancel();
      _userDataSubscription =
          FirebaseService.getUserData(user.uid).listen((userData) {
            if (mounted && userData.exists && userData.data() != null) {
              setState(() {
                _currentUser = UserModel.fromMap(
                    userData.data()! as Map<String, dynamic>, user.uid);
              });
            }
          });
    }
  }

  void _loadCategories() {
    if (mounted) setState(() => _isLoadingCategories = true);
    _categoriesSubscription?.cancel();
    _categoriesSubscription = FirebaseService.getCategories()
        .listen(_handleCategoriesLoaded, onError: _handleCategoriesError);
  }

  void _handleCategoriesLoaded(List<CategoryModel> categories) {
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
      if (_selectedCategory == null && _categories.isNotEmpty) {
        _onCategorySelected(_categories.first, isAutoSelect: true);
      }
    });
  }

  void _handleCategoriesError(Object error) {
    debugPrint('Error loading categories: $error');
    if (!mounted) return;
    setState(() {
      _categories = [];
      _isLoadingCategories = false;
    });
  }

  void _loadNotificationCount() {
    final user = FirebaseService.currentUser;
    if (user == null || user.uid.isEmpty) {
      setState(() => _notificationCount = 0);
      return;
    }
    _notificationCountSubscription?.cancel();
    _notificationCountSubscription =
        FirebaseService.getUnreadNotificationCount(user.uid).listen(
            _handleNotificationCount,
            onError: _handleNotificationError);
  }

  void _handleNotificationCount(int count) {
    if (!mounted) return;
    setState(() => _notificationCount = count);
  }

  void _handleNotificationError(Object error) {
    if (!mounted) return;
    setState(() => _notificationCount = 0);
  }

  void _onCategorySelected(CategoryModel category,
      {bool isAutoSelect = false}) async {
    if (_isLoadingSubcategories) return;
    if (mounted) setState(() => _selectedCategory = category);

    if (isAutoSelect) {
      _loadSubcategoriesInBackground(category.id);
      return;
    }

    HapticFeedback.selectionClick();
    if (mounted) setState(() => _isLoadingSubcategories = true);

    try {
      final subs =
      await FirebaseService.getSubcategoriesForCategory(category.id);
      if (!mounted) return;
      setState(() => _isLoadingSubcategories = false);

      if (subs.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProvidersListPage(
              categoryName: category.name,
              subCategoryName: '',
            ),
          ),
        );
      } else {
        _showSubcategoryPicker(category, subs);
      }
    } catch (e) {
      debugPrint('Error handling category selection: $e');
      if (mounted) setState(() => _isLoadingSubcategories = false);
    }
  }

  void _loadSubcategoriesInBackground(String categoryId) {
    _subcategoriesSubscription?.cancel();
    _subcategoriesSubscription =
        FirebaseService.getSubCategories(categoryId).listen((subs) {
          if (mounted) setState(() => _subcategories = subs);
        });
  }

  void _showSubcategoryPicker(
      CategoryModel category, List<SubcategoryModel> subs) {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: getColorForCategory(category.name, 0)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon,
                        color: getColorForCategory(category.name, 0)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.getTranslatedName(languageProvider),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Exo2',
                          ),
                        ),
                        Text(
                          languageProvider.tr('choose_subcategory_desc',
                              category: 'home_page'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  final sub = subs[index];
                  return _CategoryGridCard(
                    title: sub.getTranslatedName(languageProvider),
                    icon: sub.icon,
                    imageUrl: sub.imageUrl,
                    color: getColorForCategory(category.name, index),
                    onTap: () {
                      Navigator.pop(context);
                      _onSubcategorySelected(sub);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubcategorySelected(SubcategoryModel subcategory) {
    if (_selectedCategory == null) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProvidersListPage(
          categoryName: _selectedCategory!.name,
          subCategoryName: subcategory.name,
        ),
      ),
    );
  }

  void _navigateToServiceCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (_) => ServiceViewModel()),
          ],
          child: const CreateServiceScreen(),
        ),
      ),
    );
  }

  void _showNotifications() => showNotificationsWindow(context);

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _notificationCountSubscription?.cancel();
    _userDataSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  HomeHeader(
                    currentUser: _currentUser,
                    searchController: _searchController,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onSearchSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapSearchPage(initialQuery: query),
                          ),
                        );
                      }
                    },
                    notificationCount: _notificationCount,
                    onNotificationPressed: _showNotifications,
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCategoriesSectionHeader(languageProvider),
                            _buildCategoriesGrid(languageProvider),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CreateServiceButton(
                    onPressed: _navigateToServiceCreation,
                    isProvider: _currentUser?.isProvider ?? false,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Categories section header ──────────────────────────────
  Widget _buildCategoriesSectionHeader(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _searchQuery.isEmpty
                ? lang.tr('categories', category: 'home_page')
                : lang.tr('search_results', category: 'home_page'),
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color ??
                  kDarkTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Exo2',
              letterSpacing: -0.3,
            ),
          ),
          if (_categories.isNotEmpty && _searchQuery.isEmpty)
            GestureDetector(
              onTap: () => _navigateToAllCategories(lang),
              child: Row(
                children: [
                  Text(
                    lang.tr('see_all', category: 'home_page'),
                    style: const TextStyle(
                      color: kPrimaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 11, color: kPrimaryBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToAllCategories(LanguageProvider lang) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesPage(
          categories: _categories,
          currentUser: _currentUser,
        ),
      ),
    );
  }

  // ── Categories Grid ────────────────────────────────────────
  Widget _buildCategoriesGrid(LanguageProvider lang) {
    if (_isLoadingCategories) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => const CategorySkeleton(),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text(
          lang.tr('no_categories', category: 'home_page'),
          style: const TextStyle(
              color: kMutedTextColor, fontFamily: 'Exo2', fontSize: 14),
        ),
      );
    }

    final filteredCategories = _categories.where((cat) {
      final name = cat.getTranslatedName(lang).toLowerCase();
      final engName = cat.name.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || engName.contains(query);
    }).toList();

    if (filteredCategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                lang.tr('no_results_found', category: 'search'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.tr('adjust_filters', category: 'admin'),
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontFamily: 'Exo2',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show at most 9 categories on home (3 rows of 3) when NOT searching
    final displayCategories = _searchQuery.isEmpty
        ? (filteredCategories.length > 9
            ? filteredCategories.sublist(0, 9)
            : filteredCategories)
        : filteredCategories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: displayCategories.length,
        itemBuilder: (context, index) {
          final category = displayCategories[index];
          return _CategoryGridCard(
            title: category.getTranslatedName(lang),
            icon: category.icon,
            imageUrl: category.iconUrl,
            color: getColorForCategory(category.name, index),
            onTap: () => _onCategorySelected(category),
            isLoading: _isLoadingSubcategories &&
                _selectedCategory?.id == category.id,
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Category Grid Card  — matches reference image style
// ──────────────────────────────────────────────────────────────
class _CategoryGridCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? imageUrl;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _CategoryGridCard({
    required this.title,
    required this.icon,
    this.imageUrl,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image / icon area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildVisual(isDark),
            ),
          ),
          const SizedBox(height: 8),
          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimaryBlue),
                  )
                : Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF2D2D2D),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Exo2',
                      height: 1.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisual(bool isDark) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (ImageUtils.isBase64Image(imageUrl)) {
        final bytes = ImageUtils.decodeBase64Image(imageUrl);
        if (bytes != null) {
          return Image.memory(bytes,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _fallbackIcon(isDark));
        }
      } else {
        return CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => _shimmer(),
          errorWidget: (_, __, ___) => _fallbackIcon(isDark),
        );
      }
    }
    return _fallbackIcon(isDark);
  }

  Widget _fallbackIcon(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 36),
    );
  }

  Widget _shimmer() {
    return const SkeletonLoader(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 14,
    );
  }
}
