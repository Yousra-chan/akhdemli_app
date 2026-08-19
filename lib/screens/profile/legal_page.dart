import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

enum LegalType { privacy, terms }

class LegalPage extends StatelessWidget {
  final LegalType type;

  const LegalPage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldColor =
    isDark ? const Color(0xFF0F0F1A) : kLightBackgroundColor;
    final appBarColor = isDark ? const Color(0xFF16213E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFE0E0E0) : kDarkTextColor;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final sectionTitleColor = isDark ? const Color(0xFF8B9EFF) : kPrimaryBlue;
    final bodyTextColor = isDark ? const Color(0xFFCCCCCC) : kDarkTextColor;
    final dividerColor = isDark ? const Color(0xFF2A2A40) : Colors.grey.shade300;
    final shadowColor =
    isDark ? Colors.black54 : Colors.black.withOpacity(0.05);

    final title = type == LegalType.privacy
        ? lang.tr('privacy_policy', category: 'about_us')
        : lang.tr('terms_service', category: 'about_us');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Exo2',
          ),
        ),
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                lang.tr('legal_last_updated', category: 'about_us'),
                '${lang.tr('february', category: 'common')} 2025',
                sectionTitleColor,
                bodyTextColor,
              ),
              SizedBox(height: 20),
              _buildSection(
                type == LegalType.privacy
                    ? lang.tr('privacy_section1_title', category: 'about_us')
                    : lang.tr('terms_section1_title', category: 'about_us'),
                type == LegalType.privacy
                    ? lang.tr('privacy_section1_content', category: 'about_us')
                    : lang.tr('terms_section1_content', category: 'about_us'),
                sectionTitleColor,
                bodyTextColor,
              ),
              Divider(height: 40, color: dividerColor),
              _buildSection(
                type == LegalType.privacy
                    ? lang.tr('privacy_section2_title', category: 'about_us')
                    : lang.tr('terms_section2_title', category: 'about_us'),
                type == LegalType.privacy
                    ? lang.tr('privacy_section2_content', category: 'about_us')
                    : lang.tr('terms_section2_content', category: 'about_us'),
                sectionTitleColor,
                bodyTextColor,
              ),
              if (type == LegalType.privacy) ...[
                Divider(height: 40, color: dividerColor),
                _buildSection(
                  lang.tr('privacy_section3_title', category: 'about_us'),
                  lang.tr('privacy_section3_content', category: 'about_us'),
                  sectionTitleColor,
                  bodyTextColor,
                ),
              ],
              Divider(height: 40, color: dividerColor),
              _buildSection(
                lang.tr('legal_contact_title', category: 'about_us'),
                lang.tr('legal_contact_content', category: 'about_us'),
                sectionTitleColor,
                bodyTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
      String title, String content, Color titleColor, Color bodyColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
            fontFamily: 'Exo2',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: bodyColor,
            height: 1.6,
            fontFamily: 'Exo2',
          ),
        ),
      ],
    );
  }
}
