import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/customer_menu_features.dart';
import '../../services/secure_login_service.dart';
import '../../services/api_service.dart';
import '../../widgets/unread_notification_indicator.dart';
import '../product/product_list_screen.dart';
import '../order/my_orders_screen.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import 'address_book_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_image_crop_screen.dart';
import 'profile_options_screens.dart';
import 'buying_streak_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.secureLoginService,
  });

  final SecureLoginService? secureLoginService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _deletingAccount = false;
  int _notificationRefreshToken = 0;
  CustomerMenuFeatures _menuFeatures = CustomerMenuFeatures.defaults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCustomerMenuFeatures();
    });
  }

  Future<void> _loadCustomerMenuFeatures() async {
    final api = context.read<ApiService?>();
    if (api == null) return;
    try {
      final response = await api.get('/store/customer-menu-features');
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Invalid customer menu settings.');
      }
      if (!mounted) return;
      setState(() {
        _menuFeatures =
            CustomerMenuFeatures.fromJson(response['customerMenuFeatures']);
      });
    } catch (error) {
      debugPrint('Customer menu settings unavailable: $error');
    }
  }

  Future<bool> _ensureSignedIn() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated && auth.currentUser != null) return true;

    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnToCaller: true),
      ),
    );
    return signedIn == true &&
        mounted &&
        context.read<AuthProvider>().isAuthenticated;
  }

  Future<void> _openAccountSection(WidgetBuilder builder) async {
    if (!await _ensureSignedIn() || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: builder),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
    if (mounted) setState(() => _notificationRefreshToken++);
  }

  Future<void> _logOut(AuthProvider auth) async {
    String? storageError;
    try {
      await auth.logout();
    } catch (error) {
      storageError = error.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    if (storageError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('You are signed out for now, but this device could not clear your saved session:')} $storageError',
          ),
        ),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(AuthProvider auth) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _AccountDeletionDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _deletingAccount = true);
    String? cleanupWarning;
    try {
      cleanupWarning = await auth.deleteAccount(password: password);
      try {
        await (widget.secureLoginService ?? SecureLoginService()).clear();
      } catch (error) {
        cleanupWarning ??= error.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleanupWarning == null
                ? context.tr('Your account has been deleted.')
                : '${context.tr('Your account was deleted, but saved sign-in could not be cleared:')} $cleanupWarning',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<void> _selectAvatar(AuthProvider auth) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isEmpty) return;
      final image = files.single;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('Choose a profile photo that is 5 MB or smaller.');
      }
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
        SnackBar(content: Text(context.tr('Profile photo updated.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(error.toString().replaceFirst('Exception: ', '')),
          ),
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
        SnackBar(
          content: Text(
            '${context.tr('Could not save appearance preference:')} $error',
          ),
        ),
      );
    }
  }

  Future<void> _chooseLanguage() async {
    final languageProvider = context.read<AppLanguageProvider>();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(languageProvider.translate('Choose language')),
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
        SnackBar(
          content: Text(
            '${context.tr('Could not save language preference:')} $error',
          ),
        ),
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
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
                  key: const ValueKey('profile-menu-scroll'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 124),
                  children: [
                    Container(
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
                              ? AppConstants.borderLight.withValues(alpha: 0.72)
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
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _uploadingAvatar || user == null
                                        ? null
                                        : () => _selectAvatar(auth),
                                    borderRadius: BorderRadius.circular(38),
                                    child: Tooltip(
                                      message: context.tr(
                                        user == null
                                            ? 'Profile photo'
                                            : 'Change profile photo',
                                      ),
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
                                                      color:
                                                          AppConstants.primary,
                                                    ),
                                                  )
                                                : user?.avatarUrl != null
                                                    ? ClipOval(
                                                        child:
                                                            CachedNetworkImage(
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
                                                          placeholder: (_,
                                                                  __) =>
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
                                          if (!_uploadingAvatar && user != null)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(5),
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
                                  ),
                                  if (user?.profileId != null) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      user!.profileId!,
                                      style: TextStyle(
                                        color: AppConstants.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.fullName ??
                                          context.tr('Guest Customer'),
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
                                      user?.email ??
                                          context.tr(
                                            'Sign in to manage your account',
                                          ),
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
                                tooltip: context.tr('Edit profile'),
                                onPressed: user == null
                                    ? null
                                    : () => Navigator.push(
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
                          if (user == null) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const LoginScreen(
                                      returnToCaller: true,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.login_rounded),
                                label: Text(
                                  context.tr('Sign in to manage your account'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              if (_menuFeatures.isEnabled('orders'))
                                _ProfileQuickAction(
                                  icon: Icons.receipt_long_outlined,
                                  label: context.tr('Orders'),
                                  onTap: () => _openAccountSection(
                                    (_) => const MyOrdersScreen(),
                                  ),
                                ),
                              if (_menuFeatures.isEnabled('orders') &&
                                  (_menuFeatures.isEnabled('addresses') ||
                                      _menuFeatures.isEnabled('savedItems')))
                                const SizedBox(width: 10),
                              if (_menuFeatures.isEnabled('addresses'))
                                _ProfileQuickAction(
                                  icon: Icons.location_on_outlined,
                                  label: context.tr('Addresses'),
                                  onTap: () => _openAccountSection(
                                    (_) => const AddressBookScreen(),
                                  ),
                                ),
                              if (_menuFeatures.isEnabled('addresses') &&
                                  _menuFeatures.isEnabled('savedItems'))
                                const SizedBox(width: 10),
                              if (_menuFeatures.isEnabled('savedItems'))
                                _ProfileQuickAction(
                                  icon: Icons.favorite_border,
                                  label: context.tr('Saved items'),
                                  onTap: () {
                                    products.resetCatalogFilters();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ProductListScreen(
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
                    if (_menuFeatures.isEnabled('buyingStreak')) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: AppConstants.glassSurfaceFor(isDark),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          key: const ValueKey('profile-buying-streak'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openAccountSection(
                            (_) => const BuyingStreakScreen(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Color(0xFFE98228),
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('Buying day streak'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        context.tr(
                                          'See your milestones and claim rewards',
                                        ),
                                        style: TextStyle(
                                          color: AppConstants.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_menuFeatures.isEnabled('appearance') ||
                        _menuFeatures.isEnabled('language') ||
                        _menuFeatures.isEnabled('payments') ||
                        _menuFeatures.isEnabled('notifications') ||
                        _menuFeatures.isEnabled('notificationPreferences'))
                      const SizedBox(height: 16),
                    if (_menuFeatures.isEnabled('appearance') ||
                        _menuFeatures.isEnabled('language') ||
                        _menuFeatures.isEnabled('payments') ||
                        _menuFeatures.isEnabled('notifications') ||
                        _menuFeatures.isEnabled('notificationPreferences'))
                      Text(
                        context.tr('Preferences & payments'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppConstants.textDark,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    if (_menuFeatures.isEnabled('appearance') ||
                        _menuFeatures.isEnabled('language') ||
                        _menuFeatures.isEnabled('payments') ||
                        _menuFeatures.isEnabled('notifications') ||
                        _menuFeatures.isEnabled('notificationPreferences'))
                      const SizedBox(height: 8),
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
                          if (_menuFeatures.isEnabled('appearance'))
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
                                  isDark
                                      ? 'Dark mode is on'
                                      : 'Light mode is on',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textMuted,
                                ),
                              ),
                              value: isDark,
                              onChanged:
                                  themeProvider == null ? null : _setTheme,
                            ),
                          if (_menuFeatures.isEnabled('language'))
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
                              trailing:
                                  const Icon(Icons.chevron_right, size: 20),
                              onTap: languageProvider == null
                                  ? null
                                  : _chooseLanguage,
                            ),
                          if (_menuFeatures.isEnabled('payments'))
                            ListTile(
                              leading: const Icon(Icons.payment_outlined,
                                  color: AppConstants.primary),
                              title: Text(context.tr('Payment methods'),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 20),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PaymentPreferenceScreen(),
                                ),
                              ),
                            ),
                          if (_menuFeatures.isEnabled('notifications'))
                            ListTile(
                              leading: UnreadNotificationIndicator(
                                api: context.read<ApiService?>(),
                                userId: user?.id,
                                refreshToken: _notificationRefreshToken,
                                child: const Icon(
                                  Icons.notifications_active_outlined,
                                  color: AppConstants.primary,
                                ),
                              ),
                              title: Text(
                                context.tr('Notifications'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 20),
                              onTap: _openNotifications,
                            ),
                          if (_menuFeatures
                              .isEnabled('notificationPreferences'))
                            ListTile(
                              leading: const Icon(
                                  Icons.notifications_none_outlined,
                                  color: AppConstants.primary),
                              title: Text(
                                  context.tr('Notification Preferences'),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 20),
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
                            subtitle: Text(context.tr(
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

                    if (_menuFeatures.isEnabled('help') ||
                        _menuFeatures.isEnabled('legal') ||
                        (user != null &&
                            _menuFeatures.isEnabled('deleteAccount')))
                      Text(
                        context.tr('Help & account'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppConstants.textDark,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    if (_menuFeatures.isEnabled('help') ||
                        _menuFeatures.isEnabled('legal') ||
                        user != null)
                      const SizedBox(height: 8),
                    if (_menuFeatures.isEnabled('help') ||
                        _menuFeatures.isEnabled('legal') ||
                        user != null)
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
                            if (_menuFeatures.isEnabled('help'))
                              ListTile(
                                leading: Icon(Icons.help_outline,
                                    color: AppConstants.textMuted),
                                title: Text(
                                    context.tr('Help & store information'),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 20),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StoreHelpScreen(),
                                  ),
                                ),
                              ),
                            if (_menuFeatures.isEnabled('legal'))
                              ListTile(
                                leading: Icon(Icons.privacy_tip_outlined,
                                    color: AppConstants.textMuted),
                                title: Text(context.tr('Privacy Policy'),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 20),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StorePrivacyScreen(),
                                  ),
                                ),
                              ),
                            if (user != null &&
                                _menuFeatures.isEnabled('deleteAccount')) ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.person_remove_outlined,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  context.tr('Delete account'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                                enabled: !_deletingAccount,
                                trailing: _deletingAccount
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right, size: 20),
                                onTap: _deletingAccount
                                    ? null
                                    : () => _deleteAccount(auth),
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
                                onTap: () => _logOut(auth),
                              ),
                            ],
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

class _AccountDeletionDialog extends StatefulWidget {
  const _AccountDeletionDialog();

  @override
  State<_AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<_AccountDeletionDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(context.tr('Delete account?')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Your profile and saved data will be removed. Completed order records will be anonymized and retained. Active orders must be completed or cancelled first.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Current password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              final password = _passwordController.text;
              Navigator.pop(context, password.isEmpty ? null : password);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('Delete account')),
          ),
        ],
      );
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
