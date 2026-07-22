import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../models/CategoryModel.dart';
import '../../../providers/language_provider.dart';
import '../../../utils/image_utils.dart';
import '../../../utils/ui_widgets.dart';
import '../admin_components.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AdminViewModel>(
      builder: (context, vm, child) {
        final lang = context.watch<LanguageProvider>();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Header ----------
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.category_rounded, color: AdminColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.tr('categories_management', category: 'admin'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : AdminColors.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          lang.tr('manage_hierarchy_desc', category: 'admin'),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : AdminColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: AdminButton(
                      onPressed: () => _showCreationWizard(context, vm),
                      icon: Icons.add_rounded,
                      label: lang.tr('generate_new', category: 'admin'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ---------- Categories List ----------
              Expanded(
                child: vm.categories.isEmpty
                    ? AdminEmptyState(
                    title: lang.tr('no_categories_found', category: 'admin'),
                    subtitle: lang.tr('add_first_category', category: 'admin'),
                    icon: Icons.category_outlined
                )
                    : ListView.builder(
                  itemCount: vm.categories.length,
                  itemBuilder: (context, index) {
                    final cat = vm.categories[index];
                    return _buildCategoryCard(context, vm, cat, isDark);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(BuildContext context, AdminViewModel vm, CategoryModel cat, bool isDark) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AdminColors.primary.withOpacity(0.18),
                          AdminColors.primary.withOpacity(0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: cat.iconUrl != null && cat.iconUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ImageUtils.isBase64Image(cat.iconUrl)
                                  ? Builder(
                                      builder: (context) {
                                        final bytes = ImageUtils.decodeBase64Image(cat.iconUrl);
                                        if (bytes == null) {
                                          return Icon(cat.icon, color: AdminColors.primary, size: 22);
                                        }
                                        return Image.memory(bytes, fit: BoxFit.cover, width: 46, height: 46);
                                      },
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: cat.iconUrl!,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Icon(cat.icon, color: AdminColors.primary, size: 22),
                                    ),
                            )
                          : Icon(cat.icon, color: AdminColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.getTranslatedName(lang),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : AdminColors.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat.getTranslatedDescription(lang),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : AdminColors.textSecondary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: AdminStatusBadge(
                      label: cat.isActive ? 'ACTIVE' : 'DISABLED',
                      color: cat.isActive ? AdminColors.success : AdminColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white54 : AdminColors.textSecondary, size: 20),
                        onPressed: () => _showCreationWizard(context, vm, category: cat),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 20),
                        onPressed: () => _confirmDelete(context, () => vm.deleteCategory(cat.id), 'Category'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : AdminColors.background.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang.tr('subcategories', category: 'admin').toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                            color: isDark ? Colors.white60 : AdminColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showCreationWizard(context, vm, parentId: cat.id),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(lang.tr('add_sub', category: 'admin'), overflow: TextOverflow.ellipsis),
                        style: TextButton.styleFrom(
                          foregroundColor: AdminColors.primary,
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (cat.subcategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        lang.tr('no_subcategories_yet', category: 'admin'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : AdminColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cat.subcategories.map((sub) => GestureDetector(
                        onTap: () => _showCreationWizard(context, vm, parentId: cat.id, subcategory: sub),
                        child: Chip(
                          label: Text(sub.getTranslatedName(lang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: isDark ? const Color(0xFF1C1F26) : Colors.white,
                          labelStyle: TextStyle(color: isDark ? Colors.white : AdminColors.textMain),
                          avatar: sub.imageUrl != null 
                              ? CircleAvatar(
                                  backgroundImage: ImageUtils.isBase64Image(sub.imageUrl)
                                      ? (ImageUtils.decodeBase64Image(sub.imageUrl) != null 
                                          ? MemoryImage(ImageUtils.decodeBase64Image(sub.imageUrl)!) 
                                          : null)
                                      : CachedNetworkImageProvider(sub.imageUrl!) as ImageProvider,
                                  radius: 10,
                                )
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                          ),
                          deleteIcon: Icon(Icons.close_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                          onDeleted: () => _confirmDelete(context, () => vm.deleteSubcategory(cat.id, sub.id), 'Subcategory'),
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreationWizard(BuildContext context, AdminViewModel vm, {CategoryModel? category, SubcategoryModel? subcategory, String? parentId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CategoryCreationWizard(
        vm: vm,
        initialCategory: category,
        initialSubcategory: subcategory,
        initialParentId: parentId,
      ),
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_rounded, color: AdminColors.danger, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.trParams('delete_confirm_title_type', category: 'admin', params: {'type': type}),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: isDark ? Colors.white : AdminColors.textMain),
              ),
            ),
          ],
        ),
        content: Text(
          lang.trParams('delete_confirm_msg_type', category: 'admin', params: {'type': type}),
          style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.tr('cancel', category: 'common'), style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: AdminColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class CategoryCreationWizard extends StatefulWidget {
  final AdminViewModel vm;
  final CategoryModel? initialCategory;
  final SubcategoryModel? initialSubcategory;
  final String? initialParentId;

  const CategoryCreationWizard({
    super.key,
    required this.vm,
    this.initialCategory,
    this.initialSubcategory,
    this.initialParentId,
  });

  @override
  State<CategoryCreationWizard> createState() => _CategoryCreationWizardState();
}

class _CategoryCreationWizardState extends State<CategoryCreationWizard> {
  int _currentStep = 0;
  bool _isSubcategory = false;
  String? _selectedParentId;

  // Controllers
  final _internalNameCtrl = TextEditingController();
  final _internalDescCtrl = TextEditingController();

  final _nameEnCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _nameFrCtrl = TextEditingController();

  final _descEnCtrl = TextEditingController();
  final _descArCtrl = TextEditingController();
  final _descFrCtrl = TextEditingController();

  String? _localImagePath;
  String? _remoteImageUrl;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _isSubcategory = widget.initialSubcategory != null || widget.initialParentId != null;
    _selectedParentId = widget.initialParentId ?? widget.initialSubcategory?.categoryId;

    if (widget.initialCategory != null) {
      _populateFromCategory(widget.initialCategory!);
    } else if (widget.initialSubcategory != null) {
      _populateFromSubcategory(widget.initialSubcategory!);
    }

    // Skip selection steps if editing or adding sub from a specific category
    if (widget.initialCategory != null) {
      _currentStep = 1; // Basic Details
    } else if (widget.initialSubcategory != null) {
      _currentStep = 2; // Basic Details (skip type selection and parent selection)
    } else if (widget.initialParentId != null) {
      _currentStep = 1; // Basic Details (skip type selection, parent already known)
    }
  }

  void _populateFromCategory(CategoryModel cat) {
    _internalNameCtrl.text = cat.name;
    _internalDescCtrl.text = cat.description;
    _nameEnCtrl.text = cat.nameTranslations['en'] ?? '';
    _nameArCtrl.text = cat.nameTranslations['ar'] ?? '';
    _nameFrCtrl.text = cat.nameTranslations['fr'] ?? '';
    _descEnCtrl.text = cat.descriptionTranslations['en'] ?? '';
    _descArCtrl.text = cat.descriptionTranslations['ar'] ?? '';
    _descFrCtrl.text = cat.descriptionTranslations['fr'] ?? '';
    _remoteImageUrl = cat.iconUrl;
    _isActive = cat.isActive;
  }

  void _populateFromSubcategory(SubcategoryModel sub) {
    _internalNameCtrl.text = sub.name;
    _internalDescCtrl.text = sub.description;
    _nameEnCtrl.text = sub.nameTranslations['en'] ?? '';
    _nameArCtrl.text = sub.nameTranslations['ar'] ?? '';
    _nameFrCtrl.text = sub.nameTranslations['fr'] ?? '';
    _descEnCtrl.text = sub.descriptionTranslations['en'] ?? '';
    _descArCtrl.text = sub.descriptionTranslations['ar'] ?? '';
    _descFrCtrl.text = sub.descriptionTranslations['fr'] ?? '';
    _remoteImageUrl = sub.imageUrl;
  }

  int get _totalSteps => _isSubcategory ? 5 : 4;

  String? _getValidationError() {
    if (_isSubcategory && _currentStep == 1 && _selectedParentId == null) {
      return context.read<LanguageProvider>().tr('please_select_parent', category: 'admin');
    }

    int basicDetailsStep = _isSubcategory ? 2 : 1;
    if (_currentStep == basicDetailsStep) {
      final name = _internalNameCtrl.text.trim();
      if (name.isEmpty) return 'Internal name is required';

      // Duplicate check
      if (_isSubcategory) {
        if (_selectedParentId == null) return 'Parent category not selected';
        final parent = widget.vm.categories.firstWhere((c) => c.id == _selectedParentId);
        if (parent.subcategories.any((s) => s.name.toLowerCase() == name.toLowerCase() && s.id != widget.initialSubcategory?.id)) {
          return context.read<LanguageProvider>().trParams('duplicate_name_error', category: 'admin', params: {'type': 'Subcategory'});
        }
      } else {
        if (widget.vm.categories.any((c) => c.name.toLowerCase() == name.toLowerCase() && c.id != widget.initialCategory?.id)) {
          return context.read<LanguageProvider>().trParams('duplicate_name_error', category: 'admin', params: {'type': 'Category'});
        }
      }
    }
    return null;
  }

  bool _canGoNext() {
    return _getValidationError() == null;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildWizardHeader(lang, isDark),

            // Progress Indicator
            _buildProgressIndicator(isDark),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: _buildCurrentStep(lang, isDark),
              ),
            ),

            // Footer Actions
            _buildWizardFooter(lang, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardHeader(LanguageProvider lang, bool isDark) {
    String title = lang.tr('generate_new', category: 'admin');
    if (widget.initialCategory != null) title = lang.tr('edit_category', category: 'admin');
    if (widget.initialSubcategory != null) title = lang.tr('edit_subcategory', category: 'admin');

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 24, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      height: 4,
      width: double.infinity,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (_currentStep + 1) / _totalSteps,
        child: Container(color: AdminColors.primary),
      ),
    );
  }

  Widget _buildWizardFooter(LanguageProvider lang, bool isDark) {
    final error = _getValidationError();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AdminColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error, style: const TextStyle(color: AdminColors.danger, fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_currentStep > 0 && widget.initialCategory == null && widget.initialSubcategory == null && widget.initialParentId == null)
                TextButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: Text(lang.tr('back', category: 'admin')),
                ),
              const SizedBox(width: 12),
              if (_currentStep < _totalSteps - 1)
                AdminButton(
                  label: lang.tr('next', category: 'admin'),
                  onPressed: _canGoNext() ? () => setState(() => _currentStep++) : null,
                )
              else
                AdminButton(
                  label: lang.tr('finish', category: 'admin'),
                  onPressed: _finish,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _finish() {
    if (_isSubcategory) {
      final sub = SubcategoryModel(
        id: widget.initialSubcategory?.id ?? '',
        categoryId: _selectedParentId!,
        name: _internalNameCtrl.text.trim(),
        nameTranslations: {
          'en': _nameEnCtrl.text.trim(),
          'ar': _nameArCtrl.text.trim(),
          'fr': _nameFrCtrl.text.trim(),
        },
        description: _internalDescCtrl.text.trim(),
        descriptionTranslations: {
          'en': _descEnCtrl.text.trim(),
          'ar': _descArCtrl.text.trim(),
          'fr': _descFrCtrl.text.trim(),
        },
        icon: widget.initialSubcategory?.icon ?? Icons.subdirectory_arrow_right,
        iconCode: widget.initialSubcategory?.iconCode ?? 'circle_fill',
        imageUrl: _remoteImageUrl,
      );
      if (widget.initialSubcategory == null) {
        widget.vm.addSubcategory(_selectedParentId!, sub, localImagePath: _localImagePath);
      } else {
        widget.vm.updateSubcategory(_selectedParentId!, sub, localImagePath: _localImagePath);
      }
    } else {
      final cat = CategoryModel(
        id: widget.initialCategory?.id ?? '',
        name: _internalNameCtrl.text.trim(),
        nameTranslations: {
          'en': _nameEnCtrl.text.trim(),
          'ar': _nameArCtrl.text.trim(),
          'fr': _nameFrCtrl.text.trim(),
        },
        description: _internalDescCtrl.text.trim(),
        descriptionTranslations: {
          'en': _descEnCtrl.text.trim(),
          'ar': _descArCtrl.text.trim(),
          'fr': _descFrCtrl.text.trim(),
        },
        icon: widget.initialCategory?.icon ?? Icons.category,
        iconCode: widget.initialCategory?.iconCode ?? 'circle_fill',
        iconUrl: _remoteImageUrl,
        isActive: _isActive,
        subcategories: widget.initialCategory?.subcategories ?? [],
      );
      if (widget.initialCategory == null) {
        widget.vm.addCategory(cat, localImagePath: _localImagePath);
      } else {
        widget.vm.updateCategory(cat, localImagePath: _localImagePath);
      }
    }
    Navigator.pop(context);
    AppSnackBar.showSuccess(context, context.read<LanguageProvider>().trParams('creation_success', category: 'admin', params: {'type': _isSubcategory ? 'Subcategory' : 'Category'}));
  }

  Widget _buildCurrentStep(LanguageProvider lang, bool isDark) {
    if (_currentStep == 0) return _buildStep0Selection(lang, isDark);

    int adjustedStep = _currentStep;
    if (!_isSubcategory && adjustedStep >= 1) adjustedStep++;

    switch (adjustedStep) {
      case 1: return _buildStep1ParentSelection(lang, isDark);
      case 2: return _buildStep2BasicDetails(lang, isDark);
      case 3: return _buildStep3Translations(lang, isDark);
      case 4: return _buildStep4Review(lang, isDark);
      default: return const SizedBox();
    }
  }

  Widget _buildStep0Selection(LanguageProvider lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.tr('what_to_create', category: 'admin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildSelectionCard(
          title: lang.tr('categories', category: 'admin'),
          desc: lang.tr('create_category_desc', category: 'admin'),
          icon: Icons.category_rounded,
          isSelected: !_isSubcategory,
          onTap: () => setState(() => _isSubcategory = false),
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: lang.tr('subcategories', category: 'admin'),
          desc: lang.tr('create_subcategory_desc', category: 'admin'),
          icon: Icons.subdirectory_arrow_right_rounded,
          isSelected: _isSubcategory,
          onTap: () => setState(() => _isSubcategory = true),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSelectionCard({required String title, required String desc, required IconData icon, required bool isSelected, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.primary.withOpacity(0.05) : (isDark ? Colors.white.withOpacity(0.02) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AdminColors.primary : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isSelected ? AdminColors.primary : (isDark ? Colors.white10 : AdminColors.background), shape: BoxShape.circle),
              child: Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white60 : AdminColors.textSecondary)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : AdminColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AdminColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1ParentSelection(LanguageProvider lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.tr('select_parent_category', category: 'admin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(lang.tr('parent_category_desc', category: 'admin'), style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : AdminColors.textSecondary)),
        const SizedBox(height: 24),
        ...widget.vm.categories.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSelectionCard(
            title: cat.getTranslatedName(lang),
            desc: cat.getTranslatedDescription(lang),
            icon: cat.icon,
            isSelected: _selectedParentId == cat.id,
            onTap: () => setState(() => _selectedParentId = cat.id),
            isDark: isDark,
          ),
        )),
      ],
    );
  }

  Widget _buildStep2BasicDetails(LanguageProvider lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.tr('basic_details', category: 'admin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildWizardImagePicker(lang, isDark),
        const SizedBox(height: 24),
        _buildSectionTitle(lang.tr('general_info', category: 'admin')),
        const SizedBox(height: 12),
        AdminTextField(
          controller: _internalNameCtrl,
          hintText: lang.tr('internal_name', category: 'admin'),
          prefixIcon: Icons.label_important_outline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        AdminTextField(
          controller: _internalDescCtrl,
          hintText: lang.tr('internal_desc', category: 'admin'),
          prefixIcon: Icons.description_outlined,
        ),
        if (!_isSubcategory) ...[
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(lang.tr('visible_to_users', category: 'admin'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            value: _isActive,
            activeColor: AdminColors.primary,
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ],
      ],
    );
  }

  Widget _buildWizardImagePicker(LanguageProvider lang, bool isDark) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AdminColors.background,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: _localImagePath != null
                  ? Image.memory(ImageUtils.decodeBase64Image(_localImagePath!)!, fit: BoxFit.cover)
                  : (_remoteImageUrl != null && _remoteImageUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: _remoteImageUrl!, fit: BoxFit.cover)
                      : Icon(Icons.add_a_photo_outlined, size: 40, color: isDark ? Colors.white24 : Colors.black26)),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: FloatingActionButton.small(
              onPressed: () async {
                final path = await widget.vm.pickImage();
                if (path != null) setState(() => _localImagePath = path);
              },
              backgroundColor: AdminColors.primary,
              child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Translations(LanguageProvider lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.tr('translations', category: 'admin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildTranslationSection(lang.tr('name_translations', category: 'admin'), _nameEnCtrl, _nameArCtrl, _nameFrCtrl, isDark, lang),
        const SizedBox(height: 32),
        _buildTranslationSection(lang.tr('desc_translations', category: 'admin'), _descEnCtrl, _descArCtrl, _descFrCtrl, isDark, lang, isMultiLine: true),
      ],
    );
  }

  Widget _buildTranslationSection(String title, TextEditingController en, TextEditingController ar, TextEditingController fr, bool isDark, LanguageProvider lang, {bool isMultiLine = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 16),
        _buildTranslationField(lang.tr('english', category: 'common'), en, isMultiLine, isDark),
        const SizedBox(height: 12),
        _buildTranslationField(lang.tr('arabic', category: 'common'), ar, isMultiLine, isDark),
        const SizedBox(height: 12),
        _buildTranslationField(lang.tr('french', category: 'common'), fr, isMultiLine, isDark),
      ],
    );
  }

  Widget _buildTranslationField(String label, TextEditingController ctrl, bool multi, bool isDark) {
    return AdminTextField(
      controller: ctrl,
      hintText: label,
      maxLines: multi ? 3 : 1,
    );
  }

  Widget _buildStep4Review(LanguageProvider lang, bool isDark) {
    final parentName = _isSubcategory && _selectedParentId != null ? widget.vm.categories.firstWhere((c) => c.id == _selectedParentId).getTranslatedName(lang) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.tr('review_create', category: 'admin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildReviewItem(lang.tr('type', category: 'admin'), _isSubcategory ? 'Subcategory' : 'Category', isDark),
        if (_isSubcategory) _buildReviewItem(lang.tr('select_parent_category', category: 'admin'), parentName, isDark),
        _buildReviewItem(lang.tr('internal_name', category: 'admin'), _internalNameCtrl.text, isDark),
        _buildReviewItem(lang.tr('name_en', category: 'admin'), _nameEnCtrl.text, isDark),
        _buildReviewItem(lang.tr('status', category: 'admin'), _isActive ? 'Active' : 'Disabled', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AdminColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AdminColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(lang.tr('save_category', category: 'admin'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: isDark ? Colors.white54 : AdminColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AdminColors.primary));
  }
}
