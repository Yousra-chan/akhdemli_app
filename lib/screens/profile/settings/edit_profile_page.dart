import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/utils/ui_widgets.dart';
import 'package:service_app/utils/image_optimizer.dart';
import 'package:service_app/utils/image_utils.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _professionController;
  List<String> _portfolio = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    _nameController =
        TextEditingController(text: authVM.currentUser?.name ?? '');
    _phoneController =
        TextEditingController(text: authVM.currentUser?.phone ?? '');
    _professionController =
        TextEditingController(text: authVM.currentUser?.profession ?? '');
    _portfolio = List.from(authVM.currentUser?.portfolio ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _addPortfolioImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final compressedBytes = await ImageOptimizer.compressImage(File(image.path));
      final base64Image = base64Encode(compressedBytes);
      setState(() {
        _portfolio.add(base64Image);
      });
    } catch (e) {
      AppSnackBar.showError(context, 'Error adding image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(LanguageProvider languageProvider) async {
    setState(() => _isLoading = true);

    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);

      if (authVM.currentUser != null) {
        final updatedUser = authVM.currentUser!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          profession: _professionController.text.trim(),
          portfolio: _portfolio,
        );
        await authVM.updateUserProfile(updatedUser);
      }

      if (mounted) {
        if (!context.mounted) return;
        AppSnackBar.showSuccess(
          context,
          languageProvider.tr('updatePersonalInfo', category: 'profile'),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          '${languageProvider.tr('error_occurred', category: 'common')}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final isProvider = context.read<AuthViewModel>().currentUser?.isProvider ?? false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildAppBar(context, languageProvider, theme),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildTextField(
                        theme: theme,
                        controller: _nameController,
                        label: languageProvider.tr('full_name', category: 'auth'),
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        theme: theme,
                        controller: _phoneController,
                        label: languageProvider.tr('phone_number', category: 'auth'),
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 20),
                      if (isProvider) ...[
                        _buildTextField(
                          theme: theme,
                          controller: _professionController,
                          label: languageProvider.tr('profession', category: 'common'),
                          icon: Icons.work_outline,
                        ),
                        const SizedBox(height: 20),
                        _buildPortfolioEditor(languageProvider, theme),
                        const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _updateProfile(languageProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  languageProvider.tr('save', category: 'common'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPortfolioEditor(LanguageProvider lang, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.tr('my_work_portfolio', category: 'provider_profile'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color,
                fontFamily: 'Exo2',
              ),
            ),
            TextButton.icon(
              onPressed: _addPortfolioImage,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(lang.tr('add', category: 'common')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: _portfolio.isEmpty
              ? Center(
                  child: Text(
                    lang.tr('no_images', category: 'common'),
                    style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _portfolio.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsetsDirectional.only(end: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ImageUtils.isBase64Image(_portfolio[index])
                                ? Image.memory(
                                    ImageUtils.decodeBase64Image(_portfolio[index])!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    _portfolio[index],
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 2,
                          end: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _portfolio.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, LanguageProvider languageProvider, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: theme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back,
                color: theme.textTheme.titleLarge?.color,
                size: 24,
              ),
            ),
          ),
          Text(
            languageProvider.tr('editProfile', category: 'profile'),
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          Container(width: 40),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor),
        ),
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 16,
        ),
      ),
    );
  }
}
