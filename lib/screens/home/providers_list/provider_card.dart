import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';

class ProviderCard extends StatefulWidget {
  final ProviderModel provider;
  final Function(ProviderModel) onMessageTap;
  final Function(ProviderModel) onCallTap;
  final Function(ProviderModel)? onChatTap;
  final Function(ProviderModel)? onWhatsAppTap;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.onMessageTap,
    required this.onCallTap,
    this.onChatTap,
    this.onWhatsAppTap,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit:  (_) => _onHoverExit(),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -4 * _hoverAnimation.value),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProviderProfileScreen(
                      provider: widget.provider,
                      serviceCategory: widget.provider.profession,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(isDark ? 0.2 : 0.08 + 0.04 * _hoverAnimation.value),
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
                            colors: isDark
                                ? [
                                    theme.cardColor,
                                    theme.cardColor.withOpacity(0.8),
                                    theme.cardColor.withOpacity(0.6),
                                  ]
                                : [
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar with profile picture
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _buildProviderImage(),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Name and Rating/Location
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Name
                                      Text(
                                        widget.provider.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: theme.textTheme.titleLarge?.color,
                                          fontFamily: 'Exo2',
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      
                                      // Rating and Location compact
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: Colors.amber.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.provider.rating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: theme.textTheme.bodyLarge?.color,
                                              fontFamily: 'Exo2',
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 14,
                                            color: Colors.blue.shade600,
                                          ),
                                          const SizedBox(width: 4),
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Row(
                              children: [
                                // Chat Button (Expanded)
                                Expanded(
                                  child: _buildChatButton(languageProvider),
                                ),
                                const SizedBox(width: 12),

                                // WhatsApp Button
                                _buildWhatsAppButton(),
                                const SizedBox(width: 12),

                                // Call Button
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildProviderImage() {
    final imageProvider = ImageUtils.getImageProvider(widget.provider.photoUrl);
    if (imageProvider != null) {
      return Image(
        image: imageProvider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
      );
    }
    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: Colors.blue.shade100,
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildWhatsAppButton() {
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
          onTap: () {
            if (widget.onWhatsAppTap != null) {
              widget.onWhatsAppTap!(widget.provider);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF25D366),
                  Color(0xFF128C7E),
                ],
              ),
            ),
            child: const Icon(
              FontAwesomeIcons.whatsapp,
              size: 20,
              color: Colors.white,
            ),
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 16, color: isDark ? Colors.white10 : Colors.white),
                      const SizedBox(height: 10),
                      Container(width: 80, height: 12, color: isDark ? Colors.white10 : Colors.white),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
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
