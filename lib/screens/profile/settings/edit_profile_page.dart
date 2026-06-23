import 'package:dzair_data_usage/langs.dart';
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
import 'package:service_app/Services/wilaya_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _professionController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  
  String? _selectedWilaya;
  String? _selectedCommune;
  String? _photoUrl;
  List<String> _wilayas = [];
  List<String> _communes = [];
  
  List<String> _portfolio = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final user = authVM.currentUser;
    
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _professionController = TextEditingController(text: user?.profession ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    
    _portfolio = List.from(user?.portfolio ?? []);
    _photoUrl = user?.photoUrl;
    
    _selectedWilaya = user?.wilaya;
    _selectedCommune = user?.commune;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWilayas();
    });
  }

  Language _getDzairLanguage(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'ar':
        return Language.AR;
      case 'fr':
        return Language.FR;
      case 'en':
        return Language.FR; // Fallback to FR for location data
      default:
        return Language.FR;
    }
  }

  void _loadWilayas() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final dzairLang = _getDzairLanguage(languageProvider.locale.languageCode);
    
    setState(() {
      _wilayas = WilayaService.getAllWilayaNamesSafe(language: dzairLang);
      if (_selectedWilaya != null) {
        // Since the names in the dropdown are in the selected language, 
        // we might need to be careful if we saved them in another language.
        // For simplicity, we assume consistent language usage or rely on _findWilayaByName.
        _communes = WilayaService.getCommunesForWilayaSafe(_selectedWilaya!, language: dzairLang);
      }
    });
  }

  void _onWilayaChanged(String? newValue) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _selectedWilaya = newValue;
      _selectedCommune = null;
      _communes = newValue != null 
          ? WilayaService.getCommunesForWilayaSafe(newValue, language: _getDzairLanguage(languageProvider.locale.languageCode)) 
          : [];
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final compressedBytes = await ImageOptimizer.compressImage(File(image.path));
      final base64Image = base64Encode(compressedBytes);
      setState(() {
        _photoUrl = 'data:image/jpeg;base64,$base64Image';
      });
      print('✅ Profile photo updated in local state');
    } catch (e) {
      print('❌ Error changing photo: $e');
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      AppSnackBar.showError(context, lang.trParams('error_changing_photo', category: 'profile', params: {'error': e.toString()}));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPortfolioImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final compressedBytes = await ImageOptimizer.compressImage(File(image.path));
      final base64Image = base64Encode(compressedBytes);
      setState(() {
        _portfolio.add('data:image/jpeg;base64,$base64Image');
      });
      print('✅ Portfolio image added to local list');
    } catch (e) {
      print('❌ Error adding portfolio image: $e');
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      AppSnackBar.showError(context, lang.trParams('error_adding_image', category: 'profile', params: {'error': e.toString()}));
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
          address: _addressController.text.trim(),
          wilaya: _selectedWilaya,
          commune: _selectedCommune,
          portfolio: _portfolio,
          photoUrl: _photoUrl,
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
    final user = context.watch<AuthViewModel>().currentUser;
    final isProvider = user?.isProvider ?? false;
    final theme = Theme.of(context);
    
    print('👤 EditProfilePage Build: isProvider=$isProvider, role=${user?.role}');

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.primaryColor, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _photoUrl != null && _photoUrl!.isNotEmpty
                                    ? Builder(
                                        builder: (context) {
                                          final provider = ImageUtils.getImageProvider(_photoUrl!);
                                          if (provider == null) return const Icon(Icons.person, size: 60);
                                          return Image(
                                            image: provider,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.person, size: 60),
                                          );
                                        },
                                      )
                                    : const Icon(Icons.person, size: 60),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _changeProfilePhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildTextField(
                        theme: theme,
                        controller: _emailController,
                        label: languageProvider.tr('email', category: 'auth'),
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),
                      const SizedBox(height: 20),
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
                      
                      // Wilaya Dropdown
                      _buildDropdown(
                        theme: theme,
                        label: languageProvider.tr('wilaya', category: 'search'),
                        value: _selectedWilaya,
                        items: _wilayas,
                        icon: Icons.map_outlined,
                        onChanged: _onWilayaChanged,
                      ),
                      const SizedBox(height: 20),
                      
                      // Commune Dropdown
                      _buildDropdown(
                        theme: theme,
                        label: languageProvider.tr('commune', category: 'search'),
                        value: _selectedCommune,
                        items: _communes,
                        icon: Icons.location_city_outlined,
                        onChanged: (value) {
                          setState(() {
                            _selectedCommune = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        theme: theme,
                        controller: _addressController,
                        label: languageProvider.tr('address', category: 'auth'),
                        icon: Icons.location_on_outlined,
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

  Widget _buildDropdown({
    required ThemeData theme,
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value != null && items.contains(value) ? value : null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: theme.primaryColor),
            border: InputBorder.none,
            labelStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: theme.cardColor,
          isExpanded: true,
        ),
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
                            child: Builder(
                              builder: (context) {
                                final provider = ImageUtils.getImageProvider(_portfolio[index]);
                                if (provider == null) return const Icon(Icons.broken_image_outlined);
                                return Image(
                                  image: provider,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image_outlined),
                                );
                              },
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
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? theme.cardColor : theme.disabledColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (enabled)
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
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: enabled ? theme.primaryColor : theme.disabledColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white38 : kMutedTextColor),
        ),
        style: TextStyle(
          color: enabled ? theme.textTheme.bodyLarge?.color : theme.disabledColor,
          fontSize: 16,
        ),
      ),
    );
  }
}
