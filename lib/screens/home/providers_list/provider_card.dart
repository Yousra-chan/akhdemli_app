import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/auth/constants.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:shimmer/shimmer.dart';

class ProviderCard extends StatefulWidget {
  final ProviderModel provider;
  final Function(ProviderModel) onMessageTap;
  final Function(ProviderModel) onCallTap;
  final Function(ProviderModel)? onChatTap;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.onMessageTap,
    required this.onCallTap,
    this.onChatTap,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );

    // Debug
    print('🟡 [ProviderCard] Created for: ${widget.provider.name}');
    print(
        '🟡 [ProviderCard] Photo URL length: ${widget.provider.photoUrl.length}');

    // Check if it's Base64
    if (widget.provider.photoUrl.isNotEmpty) {
      if (_isBase64(widget.provider.photoUrl)) {
        print('✅ [ProviderCard] Photo appears to be Base64 encoded');
      } else if (widget.provider.photoUrl.startsWith('http')) {
        print('✅ [ProviderCard] Photo appears to be a network URL');
      } else {
        print('⚠️ [ProviderCard] Photo format unknown');
      }
    }
  }

  bool _isBase64(String str) {
    // Check if string looks like Base64
    if (str.isEmpty) return false;

    // Base64 typically contains alphanumeric chars and +, /, =
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

    // Also check for data URL format: data:image/...;base64,...
    if (str.startsWith('data:image') && str.contains('base64,')) {
      return true;
    }

    // Check if it's pure Base64
    try {
      // Remove potential data URL prefix
      String testStr = str;
      if (str.contains('base64,')) {
        testStr = str.split('base64,').last;
      }

      // Try to decode it
      base64.decode(testStr);
      return true;
    } catch (e) {
      return false;
    }
  }

  ImageProvider? _getImageProvider(String photoUrl) {
    if (photoUrl.isEmpty) return null;

    try {
      if (_isBase64(photoUrl)) {
        print('🟢 Creating MemoryImage from Base64');
        Uint8List bytes;

        if (photoUrl.startsWith('data:image') && photoUrl.contains('base64,')) {
          // Handle data URL format: data:image/png;base64,...
          final base64Data = photoUrl.split('base64,').last;
          bytes = base64.decode(base64Data);
        } else {
          // Handle plain Base64
          bytes = base64.decode(photoUrl);
        }

        return MemoryImage(bytes);
      } else if (photoUrl.startsWith('http')) {
        print('🟢 Creating NetworkImage from URL');
        return NetworkImage(photoUrl);
      }
    } catch (e) {
      print('❌ Error creating image provider: $e');
    }

    return null;
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    _hoverController.forward();
  }

  void _onHoverExit() {
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -4 * _hoverAnimation.value),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.08 + 0.04 * _hoverAnimation.value),
                    blurRadius: 20 + 12 * _hoverAnimation.value,
                    offset: Offset(0, 6 + 4 * _hoverAnimation.value),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Gradient Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade100,
                            Colors.orange.shade200,
                            Colors.pink.shade200,
                          ],
                        ),
                      ),
                    ),

                    // Main Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar and Info Section
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar with profile picture
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _buildProviderImage(),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name, Role and Badges
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Name
                                    Text(
                                      widget.provider.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                        fontFamily: 'Exo2',
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // Role and Status Badges
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        // Profession Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            widget.provider.profession,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.purple.shade700,
                                              fontFamily: 'Exo2',
                                            ),
                                          ),
                                        ),

                                        // Verified Badge
                                        if (widget.provider.subscriptionActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.star_rounded,
                                                  size: 11,
                                                  color: Colors.amber.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  languageProvider.tr(
                                                      'golden_user',
                                                      category:
                                                          'providers_list_page'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.amber.shade700,
                                                    fontFamily: 'Exo2',
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

                        // Description Section
                        if (widget.provider.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Text(
                              widget.provider.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontFamily: 'Exo2',
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Rating and Location
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: Colors.amber.shade600,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.provider.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  fontFamily: 'Exo2',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.location_on_rounded,
                                size: 15,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _getLocationText(languageProvider),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade600,
                                    fontFamily: 'Exo2',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Action Buttons Section
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Chat Button (Expanded)
                              Expanded(
                                child: _buildChatButton(languageProvider),
                              ),
                              const SizedBox(width: 12),

                              // Call Button (Circle)
                              _buildCallButton(languageProvider),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProviderImage() {
    if (widget.provider.photoUrl.isNotEmpty) {
      final imageProvider = _getImageProvider(widget.provider.photoUrl);

      if (imageProvider != null) {
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kPrimaryBlue,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error displaying image: $error');
            return _buildFallbackAvatar();
          },
        );
      }
    }

    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade100,
            Colors.purple.shade100,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildChatButton(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.onChatTap != null) {
              widget.onChatTap!(widget.provider);
            } else {
              widget.onMessageTap(widget.provider);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade600,
                  Colors.purple.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  lang.tr('chat_now', category: 'providers_list_page'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Exo2',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(LanguageProvider lang) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onCallTap(widget.provider),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade500,
                  Colors.green.shade600,
                ],
              ),
            ),
            child: Icon(
              Icons.phone_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _getLocationText(LanguageProvider lang) {
    final wilaya = widget.provider.wilaya;
    final commune = widget.provider.commune;
    final address = widget.provider.address;

    if (wilaya.isNotEmpty && commune.isNotEmpty) {
      return '$commune, $wilaya';
    }

    if (address.isNotEmpty) {
      return address;
    }

    return lang.tr('location_not_specified', category: 'providers_list_page');
  }
}

class ProviderSkeleton extends StatelessWidget {
  const ProviderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 16, color: Colors.white),
                      const SizedBox(height: 10),
                      Container(width: 80, height: 12, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(width: double.infinity, height: 12, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: 200, height: 12, color: Colors.white),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
