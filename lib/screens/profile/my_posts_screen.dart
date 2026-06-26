import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/posts/posts_constants.dart';
import 'package:service_app/screens/posts/posts_widgets.dart';
import 'package:service_app/utils/ui_widgets.dart' as ui;
import 'package:service_app/utils/image_optimizer.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/Services/firebase_service.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final currentUser = authVM.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr('myPosts', category: 'common'))),
        body: Center(child: Text(lang.tr('please_sign_in', category: 'posts'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.tr('myPosts', category: 'common'),
          style: const TextStyle(fontFamily: 'Exo2', fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Post>>(
        stream: _firestoreService.getUserPostsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ui.ErrorStateWidget(
              message: lang.tr('error_occurred', category: 'common'),
              onRetry: () => setState(() {}),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return ui.EmptyStateWidget(
              icon: Icons.description_outlined,
              message: lang.tr('no_posts_yet', category: 'posts'),
              subtitle: lang.tr('be_first_to_share', category: 'posts'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    PostCard(post: post),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showEditPostModal(post),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(lang.tr('edit', category: 'common')),
                            style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () => _confirmDelete(post),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(lang.tr('delete', category: 'common')),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditPostModal(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditPostModal(
          post: post,
          onPostUpdated: (updatedPost) async {
            try {
              await _firestoreService.updatePost(post.id, updatedPost.toMap());
              if (mounted) {
                ui.AppSnackBar.showSuccess(context, Provider.of<LanguageProvider>(context, listen: false).tr('save_success', category: 'admin'));
              }
            } catch (e) {
              if (mounted) {
                ui.AppSnackBar.showError(context, e.toString());
              }
            }
          },
        ),
      ),
    );
  }

  void _confirmDelete(Post post) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('delete_confirm_title', category: 'admin')),
        content: Text(lang.tr('delete_confirm_msg', category: 'admin')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('cancel', category: 'common')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.deletePost(post.id);
                if (mounted) {
                  ui.AppSnackBar.showSuccess(context, lang.tr('delete', category: 'common'));
                }
              } catch (e) {
                if (mounted) {
                  ui.AppSnackBar.showError(context, e.toString());
                }
              }
            },
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class EditPostModal extends StatefulWidget {
  final Post post;
  final Function(Post) onPostUpdated;

  const EditPostModal({
    super.key,
    required this.post,
    required this.onPostUpdated,
  });

  @override
  State<EditPostModal> createState() => _EditPostModalState();
}

class _EditPostModalState extends State<EditPostModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late PostType _type;
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  SubcategoryModel? _selectedSubcategory;
  List<String> _currentImageUrls = [];
  final List<File> _newImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _bodyController = TextEditingController(text: widget.post.body);
    _type = widget.post.type;
    _currentImageUrls = List.from(widget.post.imageUrls);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await FirebaseService.getCategoriesList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;

          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.firstWhere(
              (c) => c.name == widget.post.serviceCategory,
              orElse: () => _categories.firstWhere((c) => c.name == 'Other', orElse: () => _categories.first),
            );
            
            if (_selectedCategory != null && _selectedCategory!.subcategories.isNotEmpty) {
               _selectedSubcategory = _selectedCategory!.subcategories.firstWhere(
                (s) => s.name == widget.post.serviceSubcategory,
                orElse: () => _selectedCategory!.subcategories.first,
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var xf in pickedFiles) {
            if (_currentImageUrls.length + _newImages.length < 3) {
              _newImages.add(File(xf.path));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeCurrentImage(int index) {
    setState(() {
      _currentImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      List<String> finalImageUrls = List.from(_currentImageUrls);

      // Process new images to base64
      for (var file in _newImages) {
        final compressedBytes = await ImageOptimizer.compressImage(
          file,
          maxSizeKB: 50,
          maxWidth: 800,
          maxHeight: 800,
        );
        final base64String = base64Encode(compressedBytes);
        finalImageUrls.add('data:image/jpeg;base64,$base64String');
      }

      final updatedPost = widget.post.copyWith(
        title: _titleController.text,
        body: _bodyController.text,
        type: _type,
        serviceCategory: _selectedCategory?.name ?? widget.post.serviceCategory,
        serviceSubcategory: _selectedSubcategory?.name ?? widget.post.serviceSubcategory,
        imageUrls: finalImageUrls,
      );

      widget.onPostUpdated(updatedPost);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving post: $e');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang.tr('edit', category: 'common') + " " + lang.tr('create_post', category: 'posts'),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: lang.tr('title', category: 'posts'),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value!.isEmpty ? lang.tr('title_cannot_be_empty', category: 'posts') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: lang.tr('description', category: 'posts'),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value!.length < 10 ? lang.tr('description_too_short', category: 'posts') : null,
              ),
              const SizedBox(height: 12),
              if (_isLoadingCategories)
                const Center(child: CircularProgressIndicator())
              else ...[
                DropdownButtonFormField<CategoryModel>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: lang.tr('category', category: 'search'),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.getTranslatedName(lang)))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSubcategory = val?.subcategories.isNotEmpty == true ? val!.subcategories.first : null;
                    });
                  },
                ),
              ],
              const SizedBox(height: 20),
              Text(
                lang.tr('add_images', category: 'posts'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: (_currentImageUrls.length + _newImages.length < 3) ? _pickImages : null,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(_currentImageUrls.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image(
                                image: ImageUtils.getImageProvider(_currentImageUrls[index])!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeCurrentImage(index),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ...List.generate(_newImages.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _newImages[index],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeNewImage(index),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(lang.tr('save', category: 'common'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
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
