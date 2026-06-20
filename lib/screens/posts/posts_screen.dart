import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/utils/image_optimizer.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'posts_constants.dart';
import 'package:service_app/screens/posts/posts_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart' as home_const;

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
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
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
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    try {
      await _firestoreService.addPost(post);
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          post.type == PostType.seeking
              ? languageProvider.tr('request_published', category: 'posts')
              : languageProvider.tr('offer_published', category: 'posts'),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
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
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      AppSnackBar.showError(
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
    switch (_selectedFilter) {
      case PostFilterType.seeking:
        return posts.where((post) => post.type == PostType.seeking).toList();
      case PostFilterType.offering:
        return posts.where((post) => post.type == PostType.offering).toList();
      default:
        return posts;
    }
  }

  Widget _buildFilterChip(PostFilterType type, String labelKey) {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);
    final isSelected = _selectedFilter == type;

    return GestureDetector(
      onTap: () {
        if (_selectedFilter != type) {
          setState(() => _selectedFilter = type);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.white.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Text(
          languageProvider.tr(labelKey, category: 'posts'),
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const PostSkeleton(),
    );
  }

  Widget _buildErrorState() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return ErrorStateWidget(
      message: languageProvider.tr('unable_to_load_posts', category: 'posts'),
      onRetry: _refreshData,
    );
  }

  Widget _buildEmptyState() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return EmptyStateWidget(
      icon: Icons.description_outlined,
      message: languageProvider.tr('no_posts_yet', category: 'posts'),
      subtitle: languageProvider.tr('be_first_to_share', category: 'posts'),
      action: ElevatedButton(
        onPressed: _showCreatePostModal,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          languageProvider.tr('create_first_post', category: 'posts'),
        ),
      ),
    );
  }

  Widget _buildPostsList(List<Post> filteredPosts) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: theme.primaryColor,
      backgroundColor: theme.cardColor,
      displacement: 40,
      edgeOffset: 0,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredPosts.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: filteredPosts[index]),
          );
        },
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return EmptyStateWidget(
      icon: _selectedFilter == PostFilterType.seeking
          ? Icons.search
          : Icons.work_outline,
      message: _selectedFilter == PostFilterType.seeking
          ? languageProvider.tr('no_requests_yet', category: 'posts')
          : languageProvider.tr('no_offers_yet', category: 'posts'),
      subtitle: _selectedFilter == PostFilterType.seeking
          ? languageProvider.tr('no_one_looking', category: 'posts')
          : languageProvider.tr('no_services_offered',
          category: 'posts'),
      action: ElevatedButton(
        onPressed: _showCreatePostModal,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          _selectedFilter == PostFilterType.seeking
              ? languageProvider.tr('post_request', category: 'posts')
              : languageProvider.tr('offer_service', category: 'posts'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primaryColor,
                theme.primaryColor.withOpacity(0.8),
                theme.primaryColor.withOpacity(0.6),
                theme.primaryColor.withOpacity(0.4),
              ],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.only(
                  top: 10,
                  left: 25,
                  right: 25,
                  bottom: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Text(
                              languageProvider.tr('service_exchange',
                                  category: 'posts'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            CupertinoIcons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFilterChip(PostFilterType.all, 'all_posts'),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                                PostFilterType.seeking, 'requests'),
                            const SizedBox(width: 8),
                            _buildFilterChip(PostFilterType.offering, 'offers'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content area with rounded top corners
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: StreamBuilder<List<Post>>(
                    stream: _firestoreService.getPostsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _buildLoadingState();
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState();
                      }

                      final posts = snapshot.data ?? [];

                      if (posts.isEmpty) {
                        return _selectedFilter == PostFilterType.all
                            ? _buildEmptyState()
                            : _buildFilteredEmptyState();
                      }

                      final filteredPosts = _filterPosts(posts);

                      if (filteredPosts.isEmpty) {
                        return _buildFilteredEmptyState();
                      }

                      return RefreshIndicator(
                        onRefresh: _refreshData,
                        color: theme.primaryColor,
                        backgroundColor: theme.cardColor,
                        displacement: 40,
                        edgeOffset: 0,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: filteredPosts.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: PostCard(post: filteredPosts[index]),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
        onPressed: _scrollToTop,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.arrow_upward),
      )
          : FloatingActionButton(
        onPressed: _showCreatePostModal,
        backgroundColor: theme.cardColor,
        foregroundColor: theme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class ImageViewerDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.9),
            ),
          ),
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imageProvider =
                ImageUtils.getImageProvider(widget.imageUrls[index]);

                if (imageProvider == null) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.red,
                            size: 50,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            languageProvider.tr('unable_to_load_image',
                                category: 'posts'),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 40,
            end: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.imageUrls.length > 1)
            PositionedDirectional(
              start: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    languageProvider.isRtl ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _currentIndex > 0
                      ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ),
            ),
          if (widget.imageUrls.length > 1)
            PositionedDirectional(
              end: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    languageProvider.isRtl ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _currentIndex < widget.imageUrls.length - 1
                      ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CreatePostModal extends StatefulWidget {
  final Function(Post) onPostCreated;
  final UserModel user;
  final ImagePicker imagePicker;

  const CreatePostModal({
    super.key,
    required this.onPostCreated,
    required this.user,
    required this.imagePicker,
  });

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  PostType _type = PostType.seeking;
  late List<CategoryModel> _categories;
  CategoryModel? _selectedCategory;
  SubcategoryModel? _selectedSubcategory;
  final List<File> _selectedImages = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.user.isProvider ? PostType.offering : PostType.seeking;
    _categories = home_const.defaultCategories;

    // Set default category
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.firstWhere(
            (c) => c.name == 'Other',
        orElse: () => _categories.first,
      );
      if (_selectedCategory != null &&
          _selectedCategory!.subcategories.isNotEmpty) {
        _selectedSubcategory = _selectedCategory!.subcategories.first;
      }
    }
  }

  Future<void> _pickImages() async {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    try {
      final List<XFile> pickedFiles = await widget.imagePicker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (pickedFiles.isNotEmpty) {
        for (final pickedFile in pickedFiles) {
          if (_selectedImages.length >= 3) {
            _showSnackBar(
              languageProvider.tr('maximum_3_images', category: 'posts'),
              Colors.orange,
            );
            break;
          }

          final file = File(pickedFile.path);

          // Check file size
          final fileSize = await file.length();
          final fileSizeInKB = fileSize / 1024;

          if (fileSizeInKB > 2000) {
            _showSnackBar(
              languageProvider.trParams(
                'image_too_large',
                category: 'posts',
                params: {'size': fileSizeInKB.toStringAsFixed(0)},
              ),
              Colors.orange,
            );
            continue;
          }

          setState(() {
            _selectedImages.add(file);
          });
        }
      }
    } catch (e) {
      _showSnackBar(
        languageProvider.trParams(
          'error_selecting_images',
          category: 'posts',
          params: {'error': e.toString()},
        ),
        Colors.red,
      );
    }
  }

  Future<void> _takePhoto() async {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    try {
      final XFile? photo = await widget.imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (photo != null && _selectedImages.length < 3) {
        final file = File(photo.path);

        // Check file size
        final fileSize = await file.length();
        final fileSizeInKB = fileSize / 1024;

        if (fileSizeInKB > 2000) {
          _showSnackBar(
            languageProvider.trParams(
              'image_too_large',
              category: 'posts',
              params: {'size': fileSizeInKB.toStringAsFixed(0)},
            ),
            Colors.orange,
          );
          return;
        }

        setState(() {
          _selectedImages.add(file);
        });
      } else if (_selectedImages.length >= 3) {
        _showSnackBar(
          languageProvider.tr('maximum_3_images_reached', category: 'posts'),
          Colors.orange,
        );
      }
    } catch (e) {
      _showSnackBar(
        languageProvider.trParams(
          'error_taking_photo',
          category: 'posts',
          params: {'error': e.toString()},
        ),
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    if (color == Colors.red) {
      AppSnackBar.showError(context, message);
    } else if (color == Colors.green) {
      AppSnackBar.showSuccess(context, message);
    } else {
      AppSnackBar.showWarning(context, message);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _submitPost() async {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      _showSnackBar(
        languageProvider.tr('must_be_logged_in', category: 'posts'),
        kSeekingColor,
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      List<String> base64Images = [];

      // Compress and convert images
      if (_selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];

          final compressedBytes = await ImageOptimizer.compressImage(
            file,
            maxSizeKB: 50,
            maxWidth: 800,
            maxHeight: 800,
          );

          final base64String = base64Encode(compressedBytes);
          final base64Image = 'data:image/jpeg;base64,$base64String';

          if (base64Image.length > 70000) {
            print('Image $i too large, skipping');
            continue;
          }

          base64Images.add(base64Image);
        }
      }

      final newPost = Post(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        body: _bodyController.text,
        user: widget.user.name,
        userId: widget.user.uid,
        type: _type,
        serviceCategory: _selectedCategory?.name ?? 'Other',
        serviceSubcategory: _selectedSubcategory?.name ?? '',
        timestamp: DateTime.now(),
        imageUrls: base64Images,
      );

      widget.onPostCreated(newPost);

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(
          base64Images.isEmpty
              ? languageProvider.tr('post_created_successfully',
              category: 'posts')
              : languageProvider.trParams(
            'post_created_with_images',
            category: 'posts',
            params: {'count': base64Images.length.toString()},
          ),
          Colors.green,
        );
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        _showSnackBar(
          languageProvider.trParams(
            'error_creating_post',
            category: 'posts',
            params: {'error': e.toString()},
          ),
          Colors.red,
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildImageGrid() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_selectedImages.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.trParams(
              'selected_images',
              category: 'posts',
              params: {'count': _selectedImages.length.toString()},
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      PositionedDirectional(
                        top: 2,
                        end: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final typeColor =
    _type == PostType.seeking ? kSeekingColor : kOfferingColor;
    final bool isProvider = widget.user.isProvider;

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageProvider.tr('create_post', category: 'posts'),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    color: theme.brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isProvider
                    ? languageProvider.tr('share_services', category: 'posts')
                    : languageProvider.tr('let_providers_know',
                    category: 'posts'),
                style: TextStyle(
                  color: theme.brightness == Brightness.dark ? Colors.white54 : kMutedTextColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isProvider ? Icons.work : Icons.search,
                      color: typeColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isProvider
                          ? languageProvider.tr('i_offer_service',
                          category: 'posts')
                          : languageProvider.tr('i_need_service',
                          category: 'posts'),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: languageProvider.tr('title', category: 'posts'),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                maxLength: 60,
                validator: (value) => value!.isEmpty
                    ? languageProvider.tr('title_cannot_be_empty',
                    category: 'posts')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText:
                  languageProvider.tr('description', category: 'posts'),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                maxLines: 4,
                maxLength: 300,
                validator: (value) => value!.length < 10
                    ? languageProvider.tr('description_too_short',
                    category: 'posts')
                    : null,
              ),
              const SizedBox(height: 12),
              // Category Selection
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButton<CategoryModel>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: theme.cardColor,
                  icon: Icon(Icons.arrow_drop_down,
                      color: theme.primaryColor),
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 15, fontFamily: 'Exo2'),
                  underline: const SizedBox(),
                  onChanged: (CategoryModel? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                        _selectedSubcategory = newValue.subcategories.isNotEmpty
                            ? newValue.subcategories.first
                            : null;
                      });
                    }
                  },
                  items: _categories.map((CategoryModel cat) {
                    return DropdownMenuItem<CategoryModel>(
                      value: cat,
                      child: Text(cat.getTranslatedName(languageProvider)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // Subcategory Selection
              if (_selectedCategory != null &&
                  _selectedCategory!.subcategories.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: DropdownButton<SubcategoryModel>(
                    value: _selectedSubcategory,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    icon: Icon(Icons.arrow_drop_down,
                        color: theme.primaryColor),
                    style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 15,
                        fontFamily: 'Exo2'),
                    underline: const SizedBox(),
                    onChanged: (SubcategoryModel? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedSubcategory = newValue);
                      }
                    },
                    items: _selectedCategory!.subcategories
                        .map((SubcategoryModel sub) {
                      return DropdownMenuItem<SubcategoryModel>(
                        value: sub,
                        child: Text(sub.getTranslatedName(languageProvider)),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                languageProvider.tr('add_images', category: 'posts'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickImages,
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: Text(
                          languageProvider.tr('gallery', category: 'posts')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.cardColor,
                        foregroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: theme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text(
                          languageProvider.tr('camera', category: 'posts')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.cardColor,
                        foregroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: theme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _buildImageGrid(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  languageProvider.tr('publish_post', category: 'posts'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}