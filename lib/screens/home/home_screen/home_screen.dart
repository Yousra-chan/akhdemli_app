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
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:service_app/screens/service/create_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'home_constants.dart';
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
    setState(() => _isLoadingCategories = true);
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
    setState(() => _selectedCategory = category);

    if (isAutoSelect) {
      _loadSubcategoriesInBackground(category.id);
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isLoadingSubcategories = true);

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
                  _buildHeader(languageProvider),
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

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(LanguageProvider lang) {
    final userName = _currentUser?.name.split(' ').first;
    final greeting = userName != null && userName.isNotEmpty
        ? lang.trParams('hello_user',
        category: 'home_page', params: {'name': userName})
        : lang.tr('hello_guest', category: 'home_page');

    final subtitle = (_currentUser?.isProvider ?? false)
        ? lang.tr('manage_services', category: 'home_page')
        : lang.tr('find_service_providers', category: 'home_page');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 12, 94, 153),
            Color(0xFF4A6FDC),
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + greeting + notification
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              _buildAvatar(),
              const SizedBox(width: 12),
              // Greeting text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontFamily: 'Exo2',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Exo2',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Notification icon
              _buildNotificationIcon(),
            ],
          ),
          const SizedBox(height: 20),
          // Search bar
          _buildSearchBar(lang),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = _currentUser?.photoUrl;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        color: Colors.white.withOpacity(0.2),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _defaultAvatarIcon(),
        )
            : _defaultAvatarIcon(),
      ),
    );
  }

  Widget _defaultAvatarIcon() {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: const Icon(Icons.person, color: Colors.white, size: 26),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _showNotifications,
            icon: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
          ),
        ),
        if (_notificationCount > 0)
          PositionedDirectional(
            end: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints:
              const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _notificationCount > 9 ? '9+' : _notificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(LanguageProvider lang) {
    final isProvider = _currentUser?.isProvider ?? false;
    final hint = isProvider
        ? lang.tr('search_services_listings', category: 'home_page')
        : lang.tr('search_services_providers', category: 'home_page');

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: kMutedTextColor,
            fontSize: 14,
            fontFamily: 'Exo2',
          ),
          prefixIcon:
          const Icon(Icons.search_rounded, color: kPrimaryBlue, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
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
            lang.tr('categories', category: 'home_page'),
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color ??
                  kDarkTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Exo2',
              letterSpacing: -0.3,
            ),
          ),
          if (_categories.isNotEmpty)
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
      return const SizedBox(
        height: 200,
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: kPrimaryBlue)),
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

    // Show at most 9 categories on home (3 rows of 3), rest visible via "See all"
    final displayCategories =
    _categories.length > 9 ? _categories.sublist(0, 9) : _categories;

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
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}