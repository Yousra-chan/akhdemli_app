import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:service_app/screens/service/create_service.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/models/ServicesModel.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/service/edit_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/providers/theme_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:shimmer/shimmer.dart';

class MyServicesPage extends StatefulWidget {
  const MyServicesPage({super.key});

  @override
  State<MyServicesPage> createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage> {
  late FirestoreService _firestoreService;
  List<Service> _services = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      if (mounted) setState(() { _isLoading = true; _error = null; });

      final authVM = context.read<AuthViewModel>();
      final user = authVM.currentUser;

      if (user != null) {
        final maps = await _firestoreService.getProviderServices(user.uid);
        if (mounted) {
          setState(() {
            _services = maps.map((m) => Service.fromMap(m)).toList();
          });
        }
      } else {
        if (mounted) setState(() { _error = 'please_sign_in'; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'unable_to_load'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _refreshServices() async {
    await _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(lang, theme, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: _buildStatsOverview(context, lang, theme, isDark),
            ),
          ),
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _ServiceSkeleton(),
                  ),
                  childCount: 3,
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: ErrorStateWidget(
                message: lang.tr(_error!, category: 'my_services'),
                onRetry: _refreshServices,
              ),
            )
          else if (_services.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(lang, theme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _ServiceCard(
                      service: _services[index],
                      onTap: () => _showServiceDetails(_services[index]),
                      onEdit: () => _editService(_services[index]),
                      onDelete: () => _confirmDelete(_services[index]),
                      onToggle: () => _toggleServiceStatus(_services[index]),
                    ),
                  ),
                  childCount: _services.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: theme.primaryColor,
        elevation: 4,
        highlightElevation: 8,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          lang.tr('add_new', category: 'my_services'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Exo2',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(LanguageProvider lang, ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerColor),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: theme.primaryColor),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 60, bottom: 16),
        centerTitle: false,
        title: Text(
          lang.tr('my_services', category: 'my_services'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            fontFamily: 'Exo2',
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor),
              ),
              child: Icon(Icons.refresh_rounded, size: 20, color: theme.primaryColor),
            ),
            onPressed: _refreshServices,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview(BuildContext context, LanguageProvider lang, ThemeData theme, bool isDark) {
    int totalServices = _services.length;
    double avgRating = _calculateAverageRating();
    int activeCount = _services.where((s) => s.isActive).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: Icons.auto_graph_rounded,
            value: '$totalServices',
            label: lang.tr('total', category: 'common'),
            color: theme.primaryColor,
          ),
          _buildStatItem(
            context,
            icon: Icons.star_rounded,
            value: avgRating.toStringAsFixed(1),
            label: lang.tr('rating', category: 'common'),
            color: const Color(0xFFF59E0B),
          ),
          _buildStatItem(
            context,
            icon: Icons.check_circle_rounded,
            value: '$activeCount',
            label: lang.tr('active', category: 'admin'),
            color: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {required IconData icon, required String value, required String label, required Color color}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Exo2',
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(LanguageProvider lang, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.miscellaneous_services_rounded, size: 64, color: theme.primaryColor.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            lang.tr('no_services_yet', category: 'my_services'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Exo2'),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              lang.tr('create_first_service_hint', category: 'my_services'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _navigateToCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(lang.tr('create_first_service', category: 'my_services'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToCreate() {
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
    ).then((value) {
      if (value == true) _refreshServices();
    });
  }

  void _editService(Service service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditServiceScreen(
          serviceData: service.toMap(),
        ),
      ),
    ).then((value) {
      if (value == true) _refreshServices();
    });
  }

  Future<void> _toggleServiceStatus(Service service) async {
    try {
      final newStatus = !service.isActive;
      await _firestoreService.updateService(service.id, {'isActive': newStatus});
      if (mounted) AppSnackBar.showSuccess(context, context.read<LanguageProvider>().tr('save_success', category: 'admin'));
      _loadServices();
    } catch (e) {
      AppSnackBar.showError(context, 'Error updating status');
    }
  }

  void _confirmDelete(Service service) {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.tr('delete_service_confirm', category: 'admin')),
        content: Text('${lang.tr('delete_service_warning', category: 'admin')} "${service.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.tr('cancel', category: 'common'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await _firestoreService.deleteService(service.id);
              Navigator.pop(ctx);
              _loadServices();
            },
            child: Text(lang.tr('delete', category: 'common')),
          ),
        ],
      ),
    );
  }

  void _showServiceDetails(Service service) {
    final theme = Theme.of(context);
    final lang = context.read<LanguageProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'Exo2')),
                    const SizedBox(height: 16),
                    if (service.images.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(imageUrl: service.images[0], height: 200, width: double.infinity, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 24),
                    _buildDetailItem(Icons.description_outlined, lang.tr('description', category: 'admin'), service.description, theme),
                    _buildDetailItem(Icons.category_outlined, lang.tr('category', category: 'admin'), service.category, theme),
                    _buildDetailItem(Icons.account_tree_outlined, lang.tr('subcategory', category: 'admin'), service.subcategory, theme),
                    _buildDetailItem(Icons.attach_money_rounded, lang.tr('price', category: 'admin'), '${service.price} ${service.priceUnit}', theme),
                    _buildDetailItem(Icons.location_on_outlined, lang.tr('location', category: 'admin'), service.location, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: theme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withOpacity(0.5), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAverageRating() {
    if (_services.isEmpty) return 0.0;
    double total = 0;
    for (var s in _services) total += s.rating;
    return total / _services.length;
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ServiceCard({
    required this.service,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = context.watch<LanguageProvider>();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Image or placeholder
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  ),
                  child: service.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: service.images[0],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined, size: 40),
                        )
                      : const Icon(Icons.image_outlined, size: 40),
                ),
                // Status Badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (service.isActive ? const Color(0xFF059669) : const Color(0xFFDC2626)).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                    ),
                    child: Text(
                      (service.isActive ? lang.tr('status_active', category: 'admin') : lang.tr('inactive', category: 'admin')).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                // Rating Badge
                Positioned(
                  bottom: 12,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          service.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.title,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Exo2',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${service.price} ${service.priceUnit}',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.description,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildChip(service.category, theme, isDark),
                      const SizedBox(width: 8),
                      _buildChip(service.subcategory, theme, isDark, isSub: true),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_note_rounded, color: theme.primaryColor),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(service.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.blueGrey),
                    tooltip: service.isActive ? 'Hide' : 'Show',
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, ThemeData theme, bool isDark, {bool isSub = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSub ? theme.primaryColor.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSub ? theme.primaryColor.withOpacity(0.1) : Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSub ? theme.primaryColor : theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ServiceSkeleton extends StatelessWidget {
  const _ServiceSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
