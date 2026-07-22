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
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/Services/provider_service.dart';
import 'package:service_app/screens/home/home_screen/create_service_button.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/screens/home/providers_list/provider_list_page.dart';
import 'package:service_app/screens/search/search_screen.dart';
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:service_app/screens/service/create_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/Services/search_service.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  UserModel? _currentUser;
  int _notificationCount = 0;
  List<CategoryModel> _categories = [];
  List<ProviderModel> _featuredProviders = [];
  CategoryModel? _selectedCategory;
  List<SubcategoryModel> _subcategories = [];
  String _selectedFilter = 'all';
  List<ProviderModel> _searchProviders = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  final SearchService _searchService = SearchService();

  bool _isLoadingCategories = true;
  bool _isLoadingFeatured = true;
  bool _isLoadingSubcategories = false;
  bool _isSearchFocused = false;

  StreamSubscription? _notificationCountSubscription;
  StreamSubscription? _userDataSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _subcategoriesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
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
    _loadFeaturedProviders();
    _loadNotificationCount();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchProviders = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) return;
      
      setState(() => _isSearching = true);
      try {
        final providers = await _searchService.searchProvidersComprehensive(query);
        if (mounted && _searchQuery == query) {
          setState(() {
            _searchProviders = providers;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Search error: $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _loadFeaturedProviders() async {
    if (mounted) setState(() => _isLoadingFeatured = true);
    try {
      final service = ProviderService();
      List<ProviderModel> providers = [];

      switch (_selectedFilter) {
        case 'popular':
          providers = await service.getPopularProviders(limit: 6);
          break;
        case 'recommended':
          providers = await service.getRecommendedProviders(limit: 6);
          break;
        case 'most_viewed':
          providers = await service.getMostViewedProviders(limit: 6);
          break;
        default:
          providers = await service.getFeaturedProviders(limit: 6);
      }

      if (mounted) {
        setState(() {
          _featuredProviders = providers;
          _isLoadingFeatured = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading featured providers: $e');
      if (mounted) setState(() => _isLoadingFeatured = false);
    }
  }

  void _onFilterChanged(String filterId) {
    if (_selectedFilter == filterId) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedFilter = filterId;
    });
    _loadFeaturedProviders();
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

    if (!isAutoSelect) {
      HapticFeedback.lightImpact();
    }

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

  Widget _buildSearchResults(LanguageProvider lang) {
    final filteredCategories = _categories.where((cat) {
      final name = cat.getTranslatedName(lang).toLowerCase();
      final engName = cat.name.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || engName.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filteredCategories.isNotEmpty) ...[
            Text(
              lang.tr('categories', category: 'home_page'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Exo2'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final cat = filteredCategories[index];
                  return _ActivityCard(
                    category: cat,
                    index: index,
                    lang: lang,
                    onTap: () => _onCategorySelected(cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),
          ],
          Text(
            lang.tr('providers', category: 'providers_list_page'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Exo2'),
          ),
          const SizedBox(height: 12),
          if (_isSearching)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_searchProviders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(lang.tr('no_results_found', category: 'search'), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchProviders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final provider = _searchProviders[index];
                return _SearchProviderResultTile(
                  provider: provider,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProviderProfileScreen(
                    provider: provider,
                    serviceCategory: provider.profession,
                  ),
                ),
              );
            },
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _notificationCountSubscription?.cancel();
    _userDataSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _subcategoriesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.isRtl
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          child: Scaffold(
            backgroundColor: isDark ? theme.scaffoldBackgroundColor : kLightBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HomeHeader(
                              currentUser: _currentUser,
                              searchController: _searchController,
                              focusNode: _searchFocusNode,
                              onSearchChanged: _onSearchChanged,
                              onSearchSubmitted: (query) {
                                if (query.trim().isNotEmpty) {
                                  _searchFocusNode.unfocus();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProvidersListPage(
                                        categoryName: '',
                                        subCategoryName: '',
                                        searchQuery: query,
                                      ),
                                    ),
                                  );
                                }
                              },
                              notificationCount: _notificationCount,
                              onNotificationPressed: _showNotifications,
                            ),
                            if (_searchQuery.isEmpty) ...[
                              _buildFilterChips(languageProvider),
                              const SizedBox(height: 25),
                              _buildSectionHeader(
                                languageProvider,
                                title: languageProvider.tr('browse_activity', category: 'home_page'),
                                showSeeAll: false,
                              ),
                              const SizedBox(height: 15),
                              _buildQuickCategoriesRow(languageProvider),
                              const SizedBox(height: 30),
                              _buildSectionHeader(
                                languageProvider,
                                title: languageProvider.tr('popular_destination', category: 'home_page'),
                                showSeeAll: true,
                                onSeeAll: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProvidersListPage(categoryName: '', subCategoryName: ''),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 15),
                              _buildPopularProviders(languageProvider),
                            ] else ...[
                              _buildSearchResults(languageProvider),
                            ],
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

  Widget _buildFilterChips(LanguageProvider lang) {
    if (_searchQuery.isNotEmpty) return const SizedBox.shrink();

    final filters = [
      {'id': 'all', 'label': lang.tr('all', category: 'home_page')},
      {'id': 'popular', 'label': lang.tr('popular', category: 'home_page')},
      {'id': 'recommended', 'label': lang.tr('recommended', category: 'home_page')},
      {'id': 'most_viewed', 'label': lang.tr('most_viewed', category: 'home_page')},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 15),
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['id'];
          return GestureDetector(
            onTap: () => _onFilterChanged(filter['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryBlue : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
              ),
              child: Center(
                child: Text(
                  filter['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : kMutedTextColor,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(LanguageProvider lang, {required String title, required bool showSeeAll, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Exo2',
              color: kDarkTextColor,
            ),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: const Icon(Icons.more_horiz, color: kMutedTextColor),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoriesRow(LanguageProvider lang) {
    if (_isLoadingCategories) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    final quickCats = _categories.take(8).toList();

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: quickCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final cat = quickCats[index];
          return _ActivityCard(
            category: cat,
            index: index,
            lang: lang,
            onTap: () => _onCategorySelected(cat),
          );
        },
      ),
    );
  }

  Widget _buildPopularProviders(LanguageProvider lang) {
    if (_isLoadingFeatured) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    if (_featuredProviders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text("No featured providers available", style: TextStyle(color: kMutedTextColor)),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _featuredProviders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final provider = _featuredProviders[index];
          return _PopularProviderCard(
            provider: provider,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProviderProfileScreen(
                    provider: provider,
                    serviceCategory: provider.profession,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Activity Card (Category)
// ──────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final CategoryModel category;
  final int index;
  final LanguageProvider lang;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.category,
    required this.index,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            Container(
              height: 110,
              width: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildVisual(),
                    // Gradient overlay at bottom
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.getTranslatedName(lang),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
                color: kDarkTextColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisual() {
    final imageUrl = category.iconUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (ImageUtils.isBase64Image(imageUrl)) {
        final bytes = ImageUtils.decodeBase64Image(imageUrl);
        if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      } else {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.blue.shade50),
          errorWidget: (_, __, ___) => _fallback(),
        );
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: kPrimaryBlue.withOpacity(0.05),
      child: Icon(category.icon, color: kPrimaryBlue, size: 30),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Popular Provider Card
// ──────────────────────────────────────────────────────────────
class _PopularProviderCard extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback onTap;

  const _PopularProviderCard({
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Image Area
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      child: provider.photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: provider.photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: kPrimaryBlue.withOpacity(0.05)),
                              errorWidget: (_, __, ___) => _fallbackImage(),
                            )
                          : _fallbackImage(),
                    ),
                  ),
                  // Heart Icon
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // Info Area
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "${provider.rating.toStringAsFixed(1)} (2k)",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Exo2'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    provider.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Exo2', color: kDarkTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: kPrimaryBlue.withOpacity(0.05),
      child: const Icon(Icons.person, color: kPrimaryBlue, size: 40),
    );
  }
}

// Re-defining for subcategory support within home
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildVisual(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Exo2', color: kDarkTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVisual() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (ImageUtils.isBase64Image(imageUrl)) {
        final bytes = ImageUtils.decodeBase64Image(imageUrl);
        if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      } else {
        return CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: kPrimaryBlue.withOpacity(0.05)),
          errorWidget: (_, __, ___) => _fallback(),
        );
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: kPrimaryBlue.withOpacity(0.05),
      child: Icon(icon, color: kPrimaryBlue, size: 28),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Search Provider Result Tile
// ──────────────────────────────────────────────────────────────
class _SearchProviderResultTile extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback onTap;

  const _SearchProviderResultTile({
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryBlue.withOpacity(0.05),
              ),
              child: ClipOval(
                child: provider.photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: provider.photoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.person, color: kPrimaryBlue),
                      )
                    : const Icon(Icons.person, color: kPrimaryBlue),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Exo2'),
                  ),
                  Text(
                    provider.profession,
                    style: const TextStyle(color: kMutedTextColor, fontSize: 12, fontFamily: 'Exo2'),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 2),
                Text(
                  provider.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
