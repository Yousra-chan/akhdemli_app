import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

import 'package:service_app/screens/profile/help_faq_page.dart';
import 'package:service_app/screens/profile/legal_page.dart';

// ─── Color helpers ───────────────────────────────────────────────────────────
// "App black" used as the primary accent throughout
const Color _kAccent     = Color(0xFF1A1A1A);
const Color _kAccentDark = Color(0xFFF5F5F5);

class _DC {
  static Color scaffold(bool d)  => d ? const Color(0xFF121212) : kLightBackgroundColor;
  static Color surface(bool d)   => d ? const Color(0xFF1E1E1E) : Colors.white;
  static Color headerBg(bool d)  => d ? const Color(0xFF181818) : Colors.white;
  static Color bodyText(bool d)  => d ? const Color(0xFFF0F0F0) : _kAccent;
  static Color mutedText(bool d) => d ? const Color(0xFFAAAAAA) : kMutedTextColor;
  static Color iconBg(bool d)    => d ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);
  static Color divider(bool d)   => d ? const Color(0xFF333333) : Colors.grey.shade200;
  static Color shadow(bool d)    => d ? Colors.black54 : Colors.black12;
  static Color tagBg(bool d)     => d ? const Color(0xFF252525) : const Color(0xFFF4F4F4);
  static Color statsBg(bool d)   => d ? const Color(0xFF1C1C1C) : const Color(0xFFF4F4F4);
  static Color accent(bool d)    => d ? _kAccentDark : _kAccent;
}
// ─────────────────────────────────────────────────────────────────────────────

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  // Tracks which expandable sections are open
  bool _introExpanded   = false;
  bool _missionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final lang    = Provider.of<LanguageProvider>(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _DC.scaffold(isDark),
      appBar: AppBar(
        title: Text(
          lang.tr('aboutUs', category: 'common'),
          style: TextStyle(
            color: _DC.bodyText(isDark),
            fontWeight: FontWeight.bold,
            fontFamily: 'Exo2',
          ),
        ),
        backgroundColor: _DC.headerBg(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero ──────────────────────────────────────────────────────────
            _buildHero(lang, isDark),



            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── About (expandable) ─────────────────────────────────────
                  _buildExpandableCard(
                    icon: CupertinoIcons.info_circle_fill,
                    title: lang.tr('about_title', category: 'about_us'),
                    body:  lang.tr('app_introduction', category: 'about_us'),
                    isExpanded: _introExpanded,
                    isDark: isDark,
                    onToggle: () =>
                        setState(() => _introExpanded = !_introExpanded),
                  ),
                  const SizedBox(height: 14),

                  // ── Mission (expandable) ───────────────────────────────────
                  _buildExpandableCard(
                    icon: CupertinoIcons.rocket_fill,
                    title: lang.tr('our_mission', category: 'about_us'),
                    body:  lang.tr('mission_description', category: 'about_us'),
                    isExpanded: _missionExpanded,
                    isDark: isDark,
                    onToggle: () =>
                        setState(() => _missionExpanded = !_missionExpanded),
                  ),
                  const SizedBox(height: 24),

                  // ── Key Features (grid chips) ──────────────────────────────
                  _buildSectionLabel(
                      lang.tr('key_features', category: 'about_us'), isDark),
                  const SizedBox(height: 12),
                  _buildFeaturesGrid(lang, isDark),
                  const SizedBox(height: 24),

                  // ── Support & Legal ────────────────────────────────────────
                  _buildSectionLabel(
                      lang.tr('support_legal', category: 'about_us'), isDark),
                  const SizedBox(height: 12),
                  _buildSupportLegalLinks(context, lang, isDark),
                  const SizedBox(height: 24),

                  // ── Contact ────────────────────────────────────────────────
                  _buildContactCard(lang),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Hero
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHero(LanguageProvider lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _DC.surface(isDark),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: _DC.shadow(isDark).withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo with decorative ring
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark ? kPrimaryBlue : _DC.accent(isDark)).withOpacity(0.18),
                    width: 3,
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252525) : _DC.iconBg(isDark),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            lang.tr('about_title', category: 'about_us'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : kPrimaryBlue,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────


  // ────────────────────────────────────────────────────────────────────────────
  // Expandable card (About / Mission)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildExpandableCard({
    required IconData icon,
    required String title,
    required String body,
    required bool isExpanded,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _DC.surface(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _DC.shadow(isDark).withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _DC.iconBg(isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: kPrimaryBlue, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _DC.bodyText(isDark),
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: kPrimaryBlue, size: 24),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible body
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: _DC.divider(isDark), height: 1),
                  const SizedBox(height: 14),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      color: _DC.mutedText(isDark),
                      height: 1.7,
                      fontFamily: 'Exo2',
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Features — 2-column grid of chips
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildFeaturesGrid(LanguageProvider lang, bool isDark) {
    final features = [
      {'icon': CupertinoIcons.search,       'key': 'feature_search'},
      {'icon': CupertinoIcons.calendar,     'key': 'feature_booking'},
      {'icon': CupertinoIcons.chat_bubble_2,'key': 'feature_chat'},
      {'icon': CupertinoIcons.star,         'key': 'feature_reviews'},
      {'icon': CupertinoIcons.person_2,     'key': 'feature_exchange'},
    ];

    // Build rows of 2
    final rows = <Widget>[];
    for (var i = 0; i < features.length; i += 2) {
      final left  = features[i];
      final right = i + 1 < features.length ? features[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _buildFeatureChip(left, lang, isDark)),
            const SizedBox(width: 10),
            right != null
                ? Expanded(child: _buildFeatureChip(right, lang, isDark))
                : const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < features.length) rows.add(const SizedBox(height: 10));
    }

    return Column(children: rows);
  }

  Widget _buildFeatureChip(
      Map<String, Object> feature, LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _DC.tagBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kPrimaryBlue.withOpacity(isDark ? 0.3 : 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _DC.iconBg(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(feature['icon'] as IconData,
                size: 18, color: kPrimaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lang.tr(feature['key'] as String, category: 'about_us'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _DC.bodyText(isDark),
                fontFamily: 'Exo2',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Support & Legal links
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSupportLegalLinks(
      BuildContext context, LanguageProvider lang, bool isDark) {
    final items = [
      {
        'icon': Icons.help_outline,
        'key': 'help_faq',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpFaqPage()),
        ),
      },
      {
        'icon': Icons.gavel_outlined,
        'key': 'terms_service',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const LegalPage(type: LegalType.terms)),
        ),
      },
      {
        'icon': Icons.privacy_tip_outlined,
        'key': 'privacy_policy',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const LegalPage(type: LegalType.privacy)),
        ),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: _DC.surface(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _DC.shadow(isDark).withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx  = entry.key;
          final item = entry.value;
          return Column(
            children: [
              ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _DC.iconBg(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData,
                      color: kPrimaryBlue, size: 20),
                ),
                title: Text(
                  lang.tr(item['key'] as String, category: 'about_us'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _DC.bodyText(isDark),
                    fontFamily: 'Exo2',
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right,
                      size: 18, color: kPrimaryBlue),
                ),
                onTap: item['onTap'] as VoidCallback,
              ),
              if (idx < items.length - 1)
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: _DC.divider(isDark),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Contact card
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildContactCard(LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E2A4A), const Color(0xFF16213E)]
              : [kPrimaryBlue, const Color(0xFF4A6FDC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : kPrimaryBlue.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.email_rounded,
                color: isDark ? const Color(0xFF8B9EFF) : Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('contact_us', category: 'about_us'),
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Exo2',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lang.tr('contact_email', category: 'about_us'),
                  style: TextStyle(
                    color: isDark ? const Color(0xFFAAAAAA) : Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              color: isDark ? Colors.white24 : Colors.white70, size: 16),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: kPrimaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _DC.bodyText(isDark),
            fontFamily: 'Exo2',
          ),
        ),
      ],
    );
  }
}