import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/ProviderModel.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/utils/image_utils.dart';
import 'package:service_app/screens/profile/provider_profile/provider_profile_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProviderCard extends StatefulWidget {
  final ProviderModel provider;
  final Function(ProviderModel) onMessageTap;
  final Function(ProviderModel) onCallTap;
  final Function(ProviderModel)? onWhatsAppTap;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.onMessageTap,
    required this.onCallTap,
    this.onWhatsAppTap,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
              blurRadius: _isHovered ? 25 : 15,
              offset: Offset(0, _isHovered ? 12 : 8),
            ),
          ],
          border: Border.all(
            color: _isHovered ? theme.primaryColor.withOpacity(0.3) : theme.dividerColor.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Info & Avatar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar with subtle glow
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2), width: 2),
                      ),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        clipBehavior: Clip.antiAlias,
                        child: _buildAvatar(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.provider.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: theme.textTheme.titleLarge?.color,
                                    fontFamily: 'Exo2',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.provider.subscriptionActive)
                                const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildRatingBadge(widget.provider.rating),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on_rounded, size: 14, color: theme.primaryColor.withOpacity(0.7)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.provider.getLocalizedLocation(lang),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                    fontFamily: 'Exo2',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Category Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.provider.profession.toUpperCase(),
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom Section: Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Chat Action
                    Expanded(
                      flex: 3,
                      child: _ActionButton(
                        label: lang.tr('chat_now', category: 'providers_list_page'),
                        icon: CupertinoIcons.chat_bubble_2_fill,
                        color: theme.primaryColor,
                        onTap: () => widget.onMessageTap(widget.provider),
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // WhatsApp
                    if (widget.onWhatsAppTap != null)
                      _CircleAction(
                        icon: FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366),
                        onTap: () => widget.onWhatsAppTap!(widget.provider),
                      ),
                    const SizedBox(width: 12),
                    // Call
                    _CircleAction(
                      icon: Icons.phone_rounded,
                      color: const Color(0xFF3B82F6),
                      onTap: () => widget.onCallTap(widget.provider),
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

  Widget _buildAvatar() {
    final photo = widget.provider.photoUrl;
    if (photo.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Icon(Icons.person_rounded, color: Colors.grey, size: 32),
      );
    }
    
    final imageProvider = ImageUtils.getImageProvider(photo);
    if (imageProvider != null) {
      return Image(image: imageProvider, fit: BoxFit.cover);
    }

    return CachedNetworkImage(
      imageUrl: photo,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const Icon(Icons.person_rounded),
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Exo2'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isPrimary ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isPrimary ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.white : color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Exo2',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
