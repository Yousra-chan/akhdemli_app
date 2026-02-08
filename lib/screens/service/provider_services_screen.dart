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

class _MyServicesPageState extends State<MyServicesPage>
    with SingleTickerProviderStateMixin {
  late FirestoreService _firestoreService;
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String? _error;
  late ScrollController _scrollController;
  bool _showScrollToTop = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _showScrollToTop = _scrollController.offset > 400;
        });
      });

    _loadServices().then((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      if (!_isRefreshing) {
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
        setState(() {
          _services = services;
        });
      } else {
        setState(() {
          _error = 'Please sign in to view services';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Unable to load services. Please check your connection.';
      });
      print('Error loading services: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshServices() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadServices();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          );
        },
        child: _buildMainContent(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Fixed Header
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(
                maxHeight: 180,
                minHeight: 80,
              ),
            ),

            // Stats Overview
            SliverToBoxAdapter(
              child: _buildStatsOverview(),
            ),

            // Services Title
            SliverToBoxAdapter(
              child: _buildServicesTitle(),
            ),

            // Services List or States
            if (_isLoading && !_isRefreshing) ...[
              SliverFillRemaining(
                child: _buildLoadingState(),
              )
            ] else if (_error != null) ...[
              SliverFillRemaining(
                child: _buildErrorState(),
              )
            ] else if (_services.isEmpty) ...[
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: 100,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : 12,
                        bottom: index == _services.length - 1 ? 20 : 0,
                      ),
                      child: _buildServiceCard(_services[index], index),
                    ),
                    childCount: _services.length,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Scroll to Top Button
        if (_showScrollToTop)
          Positioned(
            bottom: 120,
            right: 20,
            child: _buildScrollToTopButton(),
          ),

        // Loading Overlay for Refresh
        if (_isRefreshing)
          Positioned(
            top: 180,
            left: 0,
            right: 0,
            child: _buildRefreshIndicator(),
          ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, right: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 12, 94, 153).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _showAddServiceDialog,
        backgroundColor: const Color.fromARGB(255, 12, 94, 153),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(CupertinoIcons.plus, size: 24),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            icon: CupertinoIcons.briefcase_fill,
            value: _services.length.toString(),
            label: 'Services',
            color: const Color.fromARGB(255, 12, 94, 153),
          ),
          _buildDivider(),
          _buildStatItem(
            icon: CupertinoIcons.star_fill,
            value: _calculateAverageRating().toStringAsFixed(1),
            label: 'Avg Rating',
            color: const Color(0xFFF59E0B),
          ),
          _buildDivider(),
          _buildStatItem(
            icon: CupertinoIcons.money_dollar_circle_fill,
            value: '\$${_calculateTotalEarnings().toStringAsFixed(0)}',
            label: 'Earnings',
            color: const Color(0xFF10B981),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Exo2',
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade200,
    );
  }

  Widget _buildServicesTitle() {
    if (_isLoading || _error != null || _services.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Your Services',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 12, 94, 153).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_services.length} ${_services.length == 1 ? 'item' : 'items'}',
              style: TextStyle(
                color: const Color.fromARGB(255, 12, 94, 153),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    final colorScheme = [
      const Color.fromARGB(255, 12, 94, 153),
      const Color(0xFF667EEA),
      const Color(0xFF764BA2),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
    ];
    final color = colorScheme[index % colorScheme.length];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _viewServiceDetails(service),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Column(
            children: [
              // Service Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          _getServiceIcon(service['category']),
                          color: color,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Service Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service['title'] ?? 'Untitled Service',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Exo2',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service['description'] ?? 'No description',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontFamily: 'Exo2',
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Service Footer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Price Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '\$${service['price']?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Exo2',
                            ),
                          ),
                          Text(
                            '/hr',
                            style: TextStyle(
                              color: const Color(0xFF10B981).withOpacity(0.8),
                              fontSize: 12,
                              fontFamily: 'Exo2',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Rating
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.star_fill,
                          color: const Color(0xFFF59E0B),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (service['rating'] ?? 0.0).toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Exo2',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Actions Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        CupertinoIcons.ellipsis_vertical,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editService(service);
                        } else if (value == 'delete') {
                          _deleteService(service);
                        } else if (value == 'view') {
                          _viewServiceDetails(service);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.eye,
                                  color: Colors.grey.shade600, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontFamily: 'Exo2',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.pencil,
                                  color: const Color.fromARGB(255, 12, 94, 153),
                                  size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Service',
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 12, 94, 153),
                                  fontFamily: 'Exo2',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.trash,
                                  color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Exo2',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
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

  IconData _getServiceIcon(String? category) {
    if (category == null) return CupertinoIcons.wrench_fill;

    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('electr')) {
      return CupertinoIcons.bolt_fill;
    } else if (lowerCategory.contains('plumb')) {
      return CupertinoIcons.drop_fill;
    } else if (lowerCategory.contains('clean')) {
      return CupertinoIcons.house_fill;
    } else if (lowerCategory.contains('tutor')) {
      return CupertinoIcons.book_fill;
    } else if (lowerCategory.contains('garden')) {
      return CupertinoIcons.clear_fill;
    }
    return CupertinoIcons.wrench_fill;
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: const Color.fromARGB(255, 12, 94, 153),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading services...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait a moment',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Services',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _refreshServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 12, 94, 153),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.refresh, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Exo2',
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 12, 94, 153).withOpacity(0.1),
                    const Color.fromARGB(255, 12, 94, 153).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.wrench_fill,
                color: Color.fromARGB(255, 12, 94, 153),
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Services Yet',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Start offering your professional services to clients and grow your business. Create your first service to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  height: 1.5,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _showAddServiceDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 12, 94, 153),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.plus, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Create Your First Service',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Show tutorial or help
              },
              child: Text(
                'Learn how to create great service listings →',
                style: TextStyle(
                  color: const Color.fromARGB(255, 12, 94, 153),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 12, 94, 153),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_upward,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _scrollToTop,
      ),
    );
  }

  Widget _buildRefreshIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color.fromARGB(255, 12, 94, 153),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Refreshing...',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog() {
    // Show beautiful add service dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'Add New Service',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Exo2',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new service offering for your clients',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ],
                  ),
                ),
                // Add form content here...
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewServiceDetails(Map<String, dynamic> service) {
    // Navigate to service details page
    print('Viewing service: ${service['id']}');
  }

  void _editService(Map<String, dynamic> service) {
    // Navigate to edit service page
    print('Editing service: ${service['id']}');
  }

  void _deleteService(Map<String, dynamic> service) {
    // Show delete confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Service?',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Exo2',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${service['title']}"?',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                height: 1.5,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Implement delete logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double maxHeight;
  final double minHeight;

  _HeaderDelegate({
    required this.maxHeight,
    required this.minHeight,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final shrinkRatio = shrinkOffset / (maxHeight - minHeight);
    final opacity = 1.0 - shrinkRatio.clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 12, 94, 153),
            const Color(0xFF4A6FDC),
            const Color(0xFF667EEA),
            const Color(0xFF764BA2),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    CupertinoIcons.back,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Title (fades out as header shrinks)
              Opacity(
                opacity: opacity,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'My Services',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage your offerings',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Right side placeholder for balance
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.line_horizontal_3,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

// Helper functions
double _calculateAverageRating() {
  // Implementation
  return 0.0;
}

double _calculateTotalEarnings() {
  // Implementation
  return 0.0;
}
