import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart' as ui;
import 'posts_constants.dart';
import 'package:service_app/screens/posts/posts_widgets.dart';
import 'package:service_app/screens/posts/create_post_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/screens/profile/profile_page.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';

enum PostFilterType { all, seeking, offering }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isRefreshing = false;
  PostFilterType _selectedFilter = PostFilterType.all;
  CategoryModel? _selectedCategory;
  SubcategoryModel? _selectedSubcategory;
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoadingCategories = true);
    try {
      final categories = await FirebaseService.getCategoriesList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories for feed: $e');
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final showButton = _scrollController.offset > 300;
      if (showButton != _showScrollToTop) {
        setState(() => _showScrollToTop = showButton);
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleCreatePost(Post post) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    try {
      await _firestoreService.addPost(post);
      if (mounted) {
        ui.AppSnackBar.showSuccess(
          context,
          post.type == PostType.seeking
              ? languageProvider.tr('request_published', category: 'posts')
              : languageProvider.tr('offer_published', category: 'posts'),
        );
      }
    } catch (e) {
      if (mounted) {
        ui.AppSnackBar.showError(
          context,
          languageProvider.trParams(
            'error_creating_post',
            category: 'posts',
            params: {'error': e.toString()},
          ),
        );
      }
    }
  }

  void _showCreatePostModal() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      ui.AppSnackBar.showError(
        context,
        languageProvider.tr('please_sign_in', category: 'posts'),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreatePostModal(
          onPostCreated: _handleCreatePost,
          user: currentUser,
          imagePicker: ImagePicker(),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  List<Post> _filterPosts(List<Post> posts) {
    List<Post> filtered = posts;
    switch (_selectedFilter) {
      case PostFilterType.seeking:
        filtered = filtered.where((post) => post.type == PostType.seeking).toList();
        break;
      case PostFilterType.offering:
        filtered = filtered.where((post) => post.type == PostType.offering).toList();
        break;
      default:
        break;
    }
    if (_selectedCategory != null) {
      filtered = filtered.where((post) => post.serviceCategory == _selectedCategory!.name).toList();
    }
    if (_selectedSubcategory != null) {
      filtered = filtered.where((post) => post.serviceSubcategory == _selectedSubcategory!.name).toList();
    }
    return filtered;
  }

  void _showFilterBottomSheet() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.tr('filters', category: 'posts'),
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        fontFamily: 'Exo2',
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedFilter = PostFilterType.all;
                          _selectedCategory = null;
                          _selectedSubcategory = null;
                        });
                        setState(() {});
                      },
                      child: Text(
                        languageProvider.tr('reset', category: 'common'),
                        style: TextStyle(color: theme.primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Post Type Filter
                Text(
                  languageProvider.tr('post_type', category: 'posts').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w800, 
                    color: isDark ? Colors.white54 : Colors.grey.shade500, 
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _FilterChip(
                      label: languageProvider.tr('all', category: 'common'),
                      isSelected: _selectedFilter == PostFilterType.all,
                      onTap: () {
                        setModalState(() => _selectedFilter = PostFilterType.all);
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: languageProvider.tr('looking_for', category: 'posts'),
                      isSelected: _selectedFilter == PostFilterType.seeking,
                      onTap: () {
                        setModalState(() => _selectedFilter = PostFilterType.seeking);
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: languageProvider.tr('offering', category: 'posts'),
                      isSelected: _selectedFilter == PostFilterType.offering,
                      onTap: () {
                        setModalState(() => _selectedFilter = PostFilterType.offering);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Category Filter
                Text(
                  languageProvider.tr('category', category: 'posts').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w800, 
                    color: isDark ? Colors.white54 : Colors.grey.shade500, 
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      DropdownButtonFormField<CategoryModel>(
                        value: _selectedCategory,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontFamily: 'Exo2'),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        items: _categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.getTranslatedName(languageProvider)),
                        )).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            _selectedCategory = val;
                            _selectedSubcategory = null;
                          });
                          setState(() {});
                        },
                        hint: Text(
                          languageProvider.tr('select_category', category: 'posts'),
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                        ),
                      ),
                      if (_selectedCategory != null) ...[
                        const SizedBox(height: 16),
                        StreamBuilder<List<SubcategoryModel>>(
                          stream: FirebaseService.getSubCategories(_selectedCategory!.id),
                          builder: (context, snapshot) {
                            final subs = snapshot.data ?? [];
                            return DropdownButtonFormField<SubcategoryModel>(
                              value: _selectedSubcategory,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontFamily: 'Exo2'),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              items: subs.map((sub) => DropdownMenuItem(
                                value: sub,
                                child: Text(sub.getTranslatedName(languageProvider)),
                              )).toList(),
                              onChanged: (val) {
                                setModalState(() => _selectedSubcategory = val);
                                setState(() {});
                              },
                              hint: Text(
                                languageProvider.tr('select_subcategory', category: 'posts'),
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(languageProvider.tr('apply_filters', category: 'posts')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authVM = Provider.of<AuthViewModel>(context);
    final currentUser = authVM.currentUser;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFFBFBFF),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => _navigateToProfile(currentUser),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.1), width: 1.5),
              ),
              child: CircleAvatar(
                backgroundColor: kPrimaryBlue.withValues(alpha: 0.05),
                backgroundImage: (currentUser?.photoUrl != null && currentUser!.photoUrl.isNotEmpty)
                    ? ImageUtils.getImageProvider(currentUser.photoUrl)
                    : null,
                child: (currentUser?.photoUrl == null || currentUser!.photoUrl.isEmpty)
                    ? const Icon(Icons.person, color: kPrimaryBlue, size: 20)
                    : null,
              ),
            ),
          ),
        ),
        title: Text(
          languageProvider.tr('feed', category: 'posts'),
          style: const TextStyle(
            color: kPrimaryBlue,
            fontWeight: FontWeight.bold,
            fontFamily: 'Exo2',
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.slider_horizontal_3, color: kPrimaryBlue),
            onPressed: _showFilterBottomSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Facebook-style "What's on your mind?" bar
            _buildFacebookStyleCreateBar(currentUser, languageProvider),

            const SizedBox(height: 12),

            // Posts List
            Expanded(
              child: StreamBuilder<List<Post>>(
                stream: _firestoreService.getPostsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 5,
                      itemBuilder: (context, index) => const ui.PostSkeleton(),
                    );
                  }

                  if (snapshot.hasError) {
                    return ui.ErrorStateWidget(
                      message: languageProvider.tr('unable_to_load_posts', category: 'posts'),
                      onRetry: _refreshData,
                    );
                  }

                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return ui.EmptyStateWidget(
                      icon: Icons.description_outlined,
                      message: languageProvider.tr('no_posts_yet', category: 'posts'),
                    );
                  }

                  final filteredPosts = _filterPosts(posts);

                  return RefreshIndicator(
                    onRefresh: _refreshData,
                    color: kPrimaryBlue,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filteredPosts.length,
                      itemBuilder: (context, index) {
                        return PostCard(post: filteredPosts[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(UserModel? user) {
    if (user == null) return;
    
    if (user.isProvider) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderProfileScreen(
            provider: ProviderModel.fromUser(user),
            serviceCategory: user.profession ?? 'Service Provider',
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage(user: user)),
      );
    }
  }

  Widget _buildFacebookStyleCreateBar(UserModel? user, LanguageProvider lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFFBFBFF);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Row(
        children: [
          // User Avatar
          GestureDetector(
            onTap: () => _navigateToProfile(user),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.1), width: 2),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: kPrimaryBlue.withValues(alpha: 0.05),
                backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                    ? ImageUtils.getImageProvider(user.photoUrl!)
                    : null,
                child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: kPrimaryBlue)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // "What's on your mind?" - clickable area
          Expanded(
            child: GestureDetector(
              onTap: _showCreatePostModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: Text(
                  lang.tr('whats_on_your_mind', category: 'posts'),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontSize: 14,
                    fontFamily: 'Exo2',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _showCreatePostModal,
            icon: const Icon(CupertinoIcons.plus_circle_fill, color: kPrimaryBlue, size: 30),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryBlue : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPrimaryBlue : (isDark ? Colors.white12 : Colors.grey.shade300)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: 'Exo2',
          ),
        ),
      ),
    );
  }
}
