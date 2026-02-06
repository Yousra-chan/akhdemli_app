import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';

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
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load services: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: Column(
        children: [
          // Custom Header matching home page style
          _buildCustomHeader(context),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _services.isEmpty
                        ? _buildEmptyState()
                        : _buildServicesList(),
          ),
        ],
      ),

      // Floating Action Button matching home page style
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20, right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddServiceDialog,
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(CupertinoIcons.plus, size: 24),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 25,
        right: 25,
        bottom: 25,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPrimaryBlue,
            Color(0xFF4A6FDC),
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'My Services',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats card matching home page style
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(_services.length.toString(), 'Services',
                    const Color(0xFF667EEA)),
                _buildStatItem(
                  _calculateAverageRating().toStringAsFixed(1),
                  'Avg Rating',
                  const Color(0xFF4FACFE),
                ),
                _buildStatItem(
                  _calculateTotalEarnings().toStringAsFixed(0),
                  'Total \$',
                  const Color(0xFF43E97B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Exo2',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: kDarkTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Exo2',
          ),
        ),
      ],
    );
  }

  double _calculateAverageRating() {
    if (_services.isEmpty) return 0.0;
    final totalRating =
        _services.fold(0.0, (sum, service) => sum + (service['rating'] ?? 0.0));
    return totalRating / _services.length;
  }

  double _calculateTotalEarnings() {
    return _services.fold(
        0.0, (sum, service) => sum + (service['price'] ?? 0.0));
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kPrimaryBlue),
          const SizedBox(height: 20),
          Text(
            'Loading your services...',
            style: TextStyle(
              color: kMutedTextColor,
              fontSize: 16,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: kMutedTextColor,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Services',
              style: TextStyle(
                color: kDarkTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kMutedTextColor,
                  fontSize: 14,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: kPrimaryBlue,
                borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              ),
              child: GestureDetector(
                onTap: _loadServices,
                child: Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Exo2',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.wrench_fill,
              color: kPrimaryBlue,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Services Yet',
            style: TextStyle(
              color: kDarkTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start offering your services to clients.\nTap the + button to create your first service.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kMutedTextColor,
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: kPrimaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: _showAddServiceDialog,
              child: Text(
                'Create First Service',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Services (${_services.length})',
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              color: kPrimaryBlue,
              onRefresh: _loadServices,
              child: ListView.builder(
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  return _buildServiceCard(_services[index], index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    final colors = [
      const Color(0xFF667EEA),
      const Color(0xFF764BA2),
      const Color(0xFFF093FB),
      const Color(0xFFF5576C),
      const Color(0xFF4FACFE),
      const Color(0xFF00F2FE),
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBackgroundColor,
        borderRadius: BorderRadius.circular(kDefaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: kSoftShadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              CupertinoIcons.wrench_fill,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Service Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['title'] ?? 'Untitled Service',
                  style: const TextStyle(
                    color: kDarkTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  service['description'] ?? 'No description',
                  style: TextStyle(
                    color: kMutedTextColor,
                    fontSize: 13,
                    fontFamily: 'Exo2',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Price
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43E97B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF43E97B).withOpacity(0.3)),
                      ),
                      child: Text(
                        '\$${service['price']?.toStringAsFixed(0) ?? '0'}/hr',
                        style: const TextStyle(
                          color: Color(0xFF43E97B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Category
                    if (service['category'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPrimaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: kPrimaryBlue.withOpacity(0.3)),
                        ),
                        child: Text(
                          service['category'],
                          style: TextStyle(
                            color: kPrimaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Rating and Menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Rating
              Row(
                children: [
                  Icon(CupertinoIcons.star_fill,
                      color: kRatingYellow, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    (service['rating'] ?? 0.0).toStringAsFixed(1),
                    style: const TextStyle(
                      color: kDarkTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Menu Button
              PopupMenuButton<String>(
                icon: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: kMutedTextColor,
                  size: 18,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editService(service);
                  } else if (value == 'delete') {
                    _deleteService(service);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.pencil,
                            color: kPrimaryBlue, size: 16),
                        const SizedBox(width: 8),
                        Text('Edit',
                            style: TextStyle(
                                color: kDarkTextColor, fontFamily: 'Exo2')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.trash, color: kErrorRed, size: 16),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(
                                color: kErrorRed, fontFamily: 'Exo2')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kDefaultBorderRadius),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kDefaultBorderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Service',
                style: TextStyle(
                  color: kDarkTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Service creation form will go here',
                style: TextStyle(
                  color: kMutedTextColor,
                  fontSize: 14,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kMutedTextColor,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kPrimaryBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          // Add service logic
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Add Service',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editService(Map<String, dynamic> service) {
    print('Editing service: ${service['id']}');
    // Implement edit service navigation
  }

  void _deleteService(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kDefaultBorderRadius),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kDefaultBorderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: kErrorRed,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Service',
                style: TextStyle(
                  color: kDarkTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${service['title']}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kMutedTextColor,
                  fontSize: 14,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kMutedTextColor,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kErrorRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            await _firestoreService
                                .deleteService(service['id']);
                            _loadServices(); // Refresh the list
                            Navigator.pop(context);
                          } catch (e) {
                            print('Error deleting service: $e');
                          }
                        },
                        child: Text(
                          'Delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
