import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/service/create_service.dart';
import 'package:service_app/ViewModel/service_view_model.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/service/edit_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/providers/theme_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';

class MyServicesPage extends StatefulWidget {
  const MyServicesPage({super.key});

  @override
  State<MyServicesPage> createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage> {
  late FirestoreService _firestoreService;
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String? _error;

  // Colors logic
  Color _getPrimaryColor(BuildContext context) => Theme.of(context).primaryColor;
  Color _getSuccessColor() => const Color(0xFF059669);
  Color _getErrorColor() => const Color(0xFFDC2626);
  Color _getTextColor(BuildContext context) => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1E293B);
  Color _getMutedColor(BuildContext context) => Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? const Color(0xFF64748B);
  Color _getBackgroundColor(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  Color _getCardColor(BuildContext context) => Theme.of(context).cardColor;
  Color _getBorderColor(BuildContext context) => Theme.of(context).dividerColor;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final UserModel? currentUser = authViewModel.currentUser;

      if (currentUser != null) {
        final services =
        await _firestoreService.getProviderServices(currentUser.uid);
        if (mounted) {
          setState(() {
            _services = services;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'please_sign_in';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'unable_to_load';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshServices() async {
    await _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          lang.tr('my_services', category: 'my_services'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.primaryColor),
            onPressed: _refreshServices,
          ),
        ],
      ),
      body: _buildMainContent(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
            if (value == true) {
              _refreshServices();
            }
          });
        },
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _refreshServices,
      child: CustomScrollView(
        slivers: [
          // Stats Overview Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildStatsOverview(context),
            ),
          ),

          // Services List or States
          if (_isLoading)
            const SliverFillRemaining(
              child: LoadingWidget(),
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
                child: EmptyStateWidget(
                  message: lang.tr('no_services_yet', category: 'my_services'),
                  subtitle: lang.tr('create_first_service_hint', category: 'my_services'),
                  action: ElevatedButton(
                    onPressed: () {
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
                        if (value == true) {
                          _refreshServices();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                        lang.tr('create_first_service', category: 'my_services')),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        top: index == 0 ? 0 : 0,
                      ),
                      child: _buildServiceCard(context, _services[index]),
                    );
                  },
                  childCount: _services.length,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int totalServices = _services.length;
    double avgRating = _calculateAverageRating();
    double totalEarnings = _calculateTotalEarnings();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            context,
            icon: Icons.work,
            value: '$totalServices',
            label: lang.tr('services', category: 'my_services'),
            color: theme.primaryColor,
          ),
          _buildDivider(context),
          _buildStatItem(
            context,
            icon: Icons.star,
            value: avgRating.toStringAsFixed(1),
            label: lang.tr('avg_rating', category: 'my_services'),
            color: const Color(0xFFF59E0B),
          ),
          _buildDivider(context),
          _buildStatItem(
            context,
            icon: Icons.attach_money,
            value: '${totalEarnings.toStringAsFixed(0)} DZD',
            label: lang.tr('earnings', category: 'my_services'),
            color: _getSuccessColor(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color ?? Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> service) {
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _viewServiceDetails(service),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with title and status
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service['title'] ??
                              lang.tr('untitled_service',
                                  category: 'my_services'),
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(service['status'] ?? 'active')
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(service['status'] ?? 'active', lang),
                          style: TextStyle(
                            color:
                            _getStatusColor(service['status'] ?? 'active'),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service['description'] ??
                        lang.tr('no_description', category: 'my_services'),
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Divider
            Divider(height: 1, color: theme.dividerColor),

            // Service details in sections (matching create service steps)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Category & Subcategory
                  _buildDetailRow(
                    context,
                    icon: Icons.category,
                    label: lang.tr('category', category: 'my_services'),
                    value: service['category'] ??
                        lang.tr('not_specified', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.list,
                    label: lang.tr('subcategory', category: 'my_services'),
                    value: service['subcategory'] ??
                        lang.tr('not_specified', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),

                  // Pricing
                  _buildDetailRow(
                    context,
                    icon: Icons.attach_money,
                    label: lang.tr('price', category: 'my_services'),
                    value: service['price'] != null
                        ? lang.trParams('price_with_unit',
                        category: 'my_services',
                        params: {
                          'price': service['price'].toString(),
                          'unit': service['priceUnit'] ??
                              lang.tr('per_service',
                                  category: 'my_services')
                        })
                        : lang.tr('price_not_set', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),

                  // Location
                  _buildDetailRow(
                    context,
                    icon: Icons.location_on,
                    label: lang.tr('location', category: 'my_services'),
                    value: service['location'] ??
                        lang.tr('not_specified', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),

                  // Rating
                  _buildDetailRow(
                    context,
                    icon: Icons.star,
                    label: lang.tr('rating', category: 'my_services'),
                    value: service['rating'] != null
                        ? lang.trParams('rating_value',
                        category: 'my_services',
                        params: {'rating': service['rating'].toString()})
                        : lang.tr('no_ratings', category: 'my_services'),
                  ),
                ],
              ),
            ),

            // Footer with actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editService(service),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.edit, size: 18, color: theme.primaryColor),
                      label: Text(
                        lang.tr('edit', category: 'my_services'),
                        style: TextStyle(color: theme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewServiceDetails(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: Text(
                          lang.tr('view_details', category: 'my_services')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText(String status, LanguageProvider lang) {
    switch (status.toLowerCase()) {
      case 'active':
        return lang.tr('status_active', category: 'my_services');
      case 'pending':
        return lang.tr('status_pending', category: 'my_services');
      case 'inactive':
        return lang.tr('status_inactive', category: 'my_services');
      case 'rejected':
        return lang.tr('status_rejected', category: 'my_services');
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _getSuccessColor();
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'inactive':
        return _getMutedColor(context);
      case 'rejected':
        return _getErrorColor();
      default:
        return _getPrimaryColor(context);
    }
  }

  void _viewServiceDetails(Map<String, dynamic> service) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer<LanguageProvider>(
          builder: (context, lang, child) {
            return Container(
              decoration: BoxDecoration(
                color: _getCardColor(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: _getBorderColor(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        service['title'] ??
                            lang.tr('service_details', category: 'my_services'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        lang.tr('description', category: 'my_services'),
                        service['description'] ??
                            lang.tr('no_description', category: 'my_services'),
                        Icons.description,
                      ),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        lang.tr('category_subcategory',
                            category: 'my_services'),
                        '${service['category'] ?? 'N/A'} • ${service['subcategory'] ?? 'N/A'}',
                        Icons.category,
                      ),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        lang.tr('pricing', category: 'my_services'),
                        service['price'] != null
                            ? lang.trParams('price_with_unit_details',
                            category: 'my_services',
                            params: {
                              'price': service['price'].toString(),
                              'unit': service['priceUnit'] ??
                                  lang.tr('per_service',
                                      category: 'my_services')
                            })
                            : lang.tr('not_specified', category: 'my_services'),
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        lang.tr('location', category: 'my_services'),
                        service['location'] ??
                            lang.tr('not_specified', category: 'my_services'),
                        Icons.location_on,
                      ),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        lang.tr('status', category: 'my_services'),
                        _getStatusText(service['status'] ?? 'active', lang),
                        Icons.info,
                      ),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        lang.tr('created', category: 'my_services'),
                        _formatDate(service['createdAt']),
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: _getPrimaryColor(context)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _getTextColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: _getMutedColor(context),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return date.toString();
  }

  void _editService(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditServiceScreen(
          serviceData: {
            'id': service['id'],
            'title': service['title'],
            'description': service['description'],
            'category': service['category'],
            'subcategory': service['subcategory'],
            'price': service['price'],
            'priceUnit': service['priceUnit'],
            'location': service['location'],
            'latitude': service['latitude'],
            'longitude': service['longitude'],
            'tags': service['tags'] ?? [],
            'images': service['images'] ?? [],
            'isActive': service['isActive'] ?? true,
            'rating': service['rating'] ?? 0.0,
            'totalReviews': service['totalReviews'] ?? 0,
          },
        ),
      ),
    );
  }

  double _calculateAverageRating() {
    if (_services.isEmpty) return 0.0;
    double total = 0;
    int count = 0;
    for (var service in _services) {
      if (service['rating'] != null) {
        total += service['rating'];
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  double _calculateTotalEarnings() {
    if (_services.isEmpty) return 0.0;
    double total = 0;
    for (var service in _services) {
      if (service['price'] != null && service['completedJobs'] != null) {
        total += service['price'] * service['completedJobs'];
      }
    }
    return total;
  }
}
