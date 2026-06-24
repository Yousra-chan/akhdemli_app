import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../ViewModel/admin_view_model.dart';
import '../../models/ServicesModel.dart';
import '../../models/UserModel.dart';
import '../../providers/language_provider.dart';
import '../../utils/image_utils.dart';
import '../service/edit_service.dart';
import 'admin_components.dart';

class AdminServiceDetailsScreen extends StatefulWidget {
  final Service service;

  const AdminServiceDetailsScreen({super.key, required this.service});

  @override
  State<AdminServiceDetailsScreen> createState() => _AdminServiceDetailsScreenState();
}

class _AdminServiceDetailsScreenState extends State<AdminServiceDetailsScreen> {
  UserModel? _provider;
  bool _isLoadingProvider = true;
  late Service _currentService;

  @override
  void initState() {
    super.initState();
    _currentService = widget.service;
    _fetchProviderInfo();
  }

  Future<void> _fetchProviderInfo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentService.providerId).get();
      if (doc.exists && mounted) {
        setState(() {
          _provider = UserModel.fromMap(doc.data()!, doc.id);
          _isLoadingProvider = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching provider info: $e');
      if (mounted) setState(() => _isLoadingProvider = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.tr('service_details', category: 'admin')),
        backgroundColor: theme.cardColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            _buildHeader(theme, lang, isMobile),
            const SizedBox(height: 24),

            // --- Images Section ---
            if (_currentService.images.isNotEmpty) ...[
              _buildSectionTitle(lang.tr('service_images', category: 'admin')),
              const SizedBox(height: 12),
              _buildImageGallery(),
              const SizedBox(height: 24),
            ],

            // --- Details Grid ---
            if (isMobile)
              Column(
                children: [
                  _buildDescriptionCard(theme, lang),
                  const SizedBox(height: 20),
                  _buildInfoCard(theme, lang),
                  const SizedBox(height: 20),
                  _buildProviderCard(theme, lang),
                  const SizedBox(height: 20),
                  _buildActionsCard(context, theme, lang),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildDescriptionCard(theme, lang),
                        const SizedBox(height: 20),
                        _buildProviderCard(theme, lang),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _buildInfoCard(theme, lang),
                        const SizedBox(height: 20),
                        _buildActionsCard(context, theme, lang),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, LanguageProvider lang, bool isMobile) {
    return AdminCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.miscellaneous_services_rounded, color: theme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _currentService.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AdminStatusBadge(
                        label: _currentService.isActive 
                            ? lang.tr('status_active', category: 'admin') 
                            : lang.tr('status_inactive', category: 'admin'),
                        color: _currentService.isActive ? AdminColors.success : AdminColors.danger,
                      ),
                      if (_currentService.isFeatured) ...[
                        const SizedBox(width: 8),
                        AdminStatusBadge(label: lang.tr('featured', category: 'admin').toUpperCase(), color: AdminColors.warning),
                      ],
                    ],
                  ),
                  Text(
                    _currentService.displayPrice,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.miscellaneous_services_rounded, color: theme.primaryColor, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentService.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AdminStatusBadge(
                          label: _currentService.isActive 
                              ? lang.tr('status_active', category: 'admin') 
                              : lang.tr('status_inactive', category: 'admin'),
                          color: _currentService.isActive ? AdminColors.success : AdminColors.danger,
                        ),
                        if (_currentService.isFeatured) ...[
                          const SizedBox(width: 8),
                          const AdminStatusBadge(label: 'FEATURED', color: AdminColors.warning),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _currentService.displayPrice,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildImageGallery() {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _currentService.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final imageUrl = _currentService.images[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ImageUtils.isBase64Image(imageUrl)
                ? Image.memory(
                    ImageUtils.decodeBase64Image(imageUrl)!,
                    width: 300,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    imageUrl,
                    width: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 300,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptionCard(ThemeData theme, LanguageProvider lang) {
    return AdminCard(
      title: lang.tr('description', category: 'admin'),
      child: Text(
        _currentService.description,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, LanguageProvider lang) {
    return AdminCard(
      title: lang.tr('service_info', category: 'admin'),
      child: Column(
        children: [
          _buildInfoRow(Icons.category_rounded, lang.tr('category', category: 'admin'), _currentService.category),
          _buildInfoRow(Icons.account_tree_rounded, lang.tr('subcategory', category: 'admin'), _currentService.subcategory),
          _buildInfoRow(Icons.location_on_rounded, lang.tr('location', category: 'admin'), _currentService.location),
          _buildInfoRow(Icons.calendar_today_rounded, lang.tr('created_at', category: 'admin'), DateFormat.yMMMd().add_jm().format(_currentService.createdAt)),
          _buildInfoRow(Icons.update_rounded, lang.tr('updated_at', category: 'admin'), DateFormat.yMMMd().add_jm().format(_currentService.updatedAt)),
          _buildInfoRow(Icons.star_rounded, lang.tr('rating', category: 'admin'), '${_currentService.rating} (${_currentService.totalReviews} reviews)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdminColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(ThemeData theme, LanguageProvider lang) {
    if (_isLoadingProvider) {
      return const AdminCard(child: Center(child: CircularProgressIndicator()));
    }

    if (_provider == null) {
      return AdminCard(child: Text(lang.tr('provider_not_found', category: 'admin')));
    }

    return AdminCard(
      title: lang.tr('provider_info', category: 'admin'),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: _provider!.photoUrl.isNotEmpty 
                    ? ImageUtils.getImageProvider(_provider!.photoUrl)
                    : null,
                child: _provider!.photoUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_provider!.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(_provider!.email, style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.phone_rounded, lang.tr('phone', category: 'admin'), _provider!.phone),
          _buildInfoRow(Icons.badge_rounded, lang.tr('profession', category: 'admin'), _provider!.profession ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, ThemeData theme, LanguageProvider lang) {
    final vm = context.read<AdminViewModel>();
    
    return AdminCard(
      title: lang.tr('admin_actions', category: 'admin'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminButton(
            label: lang.tr('edit_service', category: 'admin'),
            icon: Icons.edit_rounded,
            onPressed: () => _handleEdit(context),
            backgroundColor: AdminColors.primary,
          ),
          const SizedBox(height: 12),
          AdminButton(
            label: _currentService.isActive 
                ? lang.tr('deactivate', category: 'admin') 
                : lang.tr('activate_service', category: 'admin'),
            icon: _currentService.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            onPressed: () => _handleToggleActive(vm),
            backgroundColor: _currentService.isActive ? AdminColors.warning : AdminColors.success,
          ),
          const SizedBox(height: 12),
          AdminButton(
            label: _currentService.isFeatured 
                ? lang.tr('unfeature', category: 'admin') 
                : lang.tr('feature', category: 'admin'),
            icon: Icons.star_rounded,
            onPressed: () => _handleToggleFeatured(vm),
            backgroundColor: Colors.amber[700],
          ),
          const SizedBox(height: 12),
          AdminButton(
            label: lang.tr('delete', category: 'common'),
            icon: Icons.delete_forever_rounded,
            onPressed: () => _handleDelete(context, vm, lang),
            backgroundColor: AdminColors.danger,
          ),
        ],
      ),
    );
  }

  void _handleEdit(BuildContext context) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditServiceScreen(serviceData: _currentService.toMap()),
      ),
    );
    
    if (updated == true) {
      // Refresh current service from DB
      final doc = await FirebaseFirestore.instance.collection('services').doc(_currentService.id).get();
      if (doc.exists && mounted) {
        setState(() => _currentService = Service.fromFirestore(doc));
      }
    }
  }

  void _handleToggleActive(AdminViewModel vm) async {
    final newStatus = !_currentService.isActive;
    await vm.updateServiceStatus(_currentService.id, isActive: newStatus);
    setState(() => _currentService = _currentService.copyWith(isActive: newStatus));
  }

  void _handleToggleFeatured(AdminViewModel vm) async {
    final newFeatured = !_currentService.isFeatured;
    await vm.toggleFeaturedService(_currentService.id, newFeatured);
    setState(() => _currentService = _currentService.copyWith(isFeatured: newFeatured));
  }

  void _handleDelete(BuildContext context, AdminViewModel vm, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('delete_service_confirm', category: 'admin')),
        content: Text(lang.tr('delete_service_warning', category: 'admin')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.tr('cancel', category: 'common')),
          ),
          ElevatedButton(
            onPressed: () async {
              await vm.deleteService(_currentService.id);
              if (mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close details screen
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            child: Text(lang.tr('delete', category: 'common'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final String serviceName;
  final VoidCallback onConfirm, onCancel;
  const _DeleteDialog({required this.serviceName,
    required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<LanguageProvider>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Theme.of(context).cardColor,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AdminColors.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 22),
              ),
              const SizedBox(height: 20),
              Text(lang.tr('delete_service_confirm', category: 'admin'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(
                "${lang.tr('delete_service_warning', category: 'admin')} \"$serviceName\". ${lang.tr('delete_service_undone', category: 'admin')}",
                style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary, height: 1.6),
              ),
              const SizedBox(height: 24),
              Divider(height: 1),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(lang.tr('cancel', category: 'common')),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: Text(lang.tr('delete', category: 'common')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.danger,
                    foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ]),
      ),
    );
  }
}
