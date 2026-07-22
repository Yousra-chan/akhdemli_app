import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/ServicesModel.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../providers/language_provider.dart';
import '../../../utils/ui_widgets.dart';
import '../admin_service_details.dart';
import '../admin_components.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().fetchServices(isRefresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<AdminViewModel>().loadMoreServices();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, vm, lang, isDark),
          const SizedBox(height: 24),
          _buildFilters(vm, lang, isDark),
          const SizedBox(height: 20),
          if (vm.selectedServiceIds.isNotEmpty) ...[
            _buildBulkActions(vm, lang),
            const SizedBox(height: 20),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => vm.fetchServices(isRefresh: true),
              child: vm.paginatedServices.isEmpty && !vm.isLoading
                  ? _buildEmptyState(lang)
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: vm.paginatedServices.length + (vm.isLoadingMoreServices ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == vm.paginatedServices.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _ServiceListItem(
                          service: vm.paginatedServices[index],
                          isSelected: vm.selectedServiceIds.contains(vm.paginatedServices[index].id),
                          onToggle: () => vm.toggleServiceSelection(vm.paginatedServices[index].id),
                          onAction: (action) => _handleAction(action, vm.paginatedServices[index], vm, lang),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.miscellaneous_services_rounded, color: AdminColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr('services', category: 'admin'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : AdminColors.textMain,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                lang.tr('manage_services_desc', category: 'admin'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AdminColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(AdminViewModel vm, LanguageProvider lang, bool isDark) {
    return Column(
      children: [
        AdminTextField(
          controller: _searchCtrl,
          hintText: lang.tr('search_hint', category: 'admin'),
          prefixIcon: Icons.search_rounded,
          onSubmitted: (val) => vm.setServiceFilters(search: val),
          onChanged: (val) {
            if (val.isEmpty) vm.setServiceFilters(search: '');
          },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: lang.tr('status_filter', category: 'admin'),
                icon: Icons.filter_list_rounded,
                onTap: () => _showFilterMenu(context, vm, lang, isDark, 'status'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: lang.tr('categories', category: 'admin'),
                icon: Icons.category_outlined,
                onTap: () => _showFilterMenu(context, vm, lang, isDark, 'category'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: lang.tr('sort_by', category: 'admin'),
                icon: Icons.sort_rounded,
                onTap: () => _showFilterMenu(context, vm, lang, isDark, 'sort'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              if (_searchCtrl.text.isNotEmpty || vm.serviceFiltersAreActive)
                _buildFilterChip(
                  label: lang.tr('reset', category: 'admin'),
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    _searchCtrl.clear();
                    vm.clearAllServiceFilters();
                  },
                  isDark: isDark,
                  isReset: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon, required VoidCallback onTap, required bool isDark, bool isReset = false}) {
    final color = isReset ? AdminColors.danger : AdminColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white10 : color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white70 : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext context, AdminViewModel vm, LanguageProvider lang, bool isDark, String type) {
    List<String> items = [];
    Function(String?) onSelected;

    switch (type) {
      case 'status':
        items = ['all', 'active', 'inactive'];
        onSelected = (val) => vm.setServiceFilters(status: val);
        break;
      case 'category':
        items = ['all', ...vm.categories.map((c) => c.name)];
        onSelected = (val) => vm.setServiceFilters(category: val);
        break;
      case 'sort':
        items = ['createdAt', 'title', 'category', 'isActive'];
        onSelected = (val) => vm.setServiceFilters(sortField: val);
        break;
      default: return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1F26) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.tr('${type}_filter', category: 'admin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...items.map((item) => ListTile(
              title: Text(lang.tr(item, category: 'admin')),
              onTap: () {
                onSelected(item);
                Navigator.pop(context);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActions(AdminViewModel vm, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${vm.selectedServiceIds.length} ${lang.tr('selected_count', category: 'admin')}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.primary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () async {
              await vm.batchUpdateServicesStatus(true);
              if (mounted) AppSnackBar.showSuccess(context, lang.tr('save_success', category: 'admin'));
            },
            icon: const Icon(Icons.check_circle_outline_rounded, color: AdminColors.success, size: 20),
            tooltip: lang.tr('activate', category: 'admin'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () async {
              await vm.batchUpdateServicesStatus(false);
              if (mounted) AppSnackBar.showSuccess(context, lang.tr('save_success', category: 'admin'));
            },
            icon: const Icon(Icons.block_rounded, color: AdminColors.warning, size: 20),
            tooltip: lang.tr('deactivate', category: 'admin'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _confirmBulkDelete(context, vm, lang),
            icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 20),
            tooltip: lang.tr('delete', category: 'admin'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: vm.clearServiceSelection, 
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            child: Text(lang.tr('clear', category: 'common'), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return AdminEmptyState(
      title: lang.tr('no_matching_services', category: 'admin'),
      subtitle: lang.tr('adjust_filters', category: 'admin'),
      icon: Icons.miscellaneous_services_rounded,
    );
  }

  Future<void> _handleAction(String action, Service service, AdminViewModel vm, LanguageProvider lang) async {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: vm,
              child: AdminServiceDetailsScreen(service: service),
            ),
          ),
        );
        break;
      case 'toggle':
        await vm.updateServiceStatus(service.id, isActive: !service.isActive);
        break;
      case 'duplicate':
        await vm.duplicateService(service);
        if (mounted) AppSnackBar.showSuccess(context, lang.tr('save_success', category: 'admin'));
        break;
      case 'feature':
        await vm.toggleFeaturedService(service.id, !service.isFeatured);
        break;
      case 'delete':
        _confirmDelete(context, vm, service, lang);
        break;
    }
  }

  void _confirmDelete(BuildContext context, AdminViewModel vm, Service s, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(lang.tr('delete_service_confirm', category: 'admin')),
        content: Text('${lang.tr('delete_service_warning', category: 'admin')} "${s.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.tr('cancel', category: 'common'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              vm.deleteService(s.id);
              Navigator.pop(ctx);
            },
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context, AdminViewModel vm, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(lang.tr('confirm_bulk_delete', category: 'admin')),
        content: Text(lang.trParams('confirm_bulk_delete_msg', category: 'admin', params: {'count': vm.selectedServiceIds.length.toString()})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.tr('cancel', category: 'common'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              vm.batchDeleteServices();
              Navigator.pop(ctx);
            },
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ServiceListItem extends StatelessWidget {
  final Service service;
  final bool isSelected;
  final VoidCallback onToggle;
  final Function(String) onAction;

  const _ServiceListItem({
    required this.service,
    required this.isSelected,
    required this.onToggle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.read<LanguageProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => onAction('view'),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Image
                    Hero(
                      tag: 'service_img_${service.id}',
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.white.withOpacity(0.05) : AdminColors.background,
                          image: service.images.isNotEmpty
                              ? DecorationImage(image: NetworkImage(service.images[0]), fit: BoxFit.cover)
                              : null,
                        ),
                        child: service.images.isEmpty 
                            ? Icon(Icons.image_outlined, color: AdminColors.primary.withOpacity(0.2), size: 24) 
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title & Categories
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  service.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: isDark ? Colors.white : AdminColors.textMain,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (service.isFeatured)
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _buildMiniBadge(service.category, isDark),
                              if (service.subcategory.isNotEmpty)
                                _buildMiniBadge(service.subcategory, isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bulk Selection Checkbox
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected, 
                        onChanged: (_) => onToggle(), 
                        activeColor: AdminColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.01) : AdminColors.background.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    // Price
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr('price', category: 'admin').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white38 : AdminColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${service.price} ${service.priceUnit}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Flexible(
                      flex: 2,
                      child: AdminStatusBadge(
                        label: service.isActive 
                          ? lang.tr('status_active', category: 'admin').toUpperCase() 
                          : lang.tr('inactive', category: 'admin').toUpperCase(),
                        color: service.isActive ? AdminColors.success : AdminColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCompactAction(
                          icon: service.isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: service.isFeatured ? Colors.amber : (isDark ? Colors.white24 : Colors.grey),
                          onTap: () => onAction('feature'),
                        ),
                        const SizedBox(width: 4),
                        _buildCompactAction(
                          icon: Icons.copy_rounded,
                          color: AdminColors.primary,
                          onTap: () => onAction('duplicate'),
                        ),
                        const SizedBox(width: 4),
                        _buildCompactAction(
                          icon: service.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                          color: service.isActive ? AdminColors.warning : AdminColors.success,
                          onTap: () => onAction('toggle'),
                        ),
                        const SizedBox(width: 4),
                        _buildCompactAction(
                          icon: Icons.delete_outline_rounded,
                          color: AdminColors.danger,
                          onTap: () => onAction('delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.white70 : AdminColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCompactAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
