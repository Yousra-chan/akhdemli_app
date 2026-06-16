import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/home_screen/create_service_button.dart';
import 'package:service_app/screens/home/home_screen/subcategories_page.dart';
import 'package:service_app/services/firebase_service.dart';
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

  bool _isLoadingCategories = true;

  StreamSubscription? _notificationCountSubscription;

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

    FirebaseService.getCategories()
        .listen(_handleCategoriesLoaded, onError: _handleCategoriesError);
  }

  void _handleCategoriesLoaded(List<CategoryModel> categories) {
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _categories = categories.isNotEmpty
              ? categories
              : CategoryModel.defaultCategories;
          _isLoadingCategories = false;
        });
      }
    });
  }

  void _handleCategoriesError(Object error) {
    debugPrint('Error loading categories: $error');
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _categories = CategoryModel.defaultCategories;
          _isLoadingCategories = false;
        });
      }
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

  // Navigation Methods
  void _onCategorySelected(CategoryModel category) {
    HapticFeedback.lightImpact();
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubcategoriesPage(
          selectedCategory: category,
          onBackPressed: () => Navigator.pop(context),
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

  void _navigateToAllProviders() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(
          categoryName:
              languageProvider.tr('all_categories', category: 'home_page'),
          subCategoryName:
              languageProvider.tr('all_services', category: 'home_page'),
        ),
      ),
    );
  }

  void _showSearchResults() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    if (_searchQuery.isEmpty) {
      _navigateToAllProviders();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(
          categoryName:
              languageProvider.tr('search_results', category: 'home_page'),
          subCategoryName: _searchQuery,
        ),
      ),
    );
  }

  void _showNotifications() => showNotificationsWindow(context);

  void _onSearchChanged(String value) => setState(() => _searchQuery = value);

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
                        children: [
                          _buildCategoriesSection(languageProvider),
                          const SizedBox(height: 80),
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
    final userName = _currentUser?.name?.split(' ').first;
    final greeting = userName != null && userName.isNotEmpty
        ? lang.trParams('hello_user',
            category: 'home_page', params: {'name': userName})
        : lang.tr('hello_guest', category: 'home_page');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
            icon: Icon(
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

  Widget _buildCategoriesSection(LanguageProvider lang) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('categories', category: 'home_page'),
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color ?? kDarkTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingCategories)
            const LoadingWidget()
          else if (_categories.isEmpty)
            EmptyStateWidget(
              icon: Icons.category_outlined,
              message: lang.tr('no_services_available', category: 'home_page'),
            )
          else
            _buildCategoriesGrid(lang),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(LanguageProvider lang) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.9,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) =>
          _buildCategoryItem(_categories[index], index, lang),
    );
  }

  Widget _buildCategoryItem(
      CategoryModel category, int index, LanguageProvider lang) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _onCategorySelected(category),
      child: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getCategoryColors(index),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(category.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              getTranslatedCategoryName(category.name, lang),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color ?? kDarkTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _notificationCountSubscription?.cancel();
    super.dispose();
  }
}
