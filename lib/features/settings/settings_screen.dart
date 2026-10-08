import "package:awesome_dialog/awesome_dialog.dart";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:iconsax/iconsax.dart";
import "package:in_app_review/in_app_review.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../core/constants/app_colors.dart";
import "../../core/models/item_model.dart";
import "../../core/services/auth_service.dart";
import "../../core/services/localization_service.dart";
import "../../core/utils/snackbar_helper.dart";
import "../shell/main_shell.dart";
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import "../../shared/providers/app_provider.dart";
import "../profile/edit_profile_screen.dart";
import "legal_document_screen.dart";

class SettingsScreen extends StatefulWidget {
  final UserProfileModel? profile;

  const SettingsScreen({super.key, this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();

  String _appVersion = "";
  String _loginType = "";
  UserProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadVersion();
    _loadLoginType();
  }

  Future<void> _loadLoginType() async {
    final loginType = await _storage.read(key: "login_type") ?? "";
    if (!mounted) return;
    setState(() => _loginType = loginType);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentName: profile.name,
          currentPhone: profile.phone,
          currentType: profile.type,
          currentAvatar: profile.avatar,
          currentUid: profile.uid,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rateApp() async {
    final InAppReview inAppReview = InAppReview.instance;

    try {
      // Native App Store / Play Store review dialog inside the app.
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return;
      }

      // Store listing deep-link fallback when in-app API is blocked by quota,
      // but a store is still present on the device.
      try {
        await inAppReview.openStoreListing();
        return;
      } catch (_) {
        // Fall through to snackbar.
      }

      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr("settings.no_store_for_rating"),
        type: SnackType.info,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr("settings.no_store_for_rating"),
        type: SnackType.info,
      );
    }
  }

  void _logout() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: tr("settings.logout"),
      desc: tr("settings.logout_confirm"),
      btnCancelText: tr("common.cancel"),
      btnOkText: tr("settings.logout"),
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      },
    ).show();
  }

  void _deleteAccount() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: tr("settings.delete_account"),
      desc: tr("settings.delete_account_confirm"),
      btnCancelText: tr("common.cancel"),
      btnOkText: tr("settings.delete_permanently"),
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final uid = await AuthService.getCurrentUID();
        if (uid == null || uid.isEmpty) {
          _showSnack(tr("settings.user_not_identified"), isError: true);
          return;
        }

        try {
          final response = await Dio().post(
            "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
            data: FormData.fromMap({
              "action": "delete_account_permit",
              "uid": uid,
            }),
          );

          if (response.data["success"] == true) {
            await AuthService.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()),
              (_) => false,
            );
          } else {
            _showSnack(
              response.data["error"]?.toString() ??
                  tr("settings.delete_failed"),
              isError: true,
            );
          }
        } catch (e) {
          _showSnack(tr("settings.delete_error"), isError: true);
        }
      },
    ).show();
  }

  void _showSnack(String message, {bool isError = false}) {
    showAppSnackbar(
      context,
      message: message,
      type: isError ? SnackType.error : SnackType.success,
    );
  }

  /// بعد تغيير اللغة نرجع للـ shell كاملاً — ده يُعيد بناء كل الشاشات
  /// فيه تلقائياً وتظهر ترجمات tr() الجديدة فوراً
  void _reloadCurrentScreen(BuildContext ctx) {
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 4)),
      (_) => false,
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer<AppProvider>(
        builder: (context, appProvider, _) => Container(
          decoration: BoxDecoration(
            color: sheetContext.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr("settings.choose_language"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text("العربية"),
                trailing: appProvider.language == "ar"
                    ? const Icon(Iconsax.tick_circle, color: AppColors.primary)
                    : null,
                onTap: () async {
                  if (appProvider.language == "ar") {
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  await appProvider.setLanguage("ar");
                  if (context.mounted) _reloadCurrentScreen(context);
                },
              ),
              ListTile(
                title: const Text("English"),
                trailing: appProvider.language == "en"
                    ? const Icon(Iconsax.tick_circle, color: AppColors.primary)
                    : null,
                onTap: () async {
                  if (appProvider.language == "en") {
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  await appProvider.setLanguage("en");
                  if (context.mounted) _reloadCurrentScreen(context);
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Align(
        // Directional حتى ينقلب مع اتجاه اللغة
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: context.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.appCardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, color: context.appCardBorder);

  Widget _listTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? context.appTextPrimary,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appSurface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            tr("settings.title"),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            // سهم الرجوع يتبع اتجاه اللغة
            icon: Icon(
              context.isArabicLocale
                  ? Iconsax.arrow_right_3
                  : Iconsax.arrow_left_2,
              color: AppColors.primary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _sectionHeader(tr("settings.account")),
            _settingsCard(
              children: [
                _listTile(
                  icon: Iconsax.edit,
                  title: tr("settings.edit_profile"),
                  onTap: _profile != null ? _openEditProfile : null,
                ),
                if (_loginType == "Email") ...[
                  _divider(),
                  _listTile(
                    icon: Iconsax.lock,
                    title: tr("settings.change_password"),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tr("settings.soon"),
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            _sectionHeader(tr("settings.preferences")),
            _settingsCard(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.moon,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    tr("settings.dark_mode"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: appProvider.darkMode,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    await appProvider.setDarkMode(val);
                  },
                ),
                _divider(),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.notification,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    tr("settings.notifications"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: appProvider.notificationsEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: appProvider.setNotificationsEnabled,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.language_square,
                  title: tr("settings.language"),
                  // أسماء اللغات تبقى بلغتها الأصلية دائماً
                  subtitle: appProvider.language == "ar"
                      ? "العربية"
                      : "English",
                  trailing: Icon(
                    context.isArabicLocale
                        ? Iconsax.arrow_left_2
                        : Iconsax.arrow_right_3,
                    size: 18,
                  ),
                  onTap: _showLanguageSheet,
                ),
              ],
            ),
            _sectionHeader(tr("settings.about")),
            _settingsCard(
              children: [
                _listTile(
                  icon: Iconsax.shield,
                  title: tr("settings.privacy_policy"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalDocumentScreen(
                          type: LegalDocumentType.privacyPolicy,
                        ),
                      ),
                    );
                  },
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.document,
                  title: tr("settings.terms_of_use"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalDocumentScreen(
                          type: LegalDocumentType.termsOfUse,
                        ),
                      ),
                    );
                  },
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.star,
                  title: tr("settings.rate_app"),
                  onTap: _rateApp,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.info_circle,
                  title: tr("settings.version"),
                  trailing: Text(
                    _appVersion.isNotEmpty ? _appVersion : "1.2.6",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            _sectionHeader(tr("settings.account")),
            _settingsCard(
              children: [
                _listTile(
                  icon: Iconsax.logout,
                  title: tr("settings.logout"),
                  iconColor: AppColors.primary,
                  titleColor: AppColors.primary,
                  onTap: _logout,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.trash,
                  title: tr("settings.delete_account"),
                  iconColor: AppColors.error,
                  titleColor: AppColors.error,
                  onTap: _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
