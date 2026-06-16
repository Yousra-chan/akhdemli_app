import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';

class HelpFaqPage extends StatefulWidget {
  const HelpFaqPage({super.key});

  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage> {
  final List<Map<String, String>> _faqs = [
    {'question_key': 'faq_q1', 'answer_key': 'faq_a1'},
    {'question_key': 'faq_q2', 'answer_key': 'faq_a2'},
    {'question_key': 'faq_q3', 'answer_key': 'faq_a3'},
    {'question_key': 'faq_q4', 'answer_key': 'faq_a4'},
  ];

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors derived from isDark
    final scaffoldColor =
    isDark ? const Color(0xFF0F0F1A) : kLightBackgroundColor;
    final appBarColor = isDark ? const Color(0xFF16213E) : Colors.white;
    final titleColor = isDark ? const Color(0xFFE0E0E0) : kDarkTextColor;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final questionColor = isDark ? const Color(0xFFE0E0E0) : kDarkTextColor;
    final answerColor = isDark
        ? const Color(0xFFAAAAAA)
        : kDarkTextColor.withOpacity(0.8);
    final shadowColor =
    isDark ? Colors.black54 : Colors.black.withOpacity(0.03);
    final expansionIconColor =
    isDark ? const Color(0xFF8B9EFF) : kPrimaryBlue;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text(
          lang.tr('help_faq', category: 'about_us'),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Theme(
              // Override ExpansionTile's internal theme so colours match
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: expansionIconColor,
                ),
              ),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(
                    side: BorderSide(color: Colors.transparent)),
                collapsedIconColor: expansionIconColor,
                iconColor: expansionIconColor,
                title: Text(
                  lang.tr(_faqs[index]['question_key']!,
                      category: 'about_us'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: questionColor,
                    fontSize: 15,
                    fontFamily: 'Exo2',
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, bottom: 20),
                    child: Text(
                      lang.tr(_faqs[index]['answer_key']!,
                          category: 'about_us'),
                      style: TextStyle(
                        color: answerColor,
                        fontSize: 14,
                        height: 1.5,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}