import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_dialog.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/error_state.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/system_settings_model.dart';
import '../providers/settings_provider.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _companyNameController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  final _fcmServerKeyController = TextEditingController();
  final _defaultCommissionRateController = TextEditingController();
  final _defaultCreditLimitController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _serverDomainController = TextEditingController();

  bool _requireOrderNotes = false;
  bool _clearFcmKey = false;
  bool _obscureFcmKey = true;

  bool _isSaving = false;
  bool _isSavingDomain = false;
  bool _isClearingCache = false;
  bool _hasPopulatedForm = false;

  @override
  void initState() {
    super.initState();
    _serverDomainController.text = ApiConstants.serverOrigin;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyAddressController.dispose();
    _receiptFooterController.dispose();
    _fcmServerKeyController.dispose();
    _defaultCommissionRateController.dispose();
    _defaultCreditLimitController.dispose();
    _lowStockThresholdController.dispose();
    _serverDomainController.dispose();
    super.dispose();
  }

  void _populateFromModel(SystemSettingsModel model, {bool force = false}) {
    if (_hasPopulatedForm && !force) return;
    _hasPopulatedForm = true;
    _companyNameController.text = model.companyName;
    _companyPhoneController.text = model.companyPhone;
    _companyAddressController.text = model.companyAddress;
    _receiptFooterController.text = model.receiptFooterText;
    _fcmServerKeyController.clear();
    _clearFcmKey = false;
    _defaultCommissionRateController.text =
        Formatters.cleanNumberString(model.defaultCommissionRate);
    _defaultCreditLimitController.text = model.defaultCreditLimit.toString();
    _lowStockThresholdController.text =
        model.lowStockDefaultThreshold.toString();
    _requireOrderNotes = model.requireOrderNotes;
    _serverDomainController.text = model.serverDomain.isNotEmpty
        ? model.serverDomain
        : ApiConstants.serverOrigin;
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    final commissionRate = double.tryParse(
          _defaultCommissionRateController.text.trim().isEmpty
              ? '0'
              : _defaultCommissionRateController.text.trim(),
        ) ??
        -1;
    if (commissionRate < 0 || commissionRate > 100) {
      AppSnackbar.error(
        context,
        'ڕێژەی کۆمسیۆنی بنەڕەتی دەبێت لە نێوان 0 بۆ 100 بێت.',
      );
      return;
    }

    final creditLimit = int.tryParse(
          _defaultCreditLimitController.text.trim().isEmpty
              ? '0'
              : _defaultCreditLimitController.text.trim(),
        ) ??
        -1;
    if (creditLimit < 0) {
      AppSnackbar.error(
        context,
        'سنووری قەرزی بنەڕەتی نابێت کەمتر لە 0 بێت.',
      );
      return;
    }

    final lowStockThreshold = int.tryParse(
          _lowStockThresholdController.text.trim().isEmpty
              ? '10'
              : _lowStockThresholdController.text.trim(),
        ) ??
        -1;
    if (lowStockThreshold < 0) {
      AppSnackbar.error(
        context,
        'ئاستی کەمبوونی کاڵا نابێت کەمتر لە 0 بێت.',
      );
      return;
    }

    final trimmedDomain = _serverDomainController.text.trim();
    String? normalizedDomain;
    bool domainReachable = true;
    if (trimmedDomain.isNotEmpty) {
      normalizedDomain = ApiConstants.normalizeOrigin(trimmedDomain);
      if (normalizedDomain == null) {
        AppSnackbar.error(
          context,
          'تکایە دۆمەینێکی دروست بنووسە (نموونە: pos.gardi.click)',
        );
        return;
      }
      if (normalizedDomain != ApiConstants.serverOrigin) {
        domainReachable = await ApiConstants.verifyServerDomain(normalizedDomain);
        if (!mounted) return;
        if (!domainReachable) {
          final proceed = await AppDialog.showConfirm(
            context,
            title: 'دۆمەینەکە هێشتا وەڵام ناداتەوە',
            message:
                'لە ئێستادا پەیوەندی بە ($normalizedDomain) سەرکەوتوو نەبوو. ئایا دڵنیایت دەتەوێت لە باکێند پاشەکەوت بکرێت؟ ئامێرەکانی تر کاتێک دۆمەینە نوێیەکە کارا بوو خۆکار دەگوازرێنەوە سەری.',
            confirmText: 'بەڵێ، پاشەکەوتی بکە',
          );
          if (proceed != true || !mounted) return;
        }
      }
    }

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'company_name': _companyNameController.text.trim(),
      'company_phone': _companyPhoneController.text.trim(),
      'company_address': _companyAddressController.text.trim(),
      'receipt_footer_text': _receiptFooterController.text.trim(),
      'default_commission_rate': commissionRate,
      'default_credit_limit': creditLimit,
      'low_stock_default_threshold': lowStockThreshold,
      'require_order_notes': _requireOrderNotes,
    };

    if (normalizedDomain != null) {
      payload['server_domain'] = normalizedDomain;
    }

    if (_clearFcmKey) {
      payload['clear_fcm_server_key'] = true;
    } else if (_fcmServerKeyController.text.trim().isNotEmpty) {
      payload['fcm_server_key'] = _fcmServerKeyController.text.trim();
    }

    final error =
        await ref.read(systemSettingsProvider.notifier).saveSettings(payload);

    if (error == null &&
        normalizedDomain != null &&
        domainReachable &&
        normalizedDomain != ApiConstants.serverOrigin) {
      await ApiConstants.setCustomDomain(normalizedDomain, source: 'server');
      await _clearPusherConfigCache();
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }

    final updated = ref.read(systemSettingsProvider).valueOrNull;
    if (updated != null) {
      setState(() {
        _populateFromModel(updated, force: true);
      });
    }

    AppSnackbar.success(
      context,
      'ڕێکخستنەکان بە سەرکەوتوویی پاشەکەوت کران',
    );
  }

  Future<void> _handleClearCache() async {
    if (_isClearingCache) return;
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'پاککردنەوەی کاشی سیستەم',
      message:
          'ئایا دڵنیایت دەتەوێت کاشی سێرڤەر پاک بکەیتەوە؟ ئەم کردارە هیچ داتایەک ناسڕێتەوە.',
      confirmText: 'بەڵێ، پاکی بکەرەوە',
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearingCache = true);
    final error =
        await ref.read(systemSettingsProvider.notifier).clearServerCache();
    if (!mounted) return;
    setState(() => _isClearingCache = false);

    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(context, 'کاشی سیستەم بە سەرکەوتوویی پاککرایەوە');
    }
  }

  Future<void> _clearPusherConfigCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pusher_server_key');
      await prefs.remove('pusher_server_cluster');
    } catch (_) {}
  }

  Future<bool> _saveServerDomain({
    bool showSuccess = true,
    bool refetchIfChanged = true,
  }) async {
    if (_isSavingDomain) return false;

    final normalized = ApiConstants.normalizeOrigin(_serverDomainController.text);
    if (normalized == null) {
      AppSnackbar.error(
        context,
        'تکایە دۆمەینێکی دروست بنووسە (نموونە: pos.gardi.click)',
      );
      return false;
    }

    final previousOrigin = ApiConstants.serverOrigin;
    final hasBackendConnection = ref.read(systemSettingsProvider).hasValue;

    setState(() => _isSavingDomain = true);

    bool isReachable = normalized == previousOrigin;
    if (!isReachable) {
      isReachable = await ApiConstants.verifyServerDomain(normalized);
      if (!mounted) return false;
    }

    if (hasBackendConnection) {
      if (!isReachable) {
        setState(() => _isSavingDomain = false);
        final proceed = await AppDialog.showConfirm(
          context,
          title: 'دۆمەینەکە هێشتا وەڵام ناداتەوە',
          message:
              'لە ئێستادا پەیوەندی بە ($normalized) سەرکەوتوو نەبوو. ئایا دڵنیایت دەتەوێت لە باکێند پاشەکەوت بکرێت؟ ئامێرەکانی تر کاتێک دۆمەینە نوێیەکە کارا بوو خۆکار دەگوازرێنەوە سەری.',
          confirmText: 'بەڵێ، پاشەکەوتی بکە',
        );
        if (proceed != true || !mounted) return false;
        setState(() => _isSavingDomain = true);
      }

      final backendError = await ref
          .read(systemSettingsProvider.notifier)
          .saveSettings({'server_domain': normalized});

      if (!mounted) return false;
      if (backendError != null) {
        setState(() => _isSavingDomain = false);
        AppSnackbar.error(context, backendError);
        return false;
      }

      if (isReachable && normalized != previousOrigin) {
        await ApiConstants.setCustomDomain(normalized, source: 'server');
        await _clearPusherConfigCache();
      }

      if (!mounted) return true;
      setState(() {
        _serverDomainController.text = normalized;
        _serverDomainController.selection = TextSelection.collapsed(
          offset: _serverDomainController.text.length,
        );
        _isSavingDomain = false;
      });

      if (showSuccess && mounted) {
        AppSnackbar.success(
          context,
          isReachable
              ? 'دۆمەینی سێرڤەر بۆ هەموو سیستەمەکە پاشەکەوت کرا'
              : 'دۆمەینی نوێ لە باکێند پاشەکەوت کرا و کاتێک کارا بوو بۆ هەمووان جێگیر دەبێت',
        );
      }
      return true;
    }

    // Offline/error recovery mode: update local device origin so Owner can reconnect
    final error = await ApiConstants.setCustomDomain(normalized, source: 'local');
    if (error != null) {
      if (mounted) {
        setState(() => _isSavingDomain = false);
        AppSnackbar.error(context, error);
      }
      return false;
    }

    final changed = normalized != previousOrigin;
    if (changed) {
      await _clearPusherConfigCache();
    }

    if (!mounted) return true;

    setState(() {
      _serverDomainController.text = ApiConstants.serverOrigin;
      _serverDomainController.selection = TextSelection.collapsed(
        offset: _serverDomainController.text.length,
      );
      _isSavingDomain = false;
    });

    if (refetchIfChanged && (changed || ref.read(systemSettingsProvider).hasError)) {
      _hasPopulatedForm = false;
      await ref.read(systemSettingsProvider.notifier).fetchSettings();
      if (!mounted) return true;
      final latest = ref.read(systemSettingsProvider).valueOrNull;
      if (latest != null) {
        setState(() {
          _populateFromModel(latest, force: true);
        });
      }
    }

    if (showSuccess && mounted) {
      AppSnackbar.success(
        context,
        'دۆمەینی سێرڤەر بە سەرکەوتوویی پاشەکەوت کرا',
      );
    }
    return true;
  }

  Future<void> _resetServerDomain() async {
    if (_isSavingDomain) return;

    final previousOrigin = ApiConstants.serverOrigin;
    final hasBackendConnection = ref.read(systemSettingsProvider).hasValue;
    setState(() => _isSavingDomain = true);

    if (hasBackendConnection) {
      final backendError = await ref
          .read(systemSettingsProvider.notifier)
          .saveSettings({'reset_server_domain': true});
      if (!mounted) return;
      if (backendError != null) {
        setState(() => _isSavingDomain = false);
        AppSnackbar.error(context, backendError);
        return;
      }
    }

    await ApiConstants.resetCustomDomain();
    final newOrigin = ApiConstants.serverOrigin;
    final changed = newOrigin != previousOrigin;
    if (changed) {
      await _clearPusherConfigCache();
    }

    if (!mounted) return;
    setState(() {
      _serverDomainController.text = newOrigin;
      _serverDomainController.selection = TextSelection.collapsed(
        offset: _serverDomainController.text.length,
      );
      _isSavingDomain = false;
    });

    if (changed || ref.read(systemSettingsProvider).hasError) {
      _hasPopulatedForm = false;
      await ref.read(systemSettingsProvider.notifier).fetchSettings();
      if (!mounted) return;
      final latest = ref.read(systemSettingsProvider).valueOrNull;
      if (latest != null) {
        setState(() {
          _populateFromModel(latest, force: true);
        });
      }
    }

    if (mounted) {
      AppSnackbar.success(
        context,
        'دۆمەینی سێرڤەر گەڕێندرایەوە بۆ دۆخی بنەڕەتی',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Strict Owner-Only Protection
    if (user == null || !user.isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ڕێکخستنەکان', style: AppTextStyles.h2),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.dangerDark
                                : AppColors.danger)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_person_outlined,
                        size: 56,
                        color: isDark ? AppColors.dangerDark : AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'دەستڕاگەیشتن ڕەتکرایەوە',
                      style: AppTextStyles.h2.copyWith(
                        color: isDark ? AppColors.dangerDark : AppColors.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'بەشی ڕێکخستنەکانی سیستەم تەنها بۆ خاوەنکار (Owner) بەردەستە.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final settingsAsync = ref.watch(systemSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕێکخستنەکانی سیستەم', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'نوێکردنەوە',
            onPressed: () async {
              _hasPopulatedForm = false;
              await ref.read(systemSettingsProvider.notifier).fetchSettings();
              if (!mounted) return;
              final latest = ref.read(systemSettingsProvider).valueOrNull;
              if (latest != null) {
                setState(() {
                  _populateFromModel(latest, force: true);
                });
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ErrorState(
                    title: 'هەڵە لە بارکردنی ڕێکخستنەکان',
                    message: Formatters.cleanError(error),
                    retryText: 'دووبارە هەوڵبدەرەوە',
                    onRetry: () {
                      _hasPopulatedForm = false;
                      ref.read(systemSettingsProvider.notifier).fetchSettings();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildDomainSettingsCard(context, theme, isDark),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
        data: (settings) {
          _populateFromModel(settings);

          return RefreshIndicator(
            onRefresh: () async {
              _hasPopulatedForm = false;
              await ref.read(systemSettingsProvider.notifier).fetchSettings();
              if (!mounted) return;
              final latest = ref.read(systemSettingsProvider).valueOrNull;
              if (latest != null) {
                setState(() {
                  _populateFromModel(latest, force: true);
                });
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Owner badge header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.radiusMd,
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'ئەم بەشە تایبەتە بە خاوەنکار (${user.name}) و هەموو گۆڕانکارییەکان لە تۆماری چاودێریدا تۆمار دەکرێن.',
                                style: AppTextStyles.caption.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Section 1: Company Info
                      _buildSectionCard(
                        context,
                        title: 'زانیاری کۆمپانیا و پسوڵە',
                        icon: Icons.business_outlined,
                        color: theme.colorScheme.primary,
                        children: [
                          AppTextField(
                            controller: _companyNameController,
                            labelText: 'ناوی کۆمپانیا',
                            hintText: 'کۆمپانیای گەردی (GARDI ERP)',
                            prefixIcon: Icons.storefront_outlined,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _companyPhoneController,
                            labelText: 'ژمارەی مۆبایلی کۆمپانیا',
                            hintText: '0750 000 0000',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _companyAddressController,
                            labelText: 'ناونیشانی کۆمپانیا',
                            hintText: 'هەولێر - شەقامی ...',
                            prefixIcon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _receiptFooterController,
                            labelText: 'تێبینی خوارەوەی پسوڵە',
                            hintText: 'سوپاس بۆ مامەڵەکردنتان',
                            prefixIcon: Icons.receipt_long_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Section 2: Financial & Business Rules
                      _buildSectionCard(
                        context,
                        title: 'ڕێکخستنە دارایی و کارگێڕییەکان',
                        icon: Icons.tune_rounded,
                        color: isDark ? AppColors.infoDark : AppColors.info,
                        children: [
                          AppTextField(
                            controller: _defaultCommissionRateController,
                            labelText: 'ڕێژەی کۆمسیۆنی بنەڕەتی (%)',
                            hintText: '0',
                            prefixIcon: Icons.percent_rounded,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _defaultCreditLimitController,
                            labelText: 'سنووری قەرزی بنەڕەتی کڕیار (د.ع)',
                            hintText: '0',
                            prefixIcon: Icons.account_balance_wallet_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _lowStockThresholdController,
                            labelText:
                                'ئاستی بنەڕەتی ئاگادارکردنەوەی کەمبوونی کاڵا',
                            hintText: '10',
                            prefixIcon: Icons.inventory_2_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'پێویستبوونی تێبینی لە کاتی دروستکردنی پسوڵە',
                              style: AppTextStyles.bodyBold,
                            ),
                            subtitle: Text(
                              'ئەگەر چالاک بێت، نووسینی تێبینی لەسەر پسوڵە ناچاری دەبێت.',
                              style: AppTextStyles.caption.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: _requireOrderNotes,
                            onChanged: (val) {
                              setState(() => _requireOrderNotes = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Section 3: Push Notifications
                      _buildSectionCard(
                        context,
                        title: 'ئاگادارکردنەوەکان',
                        icon: Icons.notifications_outlined,
                        color:
                            isDark ? AppColors.successDark : AppColors.success,
                        children: [
                          _buildSecretFieldRow(
                            context: context,
                            controller: _fcmServerKeyController,
                            label: 'کلیلی FCM بۆ نۆتیفیکەیشن',
                            isConfigured:
                                settings.fcmServerKeyConfigured && !_clearFcmKey,
                            obscure: _obscureFcmKey,
                            onToggleObscure: () {
                              setState(
                                  () => _obscureFcmKey = !_obscureFcmKey);
                            },
                            onClearSecret: settings.fcmServerKeyConfigured
                                ? () {
                                    setState(() {
                                      _clearFcmKey = !_clearFcmKey;
                                      if (_clearFcmKey) {
                                        _fcmServerKeyController.clear();
                                      }
                                    });
                                  }
                                : null,
                            isMarkedForClear: _clearFcmKey,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Section 4: Server Domain Settings (Local Device Config)
                      _buildDomainSettingsCard(context, theme, isDark),
                      const SizedBox(height: AppSpacing.md),

                      // Section 5: Appearance & System Maintenance
                      _buildSectionCard(
                        context,
                        title: 'ڕوکار و چاکسازی سیستەم',
                        icon: Icons.settings_suggest_outlined,
                        color:
                            isDark ? AppColors.purpleDark : AppColors.purple,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.dark_mode_outlined),
                            title: const Text(
                              'دۆخی تاریک (Dark Mode)',
                              style: AppTextStyles.bodyBold,
                            ),
                            value:
                                ref.watch(themeModeProvider) == ThemeMode.dark,
                            onChanged: (_) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .toggleTheme();
                            },
                          ),
                          const Divider(),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'پاککردنەوەی کاشی سێرڤەر',
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'بۆ نوێکردنەوەی خێرای کاش و ڕێکخستنەکانی باکێند.',
                                      style: AppTextStyles.caption.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              AppButton(
                                text: 'پاککردنەوەی کاش',
                                icon: Icons.cleaning_services_outlined,
                                type: AppButtonType.outline,
                                size: AppButtonSize.sm,
                                isLoading: _isClearingCache,
                                onPressed: _handleClearCache,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppButton(
                        text: 'پاشەکەوتکردنی ڕێکخستنەکان',
                        icon: Icons.save_outlined,
                        size: AppButtonSize.lg,
                        isLoading: _isSaving,
                        onPressed: _saveSettings,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDomainSettingsCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    final normalizedPreview =
        ApiConstants.normalizeOrigin(_serverDomainController.text);
    final previewApiUrl = normalizedPreview != null
        ? '$normalizedPreview/api/v1'
        : ApiConstants.baseUrl;
    final settingsModel = ref.read(systemSettingsProvider).valueOrNull;
    final isCustom = ApiConstants.hasCustomDomain ||
        (settingsModel != null && settingsModel.serverDomain.isNotEmpty);

    return _buildSectionCard(
      context,
      title: 'دۆمەین و ناونیشانی سێرڤەر',
      icon: Icons.language_rounded,
      color: isDark ? AppColors.warningDark : AppColors.warning,
      children: [
        Text(
          'لە کاتی گۆڕینی دۆمەینی ساڵانە، دۆمەینی نوێ لێرە دابنێ و پاشەکەوتی بکە؛ بە شێوەیەکی خۆکار لەسەر هەموو ئامێرەکانی سیستەم جێگیر دەبێت بێ پێویستی بە گۆڕینی کۆد یان دەستکاری لەلایەن کارمەندەکانەوە.',
          style: AppTextStyles.caption.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _serverDomainController,
          labelText: 'دۆمەینی سێرڤەر (Domain / URL)',
          hintText: 'https://pos.gardi.click',
          prefixIcon: Icons.dns_outlined,
          keyboardType: TextInputType.url,
          textAlign: TextAlign.left,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            borderRadius: AppRadius.radiusSm,
            border: Border.all(
              color: normalizedPreview == null &&
                      _serverDomainController.text.trim().isNotEmpty
                  ? (isDark ? AppColors.dangerDark : AppColors.danger)
                  : theme.colorScheme.outline.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Text(
                'ناونیشانی API:',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    normalizedPreview == null &&
                            _serverDomainController.text.trim().isNotEmpty
                        ? 'دۆمەینەکە نادروستە'
                        : previewApiUrl,
                    style: AppTextStyles.caption.copyWith(
                      color: normalizedPreview == null &&
                              _serverDomainController.text.trim().isNotEmpty
                          ? (isDark ? AppColors.dangerDark : AppColors.danger)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.start,
          children: [
            AppButton(
              text: 'پاشەکەوتکردنی دۆمەین',
              icon: Icons.check_circle_outline_rounded,
              size: AppButtonSize.sm,
              isLoading: _isSavingDomain,
              onPressed: () => _saveServerDomain(),
            ),
            if (isCustom)
              AppButton(
                text: 'گەڕاندنەوە بۆ بنەڕەتی',
                icon: Icons.restart_alt_rounded,
                type: AppButtonType.outline,
                size: AppButtonSize.sm,
                onPressed: _isSavingDomain ? null : _resetServerDomain,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: AppTextStyles.h3),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSecretFieldRow({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required bool isConfigured,
    required bool obscure,
    required VoidCallback onToggleObscure,
    VoidCallback? onClearSecret,
    bool isMarkedForClear = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = isMarkedForClear
        ? (isDark ? AppColors.dangerDark : AppColors.danger)
        : (isConfigured
            ? (isDark ? AppColors.successDark : AppColors.success)
            : theme.colorScheme.onSurfaceVariant);

    final statusText = isMarkedForClear
        ? 'دوای پاشەکەوتکردن دەسڕدرێتەوە'
        : (isConfigured ? 'تۆمارکراوە' : 'تۆمارنەکراوە');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onClearSecret != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClearSecret,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        isMarkedForClear ? 'پاشگەزبوونەوە' : 'سڕینەوە',
                        style: AppTextStyles.caption.copyWith(
                          color: isMarkedForClear
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? AppColors.dangerDark
                                  : AppColors.danger),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: controller,
          hintText: isConfigured
              ? 'بۆ گۆڕین کلیلێکی نوێ بنووسە (بە بەتاڵی وازی لێبهێنە بۆ مانەوەی کۆن)'
              : 'کلیل یان تۆکن بنووسە...',
          prefixIcon: Icons.vpn_key_outlined,
          obscureText: obscure,
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
            onPressed: onToggleObscure,
          ),
        ),
      ],
    );
  }
}
