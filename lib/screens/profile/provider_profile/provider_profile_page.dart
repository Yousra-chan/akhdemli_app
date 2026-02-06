import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/home/notifications_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/models/BookingModel.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/services/chat_service.dart';
import 'package:service_app/services/booking_service.dart';

const kPrimaryBlue = Color(0xFF007BFF);
const kDarkTextColor = Color(0xFF1A1A1A);
const kMutedTextColor = Color(0xFF666666);
const kLightBackgroundColor = Color(0xFFF8F9FA);
const kCardBackground = Color(0xFFFFFFFF);
const kGradientStart = Color(0xFF667EEA);
const kGradientEnd = Color(0xFF764BA2);
const kSuccessGreen = Color(0xFF28A745);
const kWarningYellow = Color(0xFFFFC107);
const kErrorRed = Color(0xFFDC3545);

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

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _currentRating = _provider.rating;
    _checkIfUserHasRated();
    _loadProviderServices();
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
      // Error checking rating, continue anyway
    }
  }

  Future<void> _submitRating(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    if (authViewModel.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to rate this provider'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_provider.uid == null || _provider.uid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provider information is incomplete'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = authViewModel.currentUser!;
      final ratingId = '${currentUser.uid}_${_provider.uid!}';

      // Save user's rating
      await FirebaseFirestore.instance.collection('ratings').doc(ratingId).set({
        'userId': currentUser.uid,
        'providerId': _provider.uid!,
        'rating': _currentRating,
        'createdAt': FieldValue.serverTimestamp(),
        'userName': currentUser.name,
        'userPhoto': currentUser.photoUrl,
      });

      // Get all ratings for this provider
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

      // Update provider rating
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_provider.uid!)
          .update({
        'rating': newAverageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        _hasRated = true;
        _provider = _provider.copyWith(rating: newAverageRating);
        _currentRating = newAverageRating;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Thank you! You rated ${_provider.name} with $_currentRating stars'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // =================== BOOKING FUNCTIONALITY ===================

  Future<void> _bookService() async {
    final authViewModel = context.read<AuthViewModel>();
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to book a service'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Combine date and time
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Check if appointment is in the future
      if (appointmentDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a future date and time'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create booking
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
        // Send notification to provider
        await BookingNotificationService.createNewBookingNotification(
          providerId: _provider.uid!,
          clientName: currentUser.name,
          serviceTitle: _selectedService!['title'],
          clientId: currentUser.uid,
          bookingId: booking.id,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking request sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Reset form
        setState(() {
          _selectedService = null;
          _selectedDate = null;
          _selectedTime = null;
          _notes = '';
          _showBookingForm = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create booking. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  // =================== MAIN BUILD METHOD ===================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Collapsing Header
              SliverAppBar(
                backgroundColor: kPrimaryBlue,
                expandedHeight: 320.0,
                pinned: true,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert, size: 22),
                      color: Colors.white,
                      onPressed: () => _showMoreOptions(context),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeaderBackground(context),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      _provider.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Enhanced Profile Info Card with ALL provider information
                    _buildEnhancedProfileCard(),

                    // Rating Section
                    _buildRatingSection(),

                    // Services Section with Booking Option
                    _buildServicesSection(),

                    // Booking Form (if a service is selected)
                    if (_showBookingForm) _buildBookingForm(),

                    // Stats Section
                    _buildStatsSection(),

                    // About Section
                    if (_provider.description.isNotEmpty)
                      _buildSectionCard(
                        title: 'About',
                        child: Text(
                          _provider.description,
                          style: const TextStyle(
                            fontSize: 15,
                            color: kMutedTextColor,
                            height: 1.6,
                          ),
                        ),
                      ),

                    // Contact Section
                    _buildContactSection(),

                    // Bottom spacing
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // Fixed Bottom CTA Buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startChat(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Message',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: ElevatedButton(
                      onPressed: () => _makePhoneCall(_provider.phone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.call, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================== ENHANCED PROFILE CARD ===================

  Widget _buildEnhancedProfileCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with verification badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Professional Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor,
                ),
              ),
              if (_provider.subscriptionActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Basic Information Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoChip(
                Icons.person,
                'Profession',
                _provider.profession.isNotEmpty
                    ? _provider.profession
                    : 'Service Provider',
              ),
              _buildInfoChip(
                Icons.location_city,
                'Wilaya',
                _provider.wilaya,
              ),
              _buildInfoChip(
                Icons.location_on,
                'Commune',
                _provider.commune,
              ),
              _buildInfoChip(
                Icons.star,
                'Rating',
                '${_currentRating.toStringAsFixed(1)} ⭐',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Detailed Information
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kPrimaryBlue),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimaryBlue,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: kDarkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kDarkTextColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: kMutedTextColor,
          ),
        ),
      ],
    );
  }

  // =================== SERVICES SECTION WITH BOOKING ===================

  Widget _buildServicesSection() {
    return _buildSectionCard(
      title: 'Services Offered',
      child: _loadingServices
          ? const Center(child: CircularProgressIndicator())
          : _providerServices.isEmpty
              ? const Center(
                  child: Text(
                    'No services listed yet',
                    style: TextStyle(color: kMutedTextColor),
                  ),
                )
              : Column(
                  children: _providerServices.map((service) {
                    final isSelected = _selectedService?['id'] == service['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimaryBlue.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected ? kPrimaryBlue : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _selectedService = service;
                            _showBookingForm = true;
                          });
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kPrimaryBlue
                                : kPrimaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.build_circle_outlined,
                            color: isSelected ? Colors.white : kPrimaryBlue,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          service['title'] ?? 'Service',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? kPrimaryBlue : kDarkTextColor,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              service['description'] ?? '',
                              style: TextStyle(
                                color: isSelected
                                    ? kPrimaryBlue.withOpacity(0.8)
                                    : kMutedTextColor,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? kPrimaryBlue.withOpacity(0.2)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    service['category'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? kPrimaryBlue
                                          : kMutedTextColor,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${service['price'] ?? '0'} DZD',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? kPrimaryBlue
                                        : kPrimaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: kPrimaryBlue, size: 24)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  // =================== BOOKING FORM ===================

  Widget _buildBookingForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book Service',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _showBookingForm = false;
                    _selectedService = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected Service Info
          if (_selectedService != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimaryBlue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: kPrimaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedService!['title'] ?? 'Service',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedService!['price'] ?? '0'} DZD',
                          style: TextStyle(
                            fontSize: 14,
                            color: kPrimaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Date Selection
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: kPrimaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 14,
                            color: kMutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDate != null
                              ? DateFormat('EEEE, MMMM d, yyyy')
                                  .format(_selectedDate!)
                              : 'Tap to select date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: kDarkTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time Selection
          InkWell(
            onTap: () => _selectTime(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: kPrimaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Time',
                          style: TextStyle(
                            fontSize: 14,
                            color: kMutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Tap to select time',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: kDarkTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            onChanged: (value) {
              setState(() {
                _notes = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Additional Notes (Optional)',
              labelStyle: TextStyle(color: kMutedTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kPrimaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Book Now Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bookService,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================== REST OF THE METHODS ===================

  Widget _buildHeaderBackground(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kGradientStart, kGradientEnd],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildProfileImage(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _provider.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _provider.profession.isNotEmpty
                      ? _provider.profession
                      : 'Service Provider',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    final String? imageUrl = _provider.photoUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(color: kPrimaryBlue),
          );
        },
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rate This Provider',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor,
                ),
              ),
              if (_hasRated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Rated',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      if (!_hasRated && !_isSubmitting) {
                        setState(() {
                          _currentRating = (index + 1).toDouble();
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        index < _currentRating.floor()
                            ? Icons.star
                            : Icons.star_border,
                        color: _hasRated
                            ? Colors.amber.withOpacity(0.5)
                            : Colors.amber,
                        size: 48,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                _currentRating == 0
                    ? 'Tap to rate'
                    : '${_currentRating.toStringAsFixed(1)} Stars',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kDarkTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getRatingDescription(_currentRating),
                style: TextStyle(
                  fontSize: 14,
                  color: kMutedTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              if (!_hasRated)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || _currentRating == 0
                        ? null
                        : () => _submitRating(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Submit Rating',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _viewAllRatings(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryBlue,
                    side: BorderSide(color: kPrimaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.reviews, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'View All Reviews',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRatingDescription(double rating) {
    if (rating == 0) return 'Be the first to rate this provider!';
    if (rating < 2) return 'Poor';
    if (rating < 3) return 'Fair';
    if (rating < 4) return 'Good';
    if (rating < 4.5) return 'Very Good';
    return 'Excellent';
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              'Rating', '${_currentRating.toStringAsFixed(1)}', Icons.star),
          _buildStatItem('Services', '${_providerServices.length}', Icons.work),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                kGradientStart.withOpacity(0.1),
                kGradientEnd.withOpacity(0.1)
              ],
            ),
          ),
          child: Icon(icon, color: kPrimaryBlue, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kDarkTextColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: kMutedTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kDarkTextColor,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _buildSectionCard(
        title: 'Contact Information',
        child: Column(
          children: [
            _buildContactItem(
              Icons.phone,
              'Phone',
              _provider.phone,
              Colors.green,
              () => _makePhoneCall(_provider.phone),
            ),
            const SizedBox(height: 12),
            if (_provider.whatsapp.isNotEmpty)
              _buildContactItem(
                Icons.chat,
                'WhatsApp',
                _provider.whatsapp,
                const Color(0xFF25D366),
                () => _openWhatsApp(_provider.whatsapp),
              ),
            if (_provider.whatsapp.isNotEmpty) const SizedBox(height: 12),
            _buildContactItem(
              Icons.location_on,
              'Address',
              _provider.address,
              kPrimaryBlue,
              () => _openLocationInMaps(_provider.address),
            ),
          ],
        ));
  }

  void _sendEmail(String email) async {
    final url = Uri.parse('mailto:$email');
    if (await launchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildContactItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.share, color: kPrimaryBlue),
                title: const Text('Share Profile'),
                onTap: () {
                  Navigator.pop(context);
                  _shareProfile(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.bookmark, color: kPrimaryBlue),
                title: const Text('Save to Favorites'),
                onTap: () {
                  Navigator.pop(context);
                  _saveToFavorites(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.report, color: Colors.red),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.grey),
                title: const Text('Block'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveToFavorites(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to favorites'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startChat(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatService = ChatService();

    if (authViewModel.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start a chat')),
      );
      return;
    }

    try {
      final chatId = await chatService.createChat(
        clientId: authViewModel.currentUser!.uid,
        providerId: _provider.uid!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat started. Chat ID: $chatId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: ${e.toString()}')),
      );
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:${_cleanPhoneNumber(phoneNumber)}');
    if (await launchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openWhatsApp(String whatsappNumber) async {
    final cleanNumber = _cleanPhoneNumber(whatsappNumber);
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await launchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openLocationInMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse('https://maps.google.com/?q=$encodedAddress');
    if (await launchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _shareProfile(BuildContext context) {
    final text = 'Check out ${_provider.name}\'s profile on Service App!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share: $text')),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text('Please describe the issue you encountered.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted successfully')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${_provider.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_provider.name} has been blocked')),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<List<Map<String, dynamic>>> _getProviderServices(
      String providerId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _viewAllRatings(BuildContext context) async {
    if (_provider.uid == null || _provider.uid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot view ratings: Provider ID is missing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Reviews',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDarkTextColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ratings')
                      .where('providerId', isEqualTo: _provider.uid!)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 60, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading reviews',
                              style: TextStyle(
                                fontSize: 16,
                                color: kDarkTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.reviews,
                                size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: kMutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final ratings = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: ratings.length,
                      itemBuilder: (context, index) {
                        final rating = ratings[index];
                        final data = rating.data() as Map<String, dynamic>;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: data['userPhoto'] != null &&
                                        data['userPhoto'].isNotEmpty
                                    ? NetworkImage(data['userPhoto'])
                                    : null,
                                backgroundColor: kPrimaryBlue.withOpacity(0.1),
                                child: data['userPhoto'] == null ||
                                        data['userPhoto'].isEmpty
                                    ? Icon(Icons.person, color: kPrimaryBlue)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['userName'] ?? 'Anonymous',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children:
                                              List.generate(5, (starIndex) {
                                            final ratingValue =
                                                (data['rating'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;
                                            return Icon(
                                              starIndex < ratingValue.floor()
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    if (data['createdAt'] != null)
                                      Text(
                                        _formatDate(
                                            (data['createdAt'] as Timestamp)
                                                .toDate()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: kMutedTextColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
