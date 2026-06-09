import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../res/app_colors.dart';
import '../../utils/custom_button.dart';
import '../../utils/text_style.dart';
import '../../view_model/before_login_provider/auth_providers.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.name);
    _usernameController = TextEditingController(text: auth.username);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.read<AuthProvider>().goBackToCategories(),
        ),
        title: Text('Profile', style: text18(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Avatar ──────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => _showAvatarOptions(context),
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.grey200,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.grey300,
                            width: 2,
                          ),
                        ),
                        child: auth.avatarPath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(auth.avatarPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: AppColors.grey600,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 40,
                                color: AppColors.grey600,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'Tap to add photo',
                  style: text12(color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 32),

              // ── Name ────────────────────────────────────────
              Text('Name', style: text13(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'Enter your name',
                errorText: auth.nameError,
                onChanged: (v) => context.read<AuthProvider>().setName(v),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 20),

              // ── Username ─────────────────────────────────────
              Text('Username', style: text13(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _usernameController,
                hint: 'Choose a username',
                errorText: auth.usernameError,
                prefix: '@',
                onChanged: (v) => context.read<AuthProvider>().setUsername(v),
              ),
              const SizedBox(height: 6),
              Text(
                'Only lowercase letters, numbers and underscores.',
                style: text11(color: AppColors.textSecondary),
              ),

              // Selected genres summary
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your interests',
                      style: text13(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: auth.selectedGenres.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            g,
                            style: text11(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Save button ──────────────────────────────────
              AppButton(
                title: 'Continue',
                isLoading: auth.profileSaving,
                onTap: () {
                  context.read<AuthProvider>().saveProfile(context);
                },
              ),

              if (auth.profileError != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    auth.profileError!,
                    style: text12(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? errorText,
    String? prefix,
    ValueChanged<String>? onChanged,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      style: text14(color: AppColors.textPrimary),
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: text14(color: AppColors.hintText),
        prefixText: prefix,
        prefixStyle: text14(color: AppColors.textSecondary),
        errorText: errorText,
        errorStyle: text11(color: AppColors.error),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: errorText != null ? AppColors.error : AppColors.grey300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Profile Photo',
              style: text16(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AvatarOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    context.read<AuthProvider>().pickImage(ImageSource.camera);
                  },
                ),
                _AvatarOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    context.read<AuthProvider>().pickImage(ImageSource.gallery);
                  },
                ),
                if (context.read<AuthProvider>().avatarPath != null)
                  _AvatarOption(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () {
                      context.read<AuthProvider>().setAvatarPath(null);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _AvatarOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: text12(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
