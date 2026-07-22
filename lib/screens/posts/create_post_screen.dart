import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'posts_constants.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/CategoryModel.dart';
import 'package:service_app/Services/firebase_service.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  
  late PostType _selectedType;
  CategoryModel? _selectedCategory;
  SubcategoryModel? _selectedSubcategory;
  List<CategoryModel> _categories = [];
  List<SubcategoryModel> _subcategories = [];
  List<XFile> _selectedImages = [];
  bool _isLoadingCategories = false;
  bool _isLoadingSubcategories = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Enforce role-based post type
    if (widget.user.isProvider) {
      _selectedType = PostType.offering;
    } else {
      _selectedType = PostType.seeking;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await FirebaseService.getCategoriesList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    setState(() {
      _isLoadingSubcategories = true;
      _subcategories = [];
      _selectedSubcategory = null;
    });
    try {
      FirebaseService.getSubCategories(categoryId).listen((subcats) {
        if (mounted) {
          setState(() {
            _subcategories = subcats;
            _isLoadingSubcategories = false;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSubcategories = false);
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await widget.imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _submit() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.tr('please_select_category', category: 'posts'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String> imageUrls = [];

      final post = Post(
        id: '', 
        title: _titleController.text,
        body: _bodyController.text,
        user: widget.user.name,
        userId: widget.user.uid,
        userPhotoUrl: widget.user.photoUrl ?? '',
        type: _selectedType,
        serviceCategory: _selectedCategory!.name,
        serviceCategoryKey: ServiceCategoryTranslator.getCategoryKey(_selectedCategory!.name),
        serviceSubcategory: _selectedSubcategory?.name ?? '',
        serviceSubcategoryKey: _selectedSubcategory != null 
            ? ServiceCategoryTranslator.getSubcategoryKey(_selectedSubcategory!.name, category: _selectedCategory!.name)
            : '',
        timestamp: DateTime.now(),
        imageUrls: imageUrls,
      );

      widget.onPostCreated(post);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ),
                Text(
                  languageProvider.tr('create_post', category: 'posts'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2',
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: TextButton.styleFrom(
                    backgroundColor: kPrimaryBlue.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryBlue),
                        )
                      : Text(
                          languageProvider.tr('publish', category: 'posts'),
                          style: const TextStyle(
                            color: kPrimaryBlue,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Exo2',
                          ),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: kPrimaryBlue.withValues(alpha: 0.05),
                          backgroundImage: (widget.user.photoUrl.isNotEmpty)
                              ? ImageUtils.getImageProvider(widget.user.photoUrl)
                              : null,
                          child: (widget.user.photoUrl.isEmpty)
                              ? const Icon(Icons.person, color: kPrimaryBlue, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            Text(
                              widget.user.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Service Type Display (Enforced by role)
                    Text(
                      languageProvider.tr('post_type', category: 'posts').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PostTypeChip(
                          label: languageProvider.tr('looking_for', category: 'posts'),
                          icon: CupertinoIcons.search,
                          isSelected: _selectedType == PostType.seeking,
                          isDisabled: widget.user.isProvider,
                          onTap: () {
                            if (!widget.user.isProvider) {
                              setState(() => _selectedType = PostType.seeking);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _PostTypeChip(
                          label: languageProvider.tr('offering', category: 'posts'),
                          icon: CupertinoIcons.briefcase,
                          isSelected: _selectedType == PostType.offering,
                          isDisabled: widget.user.isClient,
                          onTap: () {
                            if (!widget.user.isClient) {
                              setState(() => _selectedType = PostType.offering);
                            }
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Service Title
                    _FieldLabel(label: languageProvider.tr('title', category: 'posts')),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Exo2',
                      ),
                      decoration: InputDecoration(
                        hintText: languageProvider.tr('title_hint', category: 'posts'),
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kPrimaryBlue, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (value) => value == null || value.isEmpty ? languageProvider.tr('required_field', category: 'posts') : null,
                    ),

                    const SizedBox(height: 24),

                    // Service Description
                    _FieldLabel(label: languageProvider.tr('description', category: 'posts')),
                    TextFormField(
                      controller: _bodyController,
                      maxLines: 5,
                      minLines: 3,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Exo2',
                        height: 1.4,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: languageProvider.tr('description_hint', category: 'posts'),
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400, fontSize: 15),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) => value == null || value.isEmpty ? languageProvider.tr('required_field', category: 'posts') : null,
                    ),

                    const SizedBox(height: 24),

                    // Category Selection
                    _FieldLabel(label: languageProvider.tr('category', category: 'posts')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<CategoryModel>(
                              value: _selectedCategory,
                              dropdownColor: theme.cardColor,
                              icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Exo2',
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                prefixIcon: Icon(CupertinoIcons.square_grid_2x2, size: 20, color: kPrimaryBlue),
                                prefixIconConstraints: BoxConstraints(minWidth: 40),
                              ),
                              isExpanded: true,
                              items: _categories.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat.getTranslatedName(languageProvider)),
                              )).toList(),
                              onChanged: (value) {
                                setState(() => _selectedCategory = value);
                                if (value != null) _loadSubcategories(value.id);
                              },
                              hint: Text(
                                languageProvider.tr('select_category', category: 'posts'),
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                              ),
                            ),
                          ),
                          if (_selectedCategory != null) ...[
                            Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                            DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<SubcategoryModel>(
                                value: _selectedSubcategory,
                                dropdownColor: theme.cardColor,
                                icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Exo2',
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(CupertinoIcons.list_bullet, size: 20, color: kPrimaryBlue),
                                  prefixIconConstraints: BoxConstraints(minWidth: 40),
                                ),
                                isExpanded: true,
                                items: _subcategories.map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub.getTranslatedName(languageProvider)),
                                )).toList(),
                                onChanged: (value) => setState(() => _selectedSubcategory = value),
                                hint: Text(
                                  languageProvider.tr('select_subcategory', category: 'posts'),
                                  style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Image Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FieldLabel(label: languageProvider.tr('images', category: 'posts')),
                        GestureDetector(
                          onTap: _pickImages,
                          child: Text(
                            languageProvider.tr('add_images', category: 'posts'),
                            style: const TextStyle(
                              color: kPrimaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImages.isEmpty)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade200, 
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.camera, color: isDark ? Colors.white38 : Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                languageProvider.tr('tap_to_add_photos', category: 'posts'),
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_selectedImages[index].path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _PostTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PostTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool active = isSelected && !isDisabled;
    
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active 
                ? kPrimaryBlue 
                : (isDisabled 
                    ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100) 
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active 
                  ? kPrimaryBlue 
                  : (isDisabled 
                      ? (isDark ? Colors.white12 : Colors.grey.shade200) 
                      : (isDark ? Colors.white24 : Colors.grey.shade200)),
            ),
            boxShadow: active ? [
              BoxShadow(
                color: kPrimaryBlue.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active 
                    ? Colors.white 
                    : (isDisabled 
                        ? (isDark ? Colors.white24 : Colors.grey.shade300) 
                        : (isDark ? Colors.white70 : Colors.grey.shade600)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active 
                      ? Colors.white 
                      : (isDisabled 
                          ? (isDark ? Colors.white24 : Colors.grey.shade300) 
                          : (isDark ? Colors.white : Colors.grey.shade700)),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'Exo2',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
