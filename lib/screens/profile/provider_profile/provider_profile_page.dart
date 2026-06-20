import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/services/booking_service.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/Services/booking_notification_service.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';

const kPrimaryColor = Color(0xFF667EEA);
const kSecondaryColor = Color(0xFF764BA2);
const kAccentColor = Color(0xFFFF6B6B);
const kSuccessColor = Color(0xFF4ECDC4);
const kWarningColor = Color(0xFFFFD166);
const kCardBg = Color(0xFFF8FAFF);
const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kBorderColor = Color(0xFFE2E8F0);
const kShadowColor = Color(0x1A000000);
const kLightBg = Color(0xFFF7FAFC);

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
  bool _hasRated = false;
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

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _currentRating = _provider.rating;
    _checkIfUserHasRated();
    _loadProviderServices();
    _loadBookedCount();
  }

  Future<void> _loadBookedCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: _provider.uid)
          .get();
      setState(() {
        _bookedCount = snapshot.docs.length;
      });
    } catch (e) {
      // keep default 0
    }
  }

  Future<void> _reportProvider() async {
    final TextEditingController reportController = TextEditingController();
    final authViewModel = context.read<AuthViewModel>();

    if (authViewModel.currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_report'));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr(context, 'report_user')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_tr(context, 'report_description')),
              const SizedBox(height: 10),
              TextField(
                controller: reportController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: _tr(context, 'describe_issue'),
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
                  });
                  if (!context.mounted) return;
                  AppSnackBar.showSuccess(context, _tr(context, 'report_submitted'));
                } catch (e) {
                  if (!context.mounted) return;
                  AppSnackBar.showError(context, 'Error submitting report: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
              child: Text(_tr(context, 'submit'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockProvider() async {
    final authViewModel = context.read<AuthViewModel>();

    if (authViewModel.currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_block'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(context, 'block_user')),
        content: Text(_trParams(context, 'block_confirm', {'name': _provider.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_tr(context, 'block'), style: const TextStyle(color: Colors.white)),
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
        if (!context.mounted) return;
        AppSnackBar.showSuccess(context, _trParams(context, 'user_blocked', {'name': _provider.name}));
        Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.showError(context, 'Error blocking user: $e');
      }
    }
  }

  Future<void> _applySubscriptionCode(String code) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final query = await FirebaseFirestore.instance
          .collection('subscription_codes')
          .where('code', isEqualTo: code)
          .where('validUntil', isGreaterThan: now)
          .get();

      if (query.docs.isEmpty) {
        AppSnackBar.showError(context, _tr(context, 'invalid_or_expired_code'));
        return;
      }

      QueryDocumentSnapshot? matched;
      for (final doc in query.docs) {
        final data = doc.data();
        final used = data['used'] ?? false;
        final assignedTo = data['providerId'] as String?;
        if (used == true) continue;
        if (assignedTo == null || assignedTo == _provider.uid) {
          matched = doc;
          break;
        }
      }

      if (matched == null) {
        AppSnackBar.showError(context, _tr(context, 'code_not_available_for_you'));
        return;
      }

      final data = matched.data() as Map<String, dynamic>;
      final validUntil = data['validUntil'] as Timestamp?;
      if (validUntil == null || validUntil.toDate().isBefore(DateTime.now())) {
        AppSnackBar.showError(context, _tr(context, 'invalid_or_expired_code'));
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_provider.uid)
          .update({
        'subscriptionActive': true,
        'subscriptionExpiry': validUntil,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await matched.reference.update({
        'used': true,
        'usedBy': _provider.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _provider = _provider.copyWith(subscriptionActive: true);
      });

      AppSnackBar.showSuccess(context, _tr(context, 'subscription_activated'));
    } catch (e) {
      AppSnackBar.showError(context, _trParams(context, 'error', {'error': e.toString()}));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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
      setState(() {
        _providerServices = services;
        _loadingServices = false;
      });
    } catch (e) {
      setState(() {
        _loadingServices = false;
      });
    }
  }

  Future<void> _checkIfUserHasRated() async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;

    try {
      final ratingDoc = await FirebaseFirestore.instance
          .collection('ratings')
          .doc('${authViewModel.currentUser!.uid}_${_provider.uid}')
          .get();

      if (ratingDoc.exists) {
        setState(() {
          _hasRated = true;
        });
      }
    } catch (e) {
      // Error
    }
  }

  Future<void> _submitRating(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    if (authViewModel.currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_rate'));
      return;
    }

    if (_provider.uid == null || _provider.uid!.isEmpty) {
      AppSnackBar.showError(context, _tr(context, 'provider_info_incomplete'));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

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

      setState(() {
        _hasRated = true;
        _provider = _provider.copyWith(rating: newAverageRating);
        _currentRating = newAverageRating;
      });

      AppSnackBar.showSuccess(context, _trParams(context, 'thank_you_rating',
              {'name': _provider.name, 'rating': _currentRating.toString()}));
    } catch (e) {
      AppSnackBar.showError(context, _trParams(context, 'failed_submit_rating', {'error': e.toString()}));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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

      final success = await _bookingService.createBooking(booking);

      if (success) {
        await BookingNotificationService.sendNewBookingNotification(
          providerId: _provider.uid!,
          providerName: _provider.name,
          clientName: currentUser.name,
          serviceName: _selectedService!['title'],
          clientId: currentUser.uid,
          bookingId: booking.id,
          appointmentDate: appointmentDateTime,
        );

        await _loadBookedCount();
        _showSuccessDialog(appointmentDateTime);
      } else {
        if (!context.mounted) return;
        AppSnackBar.showError(context, _tr(context, 'failed_create_booking'));
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, _trParams(context, 'error', {'error': e.toString()}));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor: cardBg,
                expandedHeight: 280.0,
                pinned: true,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.only(left: 8, top: 8, right: 8),
                  decoration: BoxDecoration(
                    color: cardBg.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 8, left: 8),
                    decoration: BoxDecoration(
                      color: cardBg.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: primaryColor),
                      color: cardBg,
                      onSelected: (value) {
                        if (value == 'report') _reportProvider();
                        if (value == 'block') _blockProvider();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              const Icon(Icons.report_outlined, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Text(_tr(context, 'report')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                              const SizedBox(width: 10),
                              Text(_tr(context, 'block')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeaderBackground(theme),
                  centerTitle: false,
                  titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                  title: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _provider.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _buildContactSection(theme),
                    const SizedBox(height: 16),
                    _buildPortfolioSection(theme),
                    const SizedBox(height: 16),
                    _buildServicesSection(theme),
                    const SizedBox(height: 16),
                    if (_showBookingForm) _buildBookingForm(theme),
                    _buildStatsSection(theme),
                    const SizedBox(height: 16),
                    _buildRatingSection(theme),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          if (!_showBookingForm && _providerServices.isNotEmpty)
            PositionedDirectional(
              bottom: 20,
              end: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _selectedService = _providerServices.first;
                    _showBookingForm = true;
                  });
                },
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.calendar_today),
                label: Text(_tr(context, 'book_now')),
              ),
            ),
          if (!_showBookingForm)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 10, offset: const Offset(0, -2)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.message,
                        label: _tr(context, 'message'),
                        color: primaryColor,
                        onTap: () => _startChat(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.call,
                      label: _tr(context, 'call'),
                      color: kSuccessColor,
                      onTap: () => _makePhoneCall(_provider.phone),
                      isSmall: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: isSmall ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isSmall ? 18 : 20, color: color),
              if (!isSmall) const SizedBox(width: 8),
              if (!isSmall) Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioSection(ThemeData theme) {
    if (_provider.portfolio.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'my_work_portfolio'),
      icon: Icons.photo_library_outlined,
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _provider.portfolio.length,
          itemBuilder: (context, index) {
            final image = _provider.portfolio[index];
            return Container(
              width: 150,
              margin: const EdgeInsetsDirectional.only(end: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ImageUtils.isBase64Image(image)
                    ? Image.memory(ImageUtils.decodeBase64Image(image)!, fit: BoxFit.cover)
                    : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildServicesSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'services_offered'),
      icon: Icons.work_outline,
      child: _loadingServices
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : Column(
              children: _providerServices.map((service) {
                final isSelected = _selectedService?['id'] == service['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor.withOpacity(0.05) : theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? theme.primaryColor : theme.dividerColor),
                  ),
                  child: ListTile(
                    onTap: () => setState(() {
                      _selectedService = service;
                      _showBookingForm = true;
                    }),
                    title: Text(service['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${service['price'] ?? '0'} ${_tr(context, 'dzd')}'),
                    trailing: isSelected ? Icon(Icons.check_circle, color: theme.primaryColor) : null,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBookingForm(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tr(context, 'book_service'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildSelectionCard(
            icon: Icons.calendar_month,
            title: _tr(context, 'date'),
            value: _selectedDate != null ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!) : _tr(context, 'select_appointment_date'),
            onTap: () => _selectDate(context),
            color: kAccentColor,
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            icon: Icons.access_time,
            title: _tr(context, 'time'),
            value: _selectedTime != null ? _selectedTime!.format(context) : _tr(context, 'select_appointment_time'),
            onTap: () => _selectTime(context),
            color: const Color(0xFF4ECDC4),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (value) => _notes = value,
            decoration: InputDecoration(
              hintText: _tr(context, 'add_instructions'),
              hintStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : Colors.grey),
            ),
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_selectedService != null && _selectedDate != null && _selectedTime != null) ? _bookService : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_tr(context, 'confirm_booking')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: ClipOval(child: _buildProfileImage()),
              ),
              const SizedBox(height: 12),
              Text(_provider.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(_provider.profession, style: const TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    if (_provider.photoUrl.isNotEmpty) {
      return ImageUtils.getImageProvider(_provider.photoUrl) != null 
        ? Image(image: ImageUtils.getImageProvider(_provider.photoUrl)!, fit: BoxFit.cover)
        : const Icon(Icons.person, size: 50, color: Colors.white);
    }
    return const Icon(Icons.person, size: 50, color: Colors.white);
  }

  Widget _buildSelectionCard({required IconData icon, required String title, required String value, required VoidCallback onTap, required Color color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 14, color: kTextSecondary)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, _tr(context, 'rating'), _currentRating.toStringAsFixed(1), Icons.star),
          _buildStatItem(theme, _tr(context, 'services'), '${_providerServices.length}', Icons.work_outline),
          _buildStatItem(theme, _tr(context, 'booked'), '$_bookedCount', Icons.verified_user),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.primaryColor, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
        Text(label, style: TextStyle(fontSize: 12, color: theme.brightness == Brightness.dark ? Colors.white54 : kTextSecondary)),
      ],
    );
  }

  Widget _buildSectionCard({required ThemeData theme, required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'contact_information'),
      icon: Icons.contact_phone,
      child: Column(
        children: [
          _buildContactItem(theme, Icons.phone, _tr(context, 'phone'), _provider.phone, kSuccessColor, () => _makePhoneCall(_provider.phone)),
          const SizedBox(height: 12),
          _buildContactItem(theme, Icons.location_on, _tr(context, 'address'), _provider.address, kAccentColor, () => _openLocationInMaps(_provider.address)),
        ],
      ),
    );
  }

  Widget _buildContactItem(ThemeData theme, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
      onTap: onTap,
    );
  }

  Widget _buildRatingSection(ThemeData theme) {
    return _buildSectionCard(
      theme: theme,
      title: _tr(context, 'rate_provider'),
      icon: Icons.star,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(index < _currentRating.floor() ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                onPressed: () => setState(() => _currentRating = (index + 1).toDouble()),
              );
            }),
          ),
          ElevatedButton(
            onPressed: () => _submitRating(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(_tr(context, 'submit_rating')),
          ),
        ],
      ),
    );
  }

  void _startChat(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();
    final currentUser = authViewModel.currentUser;
    if (currentUser == null) {
      AppSnackBar.showError(context, _tr(context, 'sign_in_to_message'));
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatViewModel = ChatViewModel(userId: currentUser.uid);
      final chatId = await chatViewModel.createChat(
        clientId: currentUser.uid,
        providerId: _provider.uid!,
      );

      if (mounted) {
        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading

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
              ),
            ),
          );
        } else {
          AppSnackBar.showError(context, _tr(context, 'failed_to_start_chat'));
        }
      }
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading
        AppSnackBar.showError(context, 'Error: $e');
      }
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _openLocationInMaps(String address) async {
    final url = Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showSuccessDialog(DateTime appointmentDateTime) {
    showDialog(
      context: context,
      builder: (context) => ProfessionalSuccessDialog(
        title: _tr(context, 'booking_confirmed'),
        message: _trParams(context, 'appointment_scheduled', {'name': _provider.name}),
        onDone: () => Navigator.pop(context),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getProviderServices(String providerId) async {
    final snapshot = await FirebaseFirestore.instance.collection('services').where('providerId', isEqualTo: providerId).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
