import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          lang.tr('terms_title', category: 'terms'),
          style: const TextStyle(fontFamily: 'Exo2', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textTheme.titleLarge?.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr('terms_intro', category: 'terms'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
                fontFamily: 'Exo2',
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: lang.tr('section_1_title', category: 'terms'),
              content: lang.tr('section_1_content', category: 'terms'),
              theme: theme,
            ),
            _buildSection(
              title: lang.tr('section_2_title', category: 'terms'),
              content: lang.tr('section_2_content', category: 'terms'),
              theme: theme,
            ),
            _buildSection(
              title: lang.tr('section_3_title', category: 'terms'),
              content: lang.tr('section_3_content', category: 'terms'),
              theme: theme,
            ),
            _buildSection(
              title: lang.tr('section_4_title', category: 'terms'),
              content: lang.tr('section_4_content', category: 'terms'),
              theme: theme,
            ),
            _buildSection(
              title: lang.tr('section_5_title', category: 'terms'),
              content: lang.tr('section_5_content', category: 'terms'),
              theme: theme,
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                lang.tr('last_updated', category: 'terms'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.6,
              fontFamily: 'Exo2',
            ),
          ),
        ],
      ),
    );
  }
}
