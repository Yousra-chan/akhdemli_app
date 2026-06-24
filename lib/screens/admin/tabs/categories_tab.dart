import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../models/CategoryModel.dart';
import '../../../providers/language_provider.dart';
import '../../../utils/image_utils.dart';
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
                  AdminButton(
                    onPressed: () => _showCategoryDialog(context, vm),
                    icon: Icons.add_rounded,
                    label: lang.tr('add_category', category: 'admin'),
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
                                  ? Image.memory(ImageUtils.decodeBase64Image(cat.iconUrl)!, fit: BoxFit.cover, width: 46, height: 46)
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
                  AdminStatusBadge(
                    label: cat.isActive ? 'ACTIVE' : 'DISABLED',
                    color: cat.isActive ? AdminColors.success : AdminColors.textSecondary,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white54 : AdminColors.textSecondary, size: 20),
                        onPressed: () => _showCategoryDialog(context, vm, category: cat),
                        splashRadius: 18,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 20),
                        onPressed: () => _confirmDelete(context, () => vm.deleteCategory(cat.id), 'Category'),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.tr('subcategories', category: 'admin').toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white60 : AdminColors.textSecondary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showSubcategoryDialog(context, vm, cat.id),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(lang.tr('add_sub', category: 'admin')),
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
                        onTap: () => _showSubcategoryDialog(context, vm, cat.id, subcategory: sub),
                        child: Chip(
                          label: Text(sub.getTranslatedName(lang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: isDark ? const Color(0xFF1C1F26) : Colors.white,
                          labelStyle: TextStyle(color: isDark ? Colors.white : AdminColors.textMain),
                          avatar: sub.imageUrl != null 
                              ? CircleAvatar(
                                  backgroundImage: ImageUtils.isBase64Image(sub.imageUrl)
                                      ? MemoryImage(ImageUtils.decodeBase64Image(sub.imageUrl)!)
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

  Widget _buildImagePicker({
    required BuildContext context,
    required String? imageUrl,
    required String? localPath,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Center(
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : AdminColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: localPath != null
                      ? (ImageUtils.isBase64Image(localPath)
                          ? Image.memory(ImageUtils.decodeBase64Image(localPath)!, fit: BoxFit.cover)
                          : Image.file(File(localPath), fit: BoxFit.cover))
                      : (imageUrl != null && imageUrl.isNotEmpty
                          ? (ImageUtils.isBase64Image(imageUrl)
                              ? Image.memory(ImageUtils.decodeBase64Image(imageUrl)!, fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Icons.image_not_supported_outlined),
                                ))
                          : Icon(Icons.image_outlined, size: 40, color: isDark ? Colors.white24 : Colors.black26)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  children: [
                    if (localPath != null || (imageUrl != null && imageUrl.isNotEmpty))
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AdminColors.danger, shape: BoxShape.circle),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onPick,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AdminColors.primary, shape: BoxShape.circle),
                        child: Icon(
                          (localPath != null || (imageUrl != null && imageUrl.isNotEmpty)) ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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

  void _showCategoryDialog(BuildContext context, AdminViewModel vm, {CategoryModel? category}) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final nameCtrl = TextEditingController(text: category?.name);
    final descCtrl = TextEditingController(text: category?.description);
    
    // Translation Controllers
    final nameEnCtrl = TextEditingController(text: category?.nameTranslations['en']);
    final nameArCtrl = TextEditingController(text: category?.nameTranslations['ar']);
    final nameFrCtrl = TextEditingController(text: category?.nameTranslations['fr']);
    
    final descEnCtrl = TextEditingController(text: category?.descriptionTranslations['en']);
    final descArCtrl = TextEditingController(text: category?.descriptionTranslations['ar']);
    final descFrCtrl = TextEditingController(text: category?.descriptionTranslations['fr']);

    final subNameEnCtrl = TextEditingController();
    final subNameArCtrl = TextEditingController();
    final subNameFrCtrl = TextEditingController();
    final subDescEnCtrl = TextEditingController();
    final subDescArCtrl = TextEditingController();
    final subDescFrCtrl = TextEditingController();
    
    bool isActive = category?.isActive ?? true;
    String? categoryLocalPath;
    String? categoryImageUrl = category?.iconUrl;

    final List<SubcategoryModel> localSubs = List<SubcategoryModel>.from(category?.subcategories ?? []);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            category == null ? lang.tr('new_category', category: 'admin') : lang.tr('edit_category', category: 'admin'),
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AdminColors.textMain),
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePicker(
                    context: context,
                    imageUrl: categoryImageUrl,
                    localPath: categoryLocalPath,
                    label: lang.tr('category_image', category: 'admin'),
                    onPick: () async {
                      final path = await vm.pickImage();
                      if (path != null) {
                        setDialogState(() => categoryLocalPath = path);
                      }
                    },
                    onRemove: () {
                      setDialogState(() {
                        categoryLocalPath = null;
                        categoryImageUrl = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(lang.tr('general_info', category: 'admin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  AdminTextField(hintText: lang.tr('internal_name', category: 'admin'), controller: nameCtrl, prefixIcon: Icons.label_important_outline),
                  const SizedBox(height: 12),
                  AdminTextField(hintText: lang.tr('internal_desc', category: 'admin'), controller: descCtrl, prefixIcon: Icons.description_outlined),
                  
                  const SizedBox(height: 24),
                  Text(lang.tr('name_translations', category: 'admin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: AdminTextField(hintText: lang.tr('english', category: 'common'), controller: nameEnCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: lang.tr('arabic', category: 'common'), controller: nameArCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: lang.tr('french', category: 'common'), controller: nameFrCtrl)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Text(lang.tr('desc_translations', category: 'admin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: AdminTextField(hintText: lang.tr('english', category: 'common'), controller: descEnCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: lang.tr('arabic', category: 'common'), controller: descArCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: lang.tr('french', category: 'common'), controller: descFrCtrl)),
                    ],
                  ),

                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      lang.tr('visible_to_users', category: 'admin'),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : AdminColors.textMain),
                    ),
                    value: isActive,
                    activeThumbColor: AdminColors.primary,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  Text(
                    lang.tr('subcategories', category: 'admin').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white60 : AdminColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (localSubs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                      children: localSubs.map((sub) => Chip(
                        label: Text(sub.getTranslatedName(Provider.of<LanguageProvider>(context, listen: false)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        backgroundColor: isDark ? Colors.white.withOpacity(0.05) : AdminColors.background,
                        labelStyle: TextStyle(color: isDark ? Colors.white : AdminColors.textMain),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        deleteIcon: Icon(Icons.close_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                        onDeleted: () => setDialogState(() => localSubs.remove(sub)),
                      )).toList(),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : AdminColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.tr('quick_add_subcategory', category: 'admin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: AdminTextField(hintText: 'EN ${lang.tr('status_active', category: 'admin')}', controller: subNameEnCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: AdminTextField(hintText: 'AR ${lang.tr('status_active', category: 'admin')}', controller: subNameArCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: AdminTextField(hintText: 'FR ${lang.tr('status_active', category: 'admin')}', controller: subNameFrCtrl)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: AdminTextField(hintText: 'EN ${lang.tr('internal_desc', category: 'admin')}', controller: subDescEnCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: AdminTextField(hintText: 'AR ${lang.tr('internal_desc', category: 'admin')}', controller: subDescArCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: AdminTextField(hintText: 'FR ${lang.tr('internal_desc', category: 'admin')}', controller: subDescFrCtrl)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: AdminButton(
                            label: lang.tr('add_to_list', category: 'admin'),
                            icon: Icons.add_rounded,
                            isSecondary: true,
                            onPressed: () {
                              final subNameEn = subNameEnCtrl.text.trim();
                              if (subNameEn.isEmpty) return;
                              setDialogState(() {
                                localSubs.add(SubcategoryModel(
                                  id: '',
                                  categoryId: category?.id ?? '',
                                  name: subNameEn,
                                  nameTranslations: {
                                    'en': subNameEn,
                                    'ar': subNameArCtrl.text.trim(),
                                    'fr': subNameFrCtrl.text.trim(),
                                  },
                                  description: subDescEnCtrl.text.trim(),
                                  descriptionTranslations: {
                                    'en': subDescEnCtrl.text.trim(),
                                    'ar': subDescArCtrl.text.trim(),
                                    'fr': subDescFrCtrl.text.trim(),
                                  },
                                  icon: Icons.subdirectory_arrow_right,
                                  iconCode: 'circle_fill',
                                ));
                                subNameEnCtrl.clear();
                                subNameArCtrl.clear();
                                subNameFrCtrl.clear();
                                subDescEnCtrl.clear();
                                subDescArCtrl.clear();
                                subDescFrCtrl.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.tr('cancel', category: 'common'), style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            AdminButton(
              label: lang.tr('save_category', category: 'admin'),
              onPressed: () {
                final newCat = CategoryModel(
                  id: category?.id ?? '',
                  name: nameCtrl.text.trim(),
                  nameTranslations: {
                    'en': nameEnCtrl.text.trim(),
                    'ar': nameArCtrl.text.trim(),
                    'fr': nameFrCtrl.text.trim(),
                  },
                  description: descCtrl.text.trim(),
                  descriptionTranslations: {
                    'en': descEnCtrl.text.trim(),
                    'ar': descArCtrl.text.trim(),
                    'fr': descFrCtrl.text.trim(),
                  },
                  icon: category?.icon ?? Icons.category,
                  iconCode: category?.iconCode ?? 'circle_fill',
                  iconUrl: categoryImageUrl,
                  isActive: isActive,
                  subcategories: localSubs,
                );

                if (category == null) {
                  vm.addCategory(newCat, localImagePath: categoryLocalPath);
                } else {
                  vm.updateCategory(newCat, localImagePath: categoryLocalPath);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSubcategoryDialog(BuildContext context, AdminViewModel vm, String categoryId, {SubcategoryModel? subcategory}) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final nameEnCtrl = TextEditingController(text: subcategory?.nameTranslations['en']);
    final nameArCtrl = TextEditingController(text: subcategory?.nameTranslations['ar']);
    final nameFrCtrl = TextEditingController(text: subcategory?.nameTranslations['fr']);
    final descEnCtrl = TextEditingController(text: subcategory?.descriptionTranslations['en']);
    final descArCtrl = TextEditingController(text: subcategory?.descriptionTranslations['ar']);
    final descFrCtrl = TextEditingController(text: subcategory?.descriptionTranslations['fr']);
    
    String? localImagePath;
    String? currentImageUrl = subcategory?.imageUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            subcategory == null ? lang.tr('new_subcategory', category: 'admin') : lang.tr('edit_subcategory', category: 'admin'),
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AdminColors.textMain),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildImagePicker(
                    context: context,
                    imageUrl: currentImageUrl,
                    localPath: localImagePath,
                    label: lang.tr('subcategory_image', category: 'admin'),
                    onPick: () async {
                      final path = await vm.pickImage();
                      if (path != null) {
                        setDialogState(() => localImagePath = path);
                      }
                    },
                    onRemove: () {
                      setDialogState(() {
                        localImagePath = null;
                        currentImageUrl = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: AdminTextField(hintText: '${lang.tr('status_active', category: 'admin')} (EN)', controller: nameEnCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: '${lang.tr('status_active', category: 'admin')} (AR)', controller: nameArCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: '${lang.tr('status_active', category: 'admin')} (FR)', controller: nameFrCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: AdminTextField(hintText: '${lang.tr('internal_desc', category: 'admin')} (EN)', controller: descEnCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: '${lang.tr('internal_desc', category: 'admin')} (AR)', controller: descArCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: AdminTextField(hintText: '${lang.tr('internal_desc', category: 'admin')} (FR)', controller: descFrCtrl)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.tr('cancel', category: 'common'), style: TextStyle(color: isDark ? Colors.white60 : AdminColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            AdminButton(
              label: subcategory == null ? lang.tr('add_subcategory', category: 'admin') : lang.tr('save_category', category: 'admin'),
              onPressed: () {
                final sub = SubcategoryModel(
                  id: subcategory?.id ?? '',
                  categoryId: categoryId,
                  name: nameEnCtrl.text.trim(),
                  nameTranslations: {
                    'en': nameEnCtrl.text.trim(),
                    'ar': nameArCtrl.text.trim(),
                    'fr': nameFrCtrl.text.trim(),
                  },
                  description: descEnCtrl.text.trim(),
                  descriptionTranslations: {
                    'en': descEnCtrl.text.trim(),
                    'ar': descArCtrl.text.trim(),
                    'fr': descFrCtrl.text.trim(),
                  },
                  icon: subcategory?.icon ?? Icons.subdirectory_arrow_right,
                  iconCode: subcategory?.iconCode ?? 'circle_fill',
                  imageUrl: currentImageUrl,
                );
                
                if (subcategory == null) {
                  vm.addSubcategory(categoryId, sub, localImagePath: localImagePath);
                } else {
                  vm.updateSubcategory(categoryId, sub, localImagePath: localImagePath);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
