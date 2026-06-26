import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/Services/booking_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/screens/home/home_screen/home_constants.dart';
import 'package:service_app/screens/posts/posts_widgets.dart';

const kTextSecondary = Color(0xFF718096);
const kAccentColor = Color(0xFFFF6B6B);

class ProviderProfileScreen extends StatefulWidget {
  final ProviderModel provider;
  final String serviceCategory;

  const ProviderProfileScreen({
    required this.provider,
    required this.serviceCategory,
    super.key,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late double _currentRating;
  bool _isSubmitting = false;
  late ProviderModel _provider;
  final BookingService _bookingService = BookingService();
  List<Map<String, dynamic>> _providerServices = [];
  Map<String, dynamic>? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _notes = '';
  bool _loadingServices = true;
  bool _showBookingForm = false;
  int _bookedCount = 0;
  final ScrollController _scrollController = ScrollController();
  List<String> _serviceGallery = [];

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _currentRating = _provider.rating;
    _checkIfUserHasRated();
    _loadProviderServices();
    _loadBookedCount();
    _loadServiceGallery();
  }

  Future<void> _loadServiceGallery() async {
    try {
      final images = await _provider.fetchServiceImages();
      if (mounted) {
        setState(() {
          _serviceGallery = images;
        });
      }
    } catch (e) {
      debugPrint('Error loading service gallery: $e');
    }
  }

  Future<void> _loadBookedCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _provider.uid)
          .get();
      if (mounted) {
        setState(() {
          _bookedCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      // keep default 0
    }
  }

  Future<void> _reportProvider() async {
    final TextEditingController reportController = TextEditingController();
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_report'));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_tr(context, 'report_user'),
              style: const TextStyle(
                  fontFamily: 'Exo2', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_tr(context, 'report_description'),
                  style: const TextStyle(fontFamily: 'Exo2')),
              const SizedBox(height: 16),
              TextField(
                controller: reportController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: _tr(context, 'describe_issue'),
                  hintStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reportController.text.trim();
                if (reason.isEmpty) return;

                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': authViewModel.currentUser!.uid,
                    'reportedId': _provider.uid,
                    'reason': reason,
                    'timestamp': FieldValue.serverTimestamp(),
                    'type': 'provider_profile',
                    'status': 'pending',
                  });
                  if (!mounted) return;
                  AppSnackBar.showSuccess(
                      context, _tr(context, 'report_submitted'));
                } catch (e) {
                  if (!mounted) return;
                  AppSnackBar.showError(context,
                      _trParams(context, 'error', {'error': e.toString()}));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_tr(context, 'submit'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockProvider() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_block'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_tr(context, 'block_user'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            _trParams(context, 'block_confirm', {'name': _provider.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text(_tr(context, 'block'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authViewModel.currentUser!.uid)
            .update({
          'blockedUsers': FieldValue.arrayUnion([_provider.uid]),
        });
        if (!mounted) return;
        AppSnackBar.showSuccess(
            context, _trParams(context, 'user_blocked', {'name': _provider.name}));
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.showError(context,
            _trParams(context, 'error', {'error': e.toString()}));
      }
    }
  }

  String _tr(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.tr(key, category: 'provider_profile');
  }

  String _trParams(
      BuildContext context, String key, Map<String, String> params) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.trParams(key,
        category: 'provider_profile', params: params);
  }

  Future<void> _loadProviderServices() async {
    try {
      final services = await _getProviderServices(_provider.uid ?? '');
      if (mounted) {
        setState(() {
          _providerServices = services;
          _loadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingServices = false;
        });
      }
    }
  }

  Future<void> _checkIfUserHasRated() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('ratings')
          .doc('${authViewModel.currentUser!.uid}_${_provider.uid}')
          .get();
    } catch (e) {
      // Error
    }
  }

  Future<void> _submitRating(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_rate'));
      return;
    }

    if (_provider.uid == null || _provider.uid!.isEmpty) {
      AppSnackBar.showError(context, _tr(context, 'provider_info_incomplete'));
      return;
    }

    if (mounted) setState(() => _isSubmitting = true);

    try {
      final currentUser = authViewModel.currentUser!;
      final ratingId = '${currentUser.uid}_${_provider.uid!}';

      await FirebaseFirestore.instance.collection('ratings').doc(ratingId).set({
        'userId': currentUser.uid,
        'providerId': _provider.uid!,
        'rating': _currentRating,
        'createdAt': FieldValue.serverTimestamp(),
        'userName': currentUser.name,
        'userPhoto': currentUser.photoUrl,
      });

      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('providerId', isEqualTo: _provider.uid!)
          .get();

      double totalRating = 0;
      int ratingCount = ratingsSnapshot.docs.length;

      for (var doc in ratingsSnapshot.docs) {
        final data = doc.data();
        if (data['rating'] != null) {
          totalRating += (data['rating'] as num).toDouble();
        }
      }

      final newAverageRating =
          ratingCount > 0 ? totalRating / ratingCount : 0.0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_provider.uid!)
          .update({
        'rating': newAverageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _provider = _provider.copyWith(rating: newAverageRating);
          _currentRating = newAverageRating;
        });

        if (!context.mounted) return;
        AppSnackBar.showSuccess(
            context,
            _trParams(context, 'thank_you_rating',
                {'name': _provider.name, 'rating': _currentRating.toStringAsFixed(1)}));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context,
            _trParams(context, 'failed_submit_rating', {'error': e.toString()}));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _bookService() async {
    final authViewModel = context.read<AuthViewModel>();
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_book'));
      return;
    }

    if (_selectedService == null) {
      AppSnackBar.showError(context, _tr(context, 'please_select_service'));
      return;
    }

    if (_selectedDate == null) {
      AppSnackBar.showError(context, _tr(context, 'please_select_date'));
      return;
    }

    if (_selectedTime == null) {
      AppSnackBar.showError(context, _tr(context, 'please_select_time'));
      return;
    }

    try {
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (appointmentDateTime.isBefore(DateTime.now())) {
        AppSnackBar.showError(context, _tr(context, 'select_future_datetime'));
        return;
      }

      // 1. OPTIMISTIC UI
      _showSuccessDialog(appointmentDateTime);
      setState(() {
        _showBookingForm = false;
      });

      // 2. BACKGROUND SYNC
      final booking = BookingModel(
        id: '',
        clientId: currentUser.uid,
        providerId: _provider.uid!,
        serviceId: _selectedService!['id'],
        serviceTitle: _selectedService!['title'],
        servicePrice: (_selectedService!['price'] ?? 0).toDouble(),
        appointmentDate: appointmentDateTime,
        status: 'pending',
        notes: _notes,
        createdAt: DateTime.now(),
        clientName: currentUser.name,
        providerName: _provider.name,
        clientPhone: currentUser.phone,
        providerPhone: _provider.phone,
      );

      _bookingService.createBooking(booking).then((success) {
        if (success) {
          _loadBookedCount();
        }
      });
    } catch (e) {
      debugPrint('❌ Booking execution error: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              onSurface: theme.textTheme.bodyLarge?.color,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              onSurface: theme.textTheme.bodyLarge?.color,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 320.0,
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeaderBackground(theme),
                ),
                leading: _buildHeaderIcon(
                    Icons.arrow_back, () => Navigator.pop(context), theme),
                actions: [
                  _buildHeaderIcon(Icons.share_outlined, _shareProfile, theme),
                  _buildHeaderIcon(
                      Icons.more_vert, () => _showMoreOptions(context), theme),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _buildStatsSection(theme),
                    _buildAboutSection(theme),
                    _buildContactSection(theme),
                    _buildServiceGallerySection(theme),
                    _buildPortfolioSection(theme),
                    _buildServicesSection(theme),
                    if (_showBookingForm) _buildBookingForm(theme),
                    _buildRatingSection(theme),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          _buildBottomActionButtons(theme),
          if (!_showBookingForm && _providerServices.isNotEmpty)
            PositionedDirectional(
              bottom: 100,
              end: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedService = _providerServices.first;
                    _showBookingForm = true;
                  });
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                },
                backgroundColor: primaryColor,
                elevation: 4,
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                label: Text(_tr(context, 'book_now'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }

  void _shareProfile() {
    HapticFeedback.mediumImpact();
    final profileText = _trParams(context, 'share_profile_text', {'name': _provider.name});
    Clipboard.setData(ClipboardData(text: profileText)).then((_) {
      if (mounted) AppSnackBar.showInfo(context, _tr(context, 'copied_to_clipboard'));
    });
  }

  void _showMoreOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _reportProvider();
            },
            child: Text(_tr(context, 'report'),
                style: const TextStyle(color: Colors.red)),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _blockProvider();
            },
            child: Text(_tr(context, 'block'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(_tr(context, 'cancel')),
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(ThemeData theme) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryColor,
                theme.primaryColor.withValues(alpha: 0.8),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
        // Profile Info
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: ClipOval(child: _buildProfileImage()),
              ),
              const SizedBox(height: 12),
              Text(
                _provider.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Exo2',
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_provider.isSubscriptionActive)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 6),
                      child: Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                    ),
                  Icon(Icons.verified, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    getTranslatedCategoryName(_provider.profession, lang),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_provider.isSubscriptionActive)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _tr(context, 'golden_user'),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _buildRatingBadge(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            _currentRating.toStringAsFixed(1),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_provider.photoUrl.isNotEmpty) {
      final provider = ImageUtils.getImageProvider(_provider.photoUrl);
      if (provider != null) {
        return Image(image: provider, fit: BoxFit.cover);
      }
    }
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.person, size: 60, color: Colors.grey.shade400),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, _tr(context, 'booked'), '$_bookedCount',
              Icons.check_circle_outline),
          _buildStatItem(theme, _tr(context, 'services'),
              '${_providerServices.length}', Icons.work_outline),
          _buildStatItem(theme, _tr(context, 'rating'),
              _currentRating.toStringAsFixed(1), Icons.star_outline),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, String label, String value, IconData icon) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: Icon(icon, color: theme.primaryColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
                fontFamily: 'Exo2')),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : kTextSecondary)),
      ],
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'about_me'),
      icon: Icons.person_outline,
      child: Text(
        _provider.description.isNotEmpty
            ? _provider.description
            : _tr(context, 'no_description_provided'),
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: theme.brightness == Brightness.dark
              ? Colors.white70
              : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildServiceGallerySection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'service_gallery'),
      icon: Icons.collections_outlined,
      child: _serviceGallery.isEmpty
          ? _buildGalleryPlaceholder(theme)
          : SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _serviceGallery.length,
                itemBuilder: (context, index) {
                  return _buildGalleryItem(_serviceGallery, index, theme);
                },
              ),
            ),
    );
  }

  Widget _buildGalleryPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, style: BorderStyle.none),
      ),
      child: Column(
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            _tr(context, 'no_service_photos_yet'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryItem(List<String> images, int index, ThemeData theme) {
    return GestureDetector(
      onTap: () => _openImageViewer(images, index),
      child: Container(
        width: 140,
        margin: const EdgeInsetsDirectional.only(end: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildVisualImage(images[index]),
        ),
      ),
    );
  }

  void _openImageViewer(List<String> images, int index) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImageViewerDialog(imageUrls: images, initialIndex: index),
    );
  }

  Widget _buildVisualImage(String image) {
    final provider = ImageUtils.getImageProvider(image);
    if (provider != null) {
      return Image(image: provider, fit: BoxFit.cover);
    }
    return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey));
  }

  Widget _buildPortfolioSection(ThemeData theme) {
    if (_provider.portfolio.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'my_work_portfolio'),
      icon: Icons.photo_library_outlined,
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _provider.portfolio.length,
          itemBuilder: (context, index) {
            return _buildGalleryItem(_provider.portfolio, index, theme);
          },
        ),
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    final lang = Provider.of<LanguageProvider>(context);
    final locationText = _provider.getLocalizedLocation(lang);

    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'contact_information'),
      icon: Icons.contact_mail_outlined,
      child: Column(
        children: [
          _buildContactTile(theme, Icons.phone_iphone, _tr(context, 'phone'),
              _provider.phone, Colors.blue, () => _makePhoneCall(_provider.phone)),
          const Divider(height: 1, indent: 50),
          _buildContactTile(
              theme,
              Icons.location_on_outlined,
              _tr(context, 'address'),
              locationText,
              Colors.redAccent,
              () => _openLocationInMaps(locationText)),
        ],
      ),
    );
  }

  Widget _buildContactTile(ThemeData theme, IconData icon, String title,
      String value, Color iconColor, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 12, color: Colors.grey.shade500, fontFamily: 'Exo2')),
      subtitle: Text(value,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color)),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }

  Widget _buildServicesSection(ThemeData theme) {
    if (_providerServices.isEmpty && !_loadingServices)
      return const SizedBox.shrink();

    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'services_offered'),
      icon: Icons.settings_suggest_outlined,
      child: _loadingServices
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : Column(
              children: _providerServices.map((service) {
                final isSelected = _selectedService?['id'] == service['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withValues(alpha: 0.08)
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: isSelected
                            ? theme.primaryColor
                            : theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedService = service;
                        _showBookingForm = true;
                      });
                    },
                    title: Text(service['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(
                        '${service['price'] ?? '0'} ${_tr(context, 'dzd')}',
                        style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme.primaryColor)
                        : const Icon(Icons.add_circle_outline, size: 20),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRatingSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'rate_provider'),
      icon: Icons.star_border_purple500_outlined,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                    index < _currentRating.floor()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 42),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentRating = (index + 1).toDouble());
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submitRating(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_tr(context, 'submit_rating'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _startChat(context),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: Text(_tr(context, 'message'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Container(
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                onPressed: () => _makePhoneCall(_provider.phone),
                icon: const Icon(Icons.phone_outlined, color: Colors.green),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required ThemeData theme,
      required String title,
      required IconData icon,
      required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.titleLarge?.color,
                      fontFamily: 'Exo2')),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBookingForm(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: theme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(_tr(context, 'book_service'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Exo2')),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showBookingForm = false)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSelectionTile(
            icon: Icons.event,
            title: _tr(context, 'date'),
            value: _selectedDate != null
                ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!)
                : _tr(context, 'select_date'),
            onTap: () => _selectDate(context),
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildSelectionTile(
            icon: Icons.schedule,
            title: _tr(context, 'time'),
            value: _selectedTime != null
                ? _selectedTime!.format(context)
                : _tr(context, 'select_time'),
            onTap: () => _selectTime(context),
            theme: theme,
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (v) => _notes = v,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: _tr(context, 'add_instructions'),
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_selectedDate != null && _selectedTime != null)
                  ? _bookService
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: Text(_tr(context, 'confirm_booking'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile(
      {required IconData icon,
      required String title,
      required String value,
      required VoidCallback onTap,
      required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _startChat(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUser = authViewModel.currentUser;
    if (currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_message'));
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final chatViewModel = ChatViewModel(userId: currentUser.uid);
      final chatId = await chatViewModel.createChat(
          clientId: currentUser.uid, providerId: _provider.uid!);

      if (mounted) {
        Navigator.pop(context);
        if (chatId != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DiscussionPage(
                        contactName: _provider.name,
                        isOnline: true,
                        chatId: chatId,
                        currentUserId: currentUser.uid,
                        chatViewModel: chatViewModel,
                        profileImageUrl: _provider.photoUrl,
                        contactUserId: _provider.uid,
                      )));
        } else {
          AppSnackBar.showError(context, _tr(context, 'failed_to_start_chat'));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(
            context, _trParams(context, 'error', {'error': e.toString()}));
      }
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _openLocationInMaps(String address) async {
    final url =
        Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showSuccessDialog(DateTime appointmentDateTime) {
    showDialog(
      context: context,
      builder: (context) => ProfessionalSuccessDialog(
        title: _tr(context, 'booking_confirmed'),
        message: _trParams(
            context, 'appointment_scheduled', {'name': _provider.name}),
        onDone: () => Navigator.pop(context),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getProviderServices(
      String providerId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('services')
        .where('providerId', isEqualTo: providerId)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
