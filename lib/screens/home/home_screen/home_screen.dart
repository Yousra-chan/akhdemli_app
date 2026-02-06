import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/home/home_screen/categories_section.dart';
import 'package:service_app/screens/home/home_screen/create_service_button.dart';
import 'package:service_app/screens/home/home_screen/subcategories_page.dart';
import 'package:service_app/services/firebase_service.dart';
import 'package:service_app/screens/home/providers_list/provider_detail_page.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:service_app/screens/service/create_service.dart';
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(
          categoryName: 'All',
          subCategoryName: 'All Services',
        ),
      ),
    );
  }

  void _showSearchResults() {
    if (_searchQuery.isEmpty) {
      _navigateToAllProviders();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(
          categoryName: 'Search',
          subCategoryName: _searchQuery,
        ),
      ),
    );
  }

  void _showNotifications() => showNotificationsWindow(context);

  void _onSearchChanged(String value) => setState(() => _searchQuery = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildCategoriesSection(),
                    const SizedBox(height: 80), // Space for the bottom button
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
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)], // Purple gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          // This row contains both the welcome text and notification button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome text section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_currentUser?.name?.split(' ').first ?? 'Guest'}!',
                      style: const TextStyle(
                        color: Colors.white, // Changed to white for contrast
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find the best service providers near you',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9), // Lighter white
                        fontSize: 14,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ],
                ),
              ),

              // Notification button
              _buildNotificationIcon(),
            ],
          ),

          const SizedBox(height: 20),
          _buildSearchBar(),
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
            color: Colors.white.withOpacity(0.2), // Semi-transparent white
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _showNotifications,
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.white, // White icon
              size: 22,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        if (_notificationCount > 0)
          Positioned(
            right: 0,
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

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _showSearchResults(),
              decoration: InputDecoration(
                hintText: 'Search services...',
                hintStyle: TextStyle(color: kMutedTextColor),
                prefixIcon: Icon(Icons.search, color: kPrimaryBlue),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(
              color: kDarkTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingCategories)
            _buildLoadingCategories()
          else if (_categories.isEmpty)
            _buildEmptyCategories()
          else
            _buildCategoriesGrid(),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 items per row
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.9, // Width/Height ratio
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) =>
          _buildCategoryItem(_categories[index], index),
    );
  }

  Widget _buildCategoryItem(CategoryModel category, int index) {
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
              category.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kDarkTextColor,
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

  Widget _buildLoadingCategories() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.9,
      ),
      itemCount: 6, // Show 6 shimmer items
      itemBuilder: (context, index) => _buildShimmerCategory(),
    );
  }

  Widget _buildShimmerCategory() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 70,
          height: 12,
          color: Colors.grey.shade200,
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 10,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }

  Widget _buildEmptyCategories() {
    return SizedBox(
      height: 300,
      child: Center(
        child: const _EmptyState(
          icon: Icons.category_outlined,
          message: 'No services available',
        ),
      ),
    );
  }

  List<Color> _getCategoryColors(int index) {
    const colorSchemes = [
      [Color(0xFF667EEA), Color(0xFF764BA2)], // Purple
      [Color(0xFF4FACFE), Color(0xFF00F2FE)], // Blue
      [Color(0xFF43E97B), Color(0xFF38F9D7)], // Green
      [Color(0xFFFA709A), Color(0xFFFEE140)], // Pink/Yellow
      [Color(0xFFF093FB), Color(0xFFF5576C)], // Purple/Red
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: kMutedTextColor),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: kMutedTextColor,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }
}
