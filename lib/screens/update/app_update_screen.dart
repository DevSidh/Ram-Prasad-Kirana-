import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/android_apk_installer.dart';
import '../../services/apk_download_service.dart';
import '../../services/app_update_service.dart';
import '../../services/github_release_service.dart';

enum _UpdateViewState {
  checking,
  available,
  downloading,
  ready,
  failed,
  current
}

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key, this.initialCheck});

  final AppUpdateCheck? initialCheck;

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _orbitController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  final _updates = AppUpdateService();
  final _downloads = ApkDownloadService();
  _UpdateViewState _state = _UpdateViewState.checking;
  AppUpdateCheck? _check;
  CancelToken? _cancelToken;
  File? _apkFile;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _error;
  String? _currentVersion;
  String? _currentBuild;
  bool _installing = false;
  bool _verifying = false;

  bool get _mandatory => _check?.isMandatory ?? false;
  GitHubAppRelease? get _release => _check?.release;
  bool get _supportsAndroidInstall => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (widget.initialCheck != null) {
      _check = widget.initialCheck;
      _state = _UpdateViewState.available;
    } else {
      _checkForUpdates();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Update screen closed.');
    _entryController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _state = _UpdateViewState.checking;
      _error = null;
    });
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
          _currentBuild = packageInfo.buildNumber;
        });
      }
      final result = await _updates.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _check = result;
        _state = result.updateAvailable
            ? _UpdateViewState.available
            : _UpdateViewState.current;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _state = _UpdateViewState.failed;
      });
    }
  }

  Future<void> _downloadUpdate() async {
    final release = _release;
    if (release == null || _state == _UpdateViewState.downloading) return;
    if (!_supportsAndroidInstall) {
      final opened = await launchUrl(
        Uri.parse(release.htmlUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() {
          _error = 'Could not open the official GitHub release page.';
          _state = _UpdateViewState.failed;
        });
      }
      return;
    }
    final token = CancelToken();
    _cancelToken = token;
    setState(() {
      _state = _UpdateViewState.downloading;
      _receivedBytes = 0;
      _totalBytes = release.sizeBytes;
      _verifying = false;
      _apkFile = null;
      _error = null;
    });
    try {
      final file = await _downloads.download(
        release,
        cancelToken: token,
        onStage: (stage) {
          if (!mounted || token.isCancelled) return;
          setState(() => _verifying = stage == ApkDownloadStage.verifying);
        },
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            if (total > 0) _totalBytes = total;
          });
        },
      );
      if (!mounted) return;
      final downloadedLength = await file.length();
      if (!mounted) return;
      setState(() {
        _apkFile = file;
        _receivedBytes = downloadedLength;
        _state = _UpdateViewState.ready;
      });
      await _installUpdate();
    } catch (error) {
      if (!mounted) return;
      if (error is DioException && CancelToken.isCancel(error)) {
        setState(() => _state = _UpdateViewState.available);
      } else {
        setState(() {
          _error = _friendlyError(error);
          _state = _UpdateViewState.failed;
        });
      }
    } finally {
      _cancelToken = null;
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('Download cancelled by user.');
  }

  Future<void> _installUpdate() async {
    final file = _apkFile;
    if (file == null || _installing) return;
    if (!_supportsAndroidInstall) {
      setState(() {
        _error = 'APK installation is available on Android devices.';
        _state = _UpdateViewState.failed;
      });
      return;
    }
    setState(() => _installing = true);
    try {
      if (!await AndroidApkInstaller.canInstallPackages()) {
        await AndroidApkInstaller.openInstallPermissionSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Allow FastStore to install this update, then return and tap Install Now.',
              ),
            ),
          );
        }
        return;
      }
      await AndroidApkInstaller.installApk(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Android installer opened. Confirm the update there.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _state = _UpdateViewState.failed;
      });
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is PlatformException &&
        error.code == 'wrong_signing_certificate') {
      return error.message ??
          'This APK was signed with a different certificate. Installation was stopped to protect your data.';
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Could not reach GitHub. Check your connection and try again.';
      }
      if (CancelToken.isCancel(error)) return 'Download cancelled.';
    }
    if (error is FormatException) return message;
    return message.isEmpty ? 'The update could not be completed.' : message;
  }

  void _continue() {
    if (!_mandatory && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_mandatory,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 22,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.shopping_bag_rounded, color: colors.primary),
              ),
              const SizedBox(width: 11),
              const Text('FastStore',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            if (_mandatory)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Chip(
                  label: const Text('UPDATE REQUIRED'),
                  backgroundColor: colors.errorContainer,
                  labelStyle: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  side: BorderSide.none,
                ),
              )
            else
              TextButton(
                onPressed:
                    _state == _UpdateViewState.downloading ? null : _continue,
                child: const Text('Maybe later'),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _entryController,
              curve: Curves.easeOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: .97, end: 1).animate(
                CurvedAnimation(
                    parent: _entryController, curve: Curves.easeOutCubic),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(22, compact ? 6 : 14, 22, 26),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight - 46),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _buildStateContent(context, compact),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent(BuildContext context, bool compact) {
    final colors = Theme.of(context).colorScheme;
    final release = _release;
    final isBusy = _state == _UpdateViewState.downloading ||
        _state == _UpdateViewState.checking;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: compact ? 8 : 18),
        _PhoneUpdateIllustration(
          orbitController: _orbitController,
          progress: _state == _UpdateViewState.downloading && !_verifying
              ? (_totalBytes == 0
                  ? null
                  : (_receivedBytes / _totalBytes).clamp(0, 1).toDouble())
              : _state == _UpdateViewState.ready
                  ? 1
                  : null,
          failed: _state == _UpdateViewState.failed,
          size: compact ? 190 : 232,
        ),
        const SizedBox(height: 15),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: Text(
            key: ValueKey(_state),
            _headline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
        ),
        if (_check != null || _currentVersion != null) ...[
          const SizedBox(height: 16),
          _VersionRow(
            current: _check?.currentVersion ?? _currentVersion!,
            buildNumber: _check?.buildNumber ?? _currentBuild ?? '',
            latest: release?.version,
          ),
        ],
        if (_state == _UpdateViewState.available && release != null) ...[
          const SizedBox(height: 20),
          _ReleaseNotesCard(release: release),
        ],
        if (_state == _UpdateViewState.downloading) ...[
          const SizedBox(height: 20),
          if (_verifying)
            const Text('Download complete. Checking APK integrity…',
                textAlign: TextAlign.center)
          else
            _DownloadProgress(
              receivedBytes: _receivedBytes,
              totalBytes: _totalBytes,
            ),
        ],
        if (_state == _UpdateViewState.failed && _error != null) ...[
          const SizedBox(height: 18),
          _ErrorCard(message: _error!),
        ],
        const SizedBox(height: 22),
        _primaryAction(context),
        if (_state == _UpdateViewState.downloading) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _cancelDownload,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel download'),
          ),
        ],
        if (!_mandatory &&
            (_state == _UpdateViewState.available ||
                _state == _UpdateViewState.failed)) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed:
                _state == _UpdateViewState.downloading ? null : _continue,
            child: const Text('Continue using FastStore'),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 15, color: colors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Secure download from the official GitHub release',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
        if (release?.publishedAt case final publishedAt?) ...[
          const SizedBox(height: 7),
          Text(
            'Published ${DateFormat.yMMMd().format(publishedAt.toLocal())}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
        if (isBusy) const SizedBox(height: 6),
      ],
    );
  }

  String get _headline => switch (_state) {
        _UpdateViewState.checking => 'Checking for updates…',
        _UpdateViewState.available => 'A fresh update is ready!',
        _UpdateViewState.downloading =>
          _verifying ? 'Verifying your update…' : 'Downloading your update…',
        _UpdateViewState.ready => 'Your update is ready!',
        _UpdateViewState.failed => 'We couldn’t finish the update',
        _UpdateViewState.current => 'You’re using the latest version!',
      };

  String get _description => switch (_state) {
        _UpdateViewState.checking => 'Checking the official FastStore release.',
        _UpdateViewState.available => _mandatory
            ? 'A newer version of FastStore is required to continue shopping.'
            : 'A newer version of FastStore is available with improvements for you.',
        _UpdateViewState.downloading =>
          'FastStore will keep your account and saved data.',
        _UpdateViewState.ready =>
          'Android will ask you to confirm the installation.',
        _UpdateViewState.failed =>
          'Your account and saved data are unchanged. You can try again.',
        _UpdateViewState.current => 'FastStore is up to date.',
      };

  Widget _primaryAction(BuildContext context) {
    switch (_state) {
      case _UpdateViewState.checking:
        return const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case _UpdateViewState.available:
        return _ActionButton(
          label: _supportsAndroidInstall ? 'Update Now' : 'View release',
          icon: _supportsAndroidInstall
              ? Icons.download_rounded
              : Icons.open_in_new_rounded,
          onPressed: _downloadUpdate,
        );
      case _UpdateViewState.downloading:
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: !_verifying && _totalBytes > 0
                ? (_receivedBytes / _totalBytes).clamp(0, 1)
                : null,
          ),
        );
      case _UpdateViewState.ready:
        return _ActionButton(
          label: _installing ? 'Opening installer…' : 'Install Now',
          icon: Icons.install_mobile_rounded,
          onPressed: _installing ? null : _installUpdate,
        );
      case _UpdateViewState.failed:
        return _ActionButton(
          label: 'Try Again',
          icon: Icons.refresh_rounded,
          onPressed: _apkFile != null
              ? _installUpdate
              : _check == null
                  ? _checkForUpdates
                  : _downloadUpdate,
        );
      case _UpdateViewState.current:
        return OutlinedButton.icon(
          onPressed: _checkForUpdates,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Check again'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
        );
    }
  }
}

class _PhoneUpdateIllustration extends StatelessWidget {
  const _PhoneUpdateIllustration({
    required this.orbitController,
    required this.progress,
    required this.failed,
    required this.size,
  });

  final AnimationController orbitController;
  final double? progress;
  final bool failed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .96,
            height: size * .96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: .08),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .12),
                  blurRadius: 45,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          SizedBox.square(
            dimension: size * .78,
            child: AnimatedBuilder(
              animation: orbitController,
              builder: (context, child) => Transform.rotate(
                angle: orbitController.value * 2 * 3.141592653589793,
                child: child,
              ),
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: colors.primary.withValues(alpha: .12),
                color: colors.primary,
              ),
            ),
          ),
          Container(
            width: size * .62,
            height: size * .62,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size * .34,
            height: size * .58,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(size * .08),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .28),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: EdgeInsets.all(size * .018),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(size * .055),
              ),
              child: Icon(
                progress == 1
                    ? Icons.check_rounded
                    : failed
                        ? Icons.error_outline_rounded
                        : Icons.south_rounded,
                size: size * .23,
                color: failed ? colors.error : colors.primary,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: orbitController,
                builder: (context, child) => Transform.rotate(
                  angle: orbitController.value * 2 * 3.141592653589793,
                  child: child,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: size * .055,
                      right: size * .12,
                      child: Icon(Icons.autorenew_rounded,
                          color: colors.primary, size: size * .14),
                    ),
                    Positioned(
                      bottom: size * .055,
                      left: size * .11,
                      child: Icon(Icons.autorenew_rounded,
                          color: colors.primary, size: size * .11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.current,
    required this.buildNumber,
    required this.latest,
  });

  final String current;
  final String buildNumber;
  final String? latest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _VersionPill(
          label: 'Current v$current ($buildNumber)',
          color: colors.surfaceContainerHighest,
        ),
        Icon(Icons.arrow_forward_rounded, color: colors.primary),
        _VersionPill(
          label: latest == null ? 'Latest' : 'New v$latest',
          color: colors.primaryContainer,
          foreground: colors.onPrimaryContainer,
        ),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill(
      {required this.label, required this.color, this.foreground});
  final String label;
  final Color color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(24)),
        child: Text(label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w800)),
      );
}

class _ReleaseNotesCard extends StatelessWidget {
  const _ReleaseNotesCard({required this.release});
  final GitHubAppRelease release;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notes = release.notes
        .split('\n')
        .map((line) => line.trim())
        .where(
            (line) => line.isNotEmpty && !line.startsWith('**Full Changelog**'))
        .map((line) => line
            .replaceFirst(RegExp(r'^[-*+]\s*'), '')
            .replaceAll('**', '')
            .replaceAll('`', ''))
        .take(6)
        .toList(growable: false);
    return Card(
      color: colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("What's new?",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (notes.isEmpty)
              Text(
                  'Improvements and fixes for a smoother FastStore experience.',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, height: 1.45))
            else
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: colors.primary, size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(note,
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  height: 1.35))),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress(
      {required this.receivedBytes, required this.totalBytes});
  final int receivedBytes;
  final int totalBytes;

  String _size(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = totalBytes > 0
        ? (receivedBytes / totalBytes).clamp(0, 1).toDouble()
        : null;
    return Column(
      children: [
        Text(
            progress == null
                ? 'Preparing download…'
                : '${(progress * 100).floor()}%',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900, color: colors.primary)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(value: progress, minHeight: 9),
        ),
        const SizedBox(height: 7),
        Text(
            '${_size(receivedBytes)} / ${totalBytes > 0 ? _size(totalBytes) : 'calculating'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant)),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .errorContainer
              .withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer)),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            textStyle:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      );
}
