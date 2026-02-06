import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/ViewModel/chat_view_model.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_page.dart';

const kPrimaryBlue = Color(0xFF007BFF);
const kDarkTextColor = Color(0xFF1A1A1A);
const kMutedTextColor = Color(0xFF666666);
const kLightBackgroundColor = Color(0xFFF8F9FA);
const kCardBackground = Color(0xFFFFFFFF);
const kGradientStart = Color(0xFF667EEA);
const kGradientEnd = Color(0xFF764BA2);

class ProviderProfileScreen extends StatefulWidget {
  final ProviderModel provider;

  const ProviderProfileScreen({super.key, required this.provider});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late double _currentRating;
  bool _hasRated = false;
  bool _isSubmitting = false;
  late ProviderModel _provider; // Local mutable copy

  @override
  void initState() {
    super.initState();
    _provider = widget.provider; // Create local mutable copy
    _currentRating = _provider.rating;
    _checkIfUserHasRated();
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

    // Check if provider UID is available
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

      print(
          '⭐ Submitting rating: $_currentRating for provider: ${_provider.uid!}');

      // Save user's rating
      await FirebaseFirestore.instance.collection('ratings').doc(ratingId).set({
        'userId': currentUser.uid,
        'providerId': _provider.uid!,
        'rating': _currentRating,
        'createdAt': FieldValue.serverTimestamp(),
        'userName': currentUser.name,
        'userPhoto': currentUser.photoUrl,
      });

      print('✅ Rating saved to ratings collection');

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

      // Calculate new average rating
      final newAverageRating =
          ratingCount > 0 ? totalRating / ratingCount : 0.0;

      print(
          '📊 Updating provider rating: $newAverageRating (from $ratingCount ratings)');

      // Only update the users collection since providers are stored there
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_provider.uid!)
          .update({
        'rating': newAverageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User document updated successfully');

      // Update local state using the copyWith method
      setState(() {
        _hasRated = true;
        _provider = _provider.copyWith(rating: newAverageRating);
        _currentRating = newAverageRating;
      });

      // Show success message with the user's actual rating, not the average
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Thank you! You rated ${_provider.name} with $_currentRating stars'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');

      if (e.code == 'not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider profile not found in database'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ General error: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kPrimaryBlue.withOpacity(0.8),
                      kPrimaryBlue.withOpacity(0.2),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 50),
                      _buildProfileImage(),
                      SizedBox(height: 16),
                      Text(
                        _provider.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Exo2',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _provider.profession,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share, color: Colors.white),
                ),
                onPressed: () => _shareProfile(context),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating Section
                    _buildRatingSection(),

                    SizedBox(height: 20),

                    // Stats Section
                    Container(
                      margin: EdgeInsets.only(bottom: 24),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                _currentRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade900,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              Text(
                                'Rating',
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.amber.shade300,
                          ),
                          Column(
                            children: [
                              Text(
                                '${_provider.serviceIds.length}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: kPrimaryBlue,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              Text(
                                'Services',
                                style: TextStyle(
                                  color: kPrimaryBlue,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.amber.shade300,
                          ),
                          Column(
                            children: [
                              Text(
                                '${_provider.serviceImages.length}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade700,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              Text(
                                'Photos',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Location Info
                    Container(
                      margin: EdgeInsets.only(bottom: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: kPrimaryBlue, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kMutedTextColor,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_provider.commune}, ${_provider.wilaya}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: kDarkTextColor,
                                    fontFamily: 'Exo2',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_provider.subscriptionActive)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade600,
                                    Colors.green.shade400,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
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

                    if (_provider.serviceImages.isNotEmpty)
                      _buildSection(
                        title: 'Service Photos',
                        icon: Icons.photo_library_rounded,
                        child: _buildServicePhotos(_provider),
                      ),
                    if (_provider.serviceImages.isNotEmpty)
                      SizedBox(height: 24),

                    _buildSection(
                      title: 'About',
                      icon: Icons.info_rounded,
                      child: Text(
                        _provider.description.isNotEmpty
                            ? _provider.description
                            : 'No description provided.',
                        style: TextStyle(
                          color: kMutedTextColor,
                          fontFamily: 'Exo2',
                          height: 1.6,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Services Section
                    _buildServicesSection(),

                    SizedBox(height: 24),

                    _buildSection(
                      title: 'Contact Information',
                      icon: Icons.contact_phone_rounded,
                      child: _buildContactInfo(_provider, context),
                    ),

                    SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _openChat(context, _provider);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(Icons.message_rounded),
                            label: Text(
                              'Message',
                              style: TextStyle(
                                fontFamily: 'Exo2',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final url = Uri.parse('tel:${_provider.phone}');
                              launchUrl(url);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(Icons.phone_rounded),
                            label: Text(
                              'Call',
                              style: TextStyle(
                                fontFamily: 'Exo2',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              String phoneNumber = _provider.whatsapp.isNotEmpty
                                  ? _provider.whatsapp
                                  : _provider.phone;
                              final cleanedPhone =
                                  phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
                              final url =
                                  Uri.parse('https://wa.me/$cleanedPhone');
                              launchUrl(url);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(CupertinoIcons.phone),
                            label: Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontFamily: 'Exo2',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final String? imageUrl = _provider.photoUrl;

    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _showImageDialog(
            context,
            imageUrl,
            "Profile Photo",
          );
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
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
                )
              : _buildFallbackImage(),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
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
                  fontFamily: 'Exo2',
                ),
              ),
              if (_hasRated)
                Container(
                  padding: EdgeInsets.symmetric(
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
                      Icon(Icons.check, size: 14, color: Colors.green),
                      SizedBox(width: 4),
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
          SizedBox(height: 16),

          // Interactive Star Rating
          Column(
            children: [
              // Large Stars for Rating
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
                      padding: EdgeInsets.symmetric(horizontal: 6),
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
              SizedBox(height: 12),

              // Rating Text
              Text(
                _currentRating == 0
                    ? 'Tap to rate'
                    : '${_currentRating.toStringAsFixed(1)} Stars',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kDarkTextColor,
                  fontFamily: 'Exo2',
                ),
              ),
              SizedBox(height: 4),

              // Rating Description
              Text(
                _getRatingDescription(_currentRating),
                style: TextStyle(
                  fontSize: 14,
                  color: kMutedTextColor,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Exo2',
                ),
              ),
              SizedBox(height: 20),

              // Submit Rating Button
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
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
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
                              SizedBox(width: 8),
                              Text(
                                'Submit Rating',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

              // View Ratings Button
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _viewAllRatings(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryBlue,
                    side: BorderSide(color: kPrimaryBlue),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.reviews, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'View All Reviews',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          fontFamily: 'Exo2',
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

  Future<void> _viewAllRatings(BuildContext context) async {
    if (_provider.uid == null || _provider.uid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot view ratings: Provider ID is missing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
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
                      fontFamily: 'Exo2',
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ratings')
                      .where('providerId', isEqualTo: _provider.uid!)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 60, color: Colors.red[300]),
                            SizedBox(height: 16),
                            Text(
                              'Error loading reviews',
                              style: TextStyle(
                                fontSize: 16,
                                color: kDarkTextColor,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
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
                            SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: kMutedTextColor,
                                fontFamily: 'Exo2',
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to rate this provider!',
                              style: TextStyle(
                                fontSize: 14,
                                color: kMutedTextColor,
                                fontFamily: 'Exo2',
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
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Avatar
                              CircleAvatar(
                                radius: 24,
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
                              SizedBox(width: 12),
                              // Rating Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['userName'] ?? 'Anonymous',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              fontFamily: 'Exo2',
                                            ),
                                          ),
                                        ),
                                        // Stars
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
                                        SizedBox(width: 4),
                                        Text(
                                          ((data['rating'] as num?)
                                                  ?.toStringAsFixed(1) ??
                                              '0.0'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: kDarkTextColor,
                                            fontFamily: 'Exo2',
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Rating Date
                                    if (data['createdAt'] != null)
                                      Text(
                                        _formatDate(
                                            (data['createdAt'] as Timestamp)
                                                .toDate()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: kMutedTextColor,
                                          fontFamily: 'Exo2',
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

  Widget _buildServicesSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getProviderServices(_provider.uid ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final services = snapshot.data ?? [];

        if (services.isEmpty) {
          return SizedBox.shrink(); // Don't show section if no services
        }

        return _buildSection(
          title: 'Services Offered',
          icon: Icons.work_rounded,
          child: Column(
            children:
                services.map((service) => _buildServiceItem(service)).toList(),
          ),
        );
      },
    );
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

  Widget _buildServiceItem(Map<String, dynamic> service) {
    final String price = '${service['price'] ?? '0'} DZD';
    final String title = service['title'] ?? 'Service';
    final String description = service['description'] ?? '';
    final String category = service['category'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.build_circle_outlined,
                color: kPrimaryBlue, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Exo2',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                      color: kMutedTextColor, fontSize: 14, fontFamily: 'Exo2'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          color: kMutedTextColor,
                          fontFamily: 'Exo2',
                        ),
                      ),
                    ),
                    Spacer(),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryBlue,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicePhotos(ProviderModel provider) {
    List<String> images = provider.serviceImages;

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _showImageDialog(
              context,
              images[index],
              "Service Photo ${index + 1}",
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.photo,
                      color: Colors.grey.shade400,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Exo2',
                      ),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.white, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Exo2',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      imageUrl,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await launchUrl(Uri.parse(imageUrl));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to open URL'),
                          ),
                        );
                      }
                    },
                    child: Icon(
                      Icons.open_in_new,
                      color: Colors.white,
                      size: 18,
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

  // Method to open chat
  void _openChat(BuildContext context, ProviderModel provider) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showLoginDialog(context);
        return;
      }

      final currentUserId = currentUser.uid;
      final providerId = provider.uid!;
      final providerName = provider.name;
      final providerPhotoUrl = provider.photoUrl;

      if (currentUserId == providerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You cannot chat with yourself'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final chatViewModel = ChatViewModel(userId: currentUserId);
      final canonicalChatId = getCanonicalChatId(currentUserId, providerId);
      final existingChat = await chatViewModel.getChatById(canonicalChatId);

      String chatId;

      if (existingChat != null) {
        chatId = canonicalChatId;
      } else {
        final newChatId = await chatViewModel.createChat(
          clientId: currentUserId,
          providerId: providerId,
        );

        if (newChatId == null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create chat'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        chatId = newChatId;
      }

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiscussionPage(
            contactName: providerName,
            isOnline: true,
            chatId: chatId,
            currentUserId: currentUserId,
            chatViewModel: chatViewModel,
            profileImageUrl: providerPhotoUrl,
            contactUserId: providerId,
          ),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error opening chat: $e');
    }
  }

  String getCanonicalChatId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login Required', style: TextStyle(fontFamily: 'Exo2')),
        content: Text('You need to login to send messages.',
            style: TextStyle(fontFamily: 'Exo2')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontFamily: 'Exo2')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
            },
            child: Text('Login', style: TextStyle(fontFamily: 'Exo2')),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: kPrimaryBlue, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kDarkTextColor,
                fontFamily: 'Exo2',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildContactInfo(ProviderModel provider, BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (provider.phone.isNotEmpty)
            _buildContactItem(
              icon: Icons.phone_rounded,
              iconColor: kPrimaryBlue,
              title: 'Phone',
              value: provider.phone,
              onTap: () {
                final url = Uri.parse('tel:${provider.phone}');
                launchUrl(url);
              },
            ),
          if (provider.whatsapp.isNotEmpty)
            _buildContactItem(
              icon: Icons.phone,
              iconColor: Colors.green,
              title: 'WhatsApp',
              value: provider.whatsapp,
              onTap: () {
                final cleanedPhone =
                    provider.whatsapp.replaceAll(RegExp(r'[^\d+]'), '');
                final url = Uri.parse('https://wa.me/$cleanedPhone');
                launchUrl(url);
              },
            ),
          _buildContactItem(
            icon: Icons.location_on_rounded,
            iconColor: Colors.orange,
            title: 'Address',
            value: provider.address,
            onTap: () {
              // Could open maps here
            },
          ),
          if (provider.photoUrl.isNotEmpty)
            _buildContactItem(
              icon: Icons.person_rounded,
              iconColor: Colors.purple,
              title: 'Profile Photo',
              value: provider.photoUrl,
              onTap: () {
                _showImageDialog(
                  context,
                  provider.photoUrl,
                  "Profile Photo",
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: kMutedTextColor,
                      fontFamily: 'Exo2',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kDarkTextColor,
                      fontFamily: 'Exo2',
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  void _shareProfile(BuildContext context) {
    final text = 'Check out ${_provider.name}\'s profile!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Simulated Share: $text',
            style: TextStyle(fontFamily: 'Exo2')),
        backgroundColor: kPrimaryBlue,
      ),
    );
  }
}
