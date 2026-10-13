import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../product/product_list_screen.dart';
import '../order/my_orders_screen.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import 'address_book_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_image_crop_screen.dart';
import 'profile_options_screens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _selectAvatar(AuthProvider auth) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isEmpty) return;
      final image = files.single;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('The selected image could not be read.');
      }
      if (!mounted) return;
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ProfileImageCropScreen(imageBytes: bytes),
        ),
      );
      if (croppedBytes == null || croppedBytes.isEmpty || !mounted) return;
      setState(() => _uploadingAvatar = true);
      await auth.updateAvatar(croppedBytes, 'profile.png');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _setTheme(bool isDark) async {
    try {
      await context.read<ThemeProvider>().setDarkMode(isDark);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save appearance preference: $error')),
      );
    }
  }

  Future<void> _chooseLanguage() async {
    final languageProvider = context.read<AppLanguageProvider>();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.tr('Choose language')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'en'),
            child: Row(
              children: [
                const Expanded(child: Text('English')),
                if (languageProvider.languageCode == 'en')
                  const Icon(Icons.check, color: AppConstants.primary),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'ne'),
            child: Row(
              children: [
                const Expanded(child: Text('नेपाली')),
                if (languageProvider.languageCode == 'ne')
                  const Icon(Icons.check, color: AppConstants.primary),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await languageProvider.setLanguage(selected);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save language preference: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final products = context.read<ProductProvider>();
    final themeProvider = context.watch<ThemeProvider?>();
    final languageProvider = context.watch<AppLanguageProvider?>();
    final isDark = themeProvider?.isDarkMode ?? AppConstants.isDarkTheme;
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark
                          ? const Color(0xFF0D1B13)
                          : const Color(0xFFDDF5E4),
                      AppConstants.backgroundLight,
                      isDark
                          ? const Color(0xFF080A09)
                          : const Color(0xFFF4FAF5),
                    ],
                    stops: const [0, 0.38, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -115,
              left: -135,
              child: IgnorePointer(
                child: Container(
                  width: 390,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? const [Color(0x661DB954), Color(0x001DB954)]
                          : const [Color(0x6676D99A), Color(0x0076D99A)],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    // Keep the expensive backdrop blur confined to this hero.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      const Color(0xD9222925),
                                      const Color(0xC91A201D),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.74),
                                      const Color(0xFFE8F8EC)
                                          .withValues(alpha: 0.68),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: isDark
                                  ? AppConstants.borderLight
                                      .withValues(alpha: 0.72)
                                  : Colors.white.withValues(alpha: 0.78),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.primary
                                    .withValues(alpha: isDark ? 0.13 : 0.1),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppConstants.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        context.tr('YOUR STORE ACCOUNT'),
                                        style: TextStyle(
                                          color: AppConstants.primaryDark,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.05,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _uploadingAvatar
                                        ? null
                                        : () => _selectAvatar(auth),
                                    borderRadius: BorderRadius.circular(38),
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 34,
                                          backgroundColor:
                                              AppConstants.primaryLight,
                                          child: _uploadingAvatar
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppConstants.primary,
                                                  ),
                                                )
                                              : user?.avatarUrl != null
                                                  ? ClipOval(
                                                      child: CachedNetworkImage(
                                                        key: ValueKey(
                                                          user!.avatarUrl,
                                                        ),
                                                        imageUrl:
                                                            user.avatarUrl!,
                                                        httpHeaders: {
                                                          if (auth.authToken !=
                                                              null)
                                                            'Authorization':
                                                                'Bearer ${auth.authToken}',
                                                        },
                                                        width: 68,
                                                        height: 68,
                                                        fit: BoxFit.cover,
                                                        memCacheWidth: 256,
                                                        memCacheHeight: 256,
                                                        placeholder: (_, __) =>
                                                            _avatarInitial(
                                                                user.fullName),
                                                        errorWidget: (_, __,
                                                                ___) =>
                                                            _avatarInitial(
                                                                user.fullName),
                                                      ),
                                                    )
                                                  : _avatarInitial(
                                                      user?.fullName,
                                                    ),
                                        ),
                                        if (!_uploadingAvatar)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: const BoxDecoration(
                                                color: AppConstants.primary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt_outlined,
                                                size: 14,
                                                color: AppConstants
                                                    .primaryForeground,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.fullName ?? 'Guest Customer',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 19,
                                            color: AppConstants.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user?.email ?? 'customer@example.com',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppConstants.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit profile',
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EditProfileScreen(),
                                      ),
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppConstants.surfaceLight
                                          .withValues(alpha: 0.78),
                                      foregroundColor: AppConstants.primaryDark,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  _ProfileQuickAction(
                                    icon: Icons.receipt_long_outlined,
                                    label: context.tr('Orders'),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MyOrdersScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _ProfileQuickAction(
                                    icon: Icons.location_on_outlined,
                                    label: context.tr('Addresses'),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AddressBookScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _ProfileQuickAction(
                                    icon: Icons.favorite_border,
                                    label: context.tr('Saved items'),
                                    onTap: () {
                                      products.resetCatalogFilters();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ProductListScreen(
                                            categoryName: 'Saved items',
                                            favoritesOnly: true,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options List
                    Material(
                      color: AppConstants.glassSurfaceFor(isDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: AppConstants.glassBorderFor(isDark),
                        ),
                      ),
                      elevation: 1,
                      shadowColor:
                          AppConstants.primaryDark.withValues(alpha: 0.06),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            secondary: Icon(
                              isDark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              color: AppConstants.primary,
                            ),
                            title: Text(
                              context.tr('Dark appearance'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              context.tr(
                                isDark ? 'Dark mode is on' : 'Light mode is on',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppConstants.textMuted,
                              ),
                            ),
                            value: isDark,
                            onChanged: themeProvider == null ? null : _setTheme,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.translate_outlined,
                              color: AppConstants.primary,
                            ),
                            title: Text(
                              context.tr('Language'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              context.tr(
                                languageProvider?.languageCode == 'ne'
                                    ? 'Nepali'
                                    : 'English',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppConstants.textMuted,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: languageProvider == null
                                ? null
                                : _chooseLanguage,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.payment_outlined,
                                color: AppConstants.primary),
                            title: Text(context.tr('Payment Methods'),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentPreferenceScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.notifications_active_outlined,
                              color: AppConstants.primary,
                            ),
                            title: Text(
                              context.tr('Notifications'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                                Icons.notifications_none_outlined,
                                color: AppConstants.primary),
                            title: Text(context.tr('Notification Preferences'),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationPreferencesScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: AppConstants.primary,
                            ),
                            title: Text(
                              context.tr('Store administration'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle:
                                Text(context.tr(
                                  'Sign in with an admin account',
                                )),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LoginScreen(isAdminLogin: true),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Material(
                      color: AppConstants.glassSurfaceFor(isDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: AppConstants.glassBorderFor(isDark),
                        ),
                      ),
                      elevation: 1,
                      shadowColor:
                          AppConstants.primaryDark.withValues(alpha: 0.06),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.help_outline,
                                color: AppConstants.textMuted),
                            title: Text(context.tr('Help & store information'),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StoreHelpScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.privacy_tip_outlined,
                                color: AppConstants.textMuted),
                            title: Text(context.tr('Privacy Policy'),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StorePrivacyScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading:
                                const Icon(Icons.logout, color: Colors.red),
                            title: Text(context.tr('Log Out'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red)),
                            onTap: () async {
                              await auth.logout();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _avatarInitial(String? fullName) {
  return Center(
    child: Text(
      fullName != null && fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
      style: TextStyle(
        color: AppConstants.primaryDark,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _ProfileQuickAction extends StatelessWidget {
  const _ProfileQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppConstants.glassSurfaceFor(AppConstants.isDarkTheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppConstants.glassBorderFor(AppConstants.isDarkTheme),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppConstants.primary.withValues(alpha: 0.1),
          highlightColor: AppConstants.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, color: AppConstants.primaryDark, size: 20),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppConstants.textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
