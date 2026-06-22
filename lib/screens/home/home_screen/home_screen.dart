import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
import 'home_constants.dart';

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
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
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
      _userDataSubscription = FirebaseService.getUserData(user.uid).listen((userData) {
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
      
      // Auto-select first category if none selected, but DON'T navigate
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

  void _onCategorySelected(CategoryModel category, {bool isAutoSelect = false}) async {
    if (_isLoadingSubcategories) return;

    // We still update the UI selection for the horizontal list
    setState(() {
      _selectedCategory = category;
    });

    if (isAutoSelect) {
      // For auto-selection on init, we just load subcategories into the background/grid
      _loadSubcategoriesInBackground(category.id);
      return;
    }

    HapticFeedback.selectionClick();
    
    // Show a small loading overlay or indicator while checking subcategories
    setState(() => _isLoadingSubcategories = true);

    try {
      final subs = await FirebaseService.getSubcategoriesForCategory(category.id);
      
      if (!mounted) return;
      setState(() => _isLoadingSubcategories = false);

      if (subs.isEmpty) {
        // CASE 2: No subcategories -> Immediate navigation
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
        // CASE 1: Subcategories exist -> Show modern selection picker
        _showSubcategoryPicker(category, subs);
      }
    } catch (e) {
      debugPrint('Error handling category selection: $e');
      if (mounted) setState(() => _isLoadingSubcategories = false);
    }
  }

  void _loadSubcategoriesInBackground(String categoryId) {
    _subcategoriesSubscription?.cancel();
    _subcategoriesSubscription = FirebaseService.getSubCategories(categoryId).listen((subs) {
      if (mounted) {
        setState(() {
          _subcategories = subs;
        });
      }
    });
  }

  void _showSubcategoryPicker(CategoryModel category, List<SubcategoryModel> subs) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
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
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: getColorForCategory(category.name, 0).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon, color: getColorForCategory(category.name, 0)),
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
                          languageProvider.tr('choose_subcategory_desc', category: 'home_page'),
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
            
            // Subcategories Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  final sub = subs[index];
                  return _UnifiedServiceCard(
                    title: sub.getTranslatedName(languageProvider),
                    icon: sub.icon,
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      _onSubcategorySelected(sub);
                    },
                    color: theme.primaryColor,
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
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(languageProvider.tr('categories', category: 'home_page')),
                          _buildCategoriesHorizontal(languageProvider),
                          
                          const SizedBox(height: 24),
                          


                          
                          const SizedBox(height: 100),
                        ],
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

  Widget _buildHeader(LanguageProvider lang) {
    final userName = _currentUser?.name.split(' ').first;
    final greeting = userName != null && userName.isNotEmpty
        ? lang.trParams('hello_user',
            category: 'home_page', params: {'name': userName})
        : lang.tr('hello_guest', category: 'home_page');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 12, 94, 153),
            Color(0xFF4A6FDC),
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.tr('find_service_providers', category: 'home_page'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontFamily: 'Exo2',
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationIcon(),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
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
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 22,
            ),
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
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                _notificationCount > 9 ? '9+' : _notificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFamily: 'Exo2',
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildCategoriesHorizontal(LanguageProvider lang) {
    if (_isLoadingCategories) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(lang.tr('no_categories', category: 'home_page')),
      );
    }

    return SizedBox(
      height: 125,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory?.id == category.id;
          return _UnifiedServiceCard(
            title: category.getTranslatedName(lang),
            icon: category.icon,
            isSelected: isSelected,
            onTap: () => _onCategorySelected(category),
            color: getColorForCategory(category.name, index),
          );
        },
      ),
    );
  }

}

class _UnifiedServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isSmall;

  const _UnifiedServiceCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 100),
        tween: Tween(begin: 1.0, end: isSelected ? 1.05 : 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSmall ? null : 100,
              margin: EdgeInsets.all(isSmall ? 4 : 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  width: 2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 8 : 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: isSmall ? 22 : 28,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : kDarkTextColor),
                  fontSize: isSmall ? 11 : 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
