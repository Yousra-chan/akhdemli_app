import 'package:flutter/material.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'package:service_app/models/UserModel.dart';
import 'package:service_app/screens/profile/profile_constants.dart';
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _professionController;
  late TextEditingController _wilayaController;
  late TextEditingController _communeController;
  bool _isLoading = false;

  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _currentUser = authViewModel.currentUser!;

    // Initialize all controllers with current user data
    _nameController = TextEditingController(text: _currentUser.name);
    _phoneController = TextEditingController(text: _currentUser.phone);
    _addressController = TextEditingController(text: _currentUser.address);
    _professionController =
        TextEditingController(text: _currentUser.profession ?? '');
    _wilayaController = TextEditingController(text: _currentUser.wilaya ?? '');
    _communeController =
        TextEditingController(text: _currentUser.commune ?? '');

    authViewModel.addListener(_updateCurrentUser);
  }

  void _updateCurrentUser() {
    if (mounted) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      setState(() {
        _currentUser = authViewModel.currentUser!;
      });
    }
  }

  @override
  void dispose() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    authViewModel.removeListener(_updateCurrentUser);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    _wilayaController.dispose();
    _communeController.dispose();
    super.dispose();
  }

  Future<void> _handlePhotoChange() async {
    setState(() => _isLoading = true);

    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final String? newPhotoUrl = await authViewModel.pickImageAndEncode();

      if (newPhotoUrl != null) {
        final updatedUser = _currentUser.copyWith(photoUrl: newPhotoUrl);
        await authViewModel.updateUserProfile(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: kSuccessColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      final updatedUser = _currentUser.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        profession: _professionController.text.trim().isNotEmpty
            ? _professionController.text.trim()
            : null,
        wilaya: _wilayaController.text.trim().isNotEmpty
            ? _wilayaController.text.trim()
            : null,
        commune: _communeController.text.trim().isNotEmpty
            ? _communeController.text.trim()
            : null,
      );

      await authViewModel.updateUserProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: kSuccessColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: kDangerColor,
          ),
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
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user = authViewModel.currentUser!;

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Simple App Bar (matches ProfilePage)
                _buildAppBar(context),

                // Profile Picture Section
                _buildProfileHeader(user),

                // Form Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: kCardBackgroundColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: kSoftShadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildEditableField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildEditableField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.length < 8) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _buildEditableField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your address';
                            }
                            return null;
                          },
                        ),
                        if (user.profession != null || true) ...[
                          const Divider(height: 1, indent: 20, endIndent: 20),
                          _buildEditableField(
                            controller: _professionController,
                            label: 'Profession',
                            icon: Icons.work_outline,
                            validator: (value) => null, // Optional field
                          ),
                        ],
                        if (user.wilaya != null || true) ...[
                          const Divider(height: 1, indent: 20, endIndent: 20),
                          _buildEditableField(
                            controller: _wilayaController,
                            label: 'Wilaya',
                            icon: Icons.location_city_outlined,
                            validator: (value) => null, // Optional field
                          ),
                        ],
                        if (user.commune != null || true) ...[
                          const Divider(height: 1, indent: 20, endIndent: 20),
                          _buildEditableField(
                            controller: _communeController,
                            label: 'Commune',
                            icon: Icons.location_city,
                            validator: (value) => null, // Optional field
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Update Button
                _buildUpdateButton(),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kLightBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: kDarkTextColor,
                size: 24,
              ),
            ),
          ),
          const Text(
            'Edit Profile',
            style: TextStyle(
              color: kDarkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          Container(
            width: 40, // Placeholder for spacing
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Profile Picture
              _buildProfilePicture(user),
              // Camera Icon
              GestureDetector(
                onTap: _isLoading ? null : _handlePhotoChange,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(
              color: kDarkTextColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Exo2',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: TextStyle(
                color: kPrimaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture(UserModel user) {
    final isBase64 = user.photoUrl.startsWith('data:');

    if (user.photoUrl.isNotEmpty) {
      if (isBase64) {
        final base64String = user.photoUrl.split(',').last;
        try {
          return CircleAvatar(
            radius: 50,
            backgroundColor: kLightBackgroundColor,
            backgroundImage: MemoryImage(base64Decode(base64String)),
          );
        } catch (e) {
          return _buildFallbackAvatar(user);
        }
      } else {
        return CircleAvatar(
          radius: 50,
          backgroundColor: kLightBackgroundColor,
          backgroundImage: NetworkImage(user.photoUrl),
          child: user.photoUrl.isEmpty ? _buildFallbackAvatar(user) : null,
        );
      }
    } else {
      return _buildFallbackAvatar(user);
    }
  }

  Widget _buildFallbackAvatar(UserModel user) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: kLightBackgroundColor,
      child: user.name.isNotEmpty
          ? Text(
              user.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 36,
                color: kPrimaryBlue,
                fontWeight: FontWeight.bold,
                fontFamily: 'Exo2',
              ),
            )
          : const Icon(
              Icons.person,
              color: kPrimaryBlue,
              size: 60,
            ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kMutedTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                icon,
                color: kPrimaryBlue,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    color: kDarkTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
