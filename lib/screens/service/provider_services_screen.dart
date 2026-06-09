import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/service/edit_service.dart';
import 'package:service_app/providers/language_provider.dart';

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

  // Colors matching create_service.dart
  static const Color kPrimaryBlue = Color(0xFF2563EB);
  static const Color kSuccessGreen = Color(0xFF059669);
  static const Color kErrorRed = Color(0xFFDC2626);
  static const Color kDarkTextColor = Color(0xFF1E293B);
  static const Color kMutedTextColor = Color(0xFF64748B);
  static const Color kLightBackgroundColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final UserModel? currentUser = authViewModel.currentUser;

      if (currentUser != null) {
        final services =
            await _firestoreService.getProviderServices(currentUser.uid);
        setState(() {
          _services = services;
        });
      } else {
        setState(() {
          _error = 'please_sign_in';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'unable_to_load';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshServices() async {
    await _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      appBar: AppBar(
        title: Text(
          lang.tr('my_services', category: 'my_services'),
          style: const TextStyle(
            color: kDarkTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kPrimaryBlue),
            onPressed: _refreshServices,
          ),
        ],
      ),
      body: _buildMainContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-service');
        },
        backgroundColor: kPrimaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _refreshServices,
      child: CustomScrollView(
        slivers: [
          // Stats Overview Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildStatsOverview(),
            ),
          ),

          // Services List or States
          if (_isLoading)
            SliverFillRemaining(
              child: _buildLoadingState(),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else if (_services.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
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
                    child: _buildServiceCard(_services[index]),
                  );
                },
                childCount: _services.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final lang = Provider.of<LanguageProvider>(context);

    int totalServices = _services.length;
    double avgRating = _calculateAverageRating();
    double totalEarnings = _calculateTotalEarnings();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            icon: Icons.work,
            value: '$totalServices',
            label: lang.tr('services', category: 'my_services'),
            color: kPrimaryBlue,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.star,
            value: avgRating.toStringAsFixed(1),
            label: lang.tr('avg_rating', category: 'my_services'),
            color: const Color(0xFFF59E0B),
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.attach_money,
            value: '${totalEarnings.toStringAsFixed(0)} DZD',
            label: lang.tr('earnings', category: 'my_services'),
            color: kSuccessGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
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
              color: kDarkTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: kMutedTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final lang = Provider.of<LanguageProvider>(context);

    return GestureDetector(
      onTap: () => _viewServiceDetails(service),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
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
                          style: const TextStyle(
                            color: kDarkTextColor,
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
                    style: const TextStyle(
                      color: kMutedTextColor,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Divider
            Divider(height: 1, color: Colors.grey.shade200),

            // Service details in sections (matching create service steps)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Category & Subcategory
                  _buildDetailRow(
                    icon: Icons.category,
                    label: lang.tr('category', category: 'my_services'),
                    value: service['category'] ??
                        lang.tr('not_specified', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.list,
                    label: lang.tr('subcategory', category: 'my_services'),
                    value: service['subcategory'] ??
                        lang.tr('not_specified', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),

                  // Pricing
                  _buildDetailRow(
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
                    icon: Icons.location_on,
                    label: lang.tr('location', category: 'my_services'),
                    value: service['location'] ??
                        lang.tr('not_specified', category: 'my_services'),
                  ),
                  const SizedBox(height: 12),

                  // Rating
                  _buildDetailRow(
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
                color: Colors.grey.shade50,
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
                        side: BorderSide(color: kPrimaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.edit, size: 18, color: kPrimaryBlue),
                      label: Text(
                        lang.tr('edit', category: 'my_services'),
                        style: TextStyle(color: kPrimaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewServiceDetails(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue,
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: kMutedTextColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMutedTextColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: kDarkTextColor,
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

  Widget _buildLoadingState() {
    final lang = Provider.of<LanguageProvider>(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kPrimaryBlue),
          const SizedBox(height: 20),
          Text(
            lang.tr('loading_services', category: 'my_services'),
            style: const TextStyle(color: kMutedTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final lang = Provider.of<LanguageProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: kErrorRed,
            ),
            const SizedBox(height: 20),
            Text(
              lang.tr('unable_to_load_services', category: 'my_services'),
              style: TextStyle(
                color: kDarkTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error != null ? lang.tr(_error!, category: 'my_services') : '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kMutedTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
              ),
              child: Text(lang.tr('try_again', category: 'my_services')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final lang = Provider.of<LanguageProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: kMutedTextColor,
            ),
            const SizedBox(height: 20),
            Text(
              lang.tr('no_services_yet', category: 'my_services'),
              style: TextStyle(
                color: kDarkTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lang.tr('create_first_service_hint', category: 'my_services'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kMutedTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create-service');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: Text(
                  lang.tr('create_first_service', category: 'my_services')),
            ),
          ],
        ),
      ),
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
        return kSuccessGreen;
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'inactive':
        return kMutedTextColor;
      case 'rejected':
        return kErrorRed;
      default:
        return kPrimaryBlue;
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        service['title'] ??
                            lang.tr('service_details', category: 'my_services'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: kDarkTextColor,
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
            Icon(icon, size: 20, color: kPrimaryBlue),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kDarkTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: kMutedTextColor,
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
