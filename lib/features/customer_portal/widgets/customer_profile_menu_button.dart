import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/customer_avatar.dart';
import '../../../core/components/gardi_logo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';

class CustomerProfileMenuButton extends ConsumerStatefulWidget {
  final VoidCallback onLogout;
  final double logoHeight;

  const CustomerProfileMenuButton({
    super.key,
    required this.onLogout,
    this.logoHeight = 32,
  });

  @override
  ConsumerState<CustomerProfileMenuButton> createState() =>
      _CustomerProfileMenuButtonState();
}

class _CustomerProfileMenuButtonState
    extends ConsumerState<CustomerProfileMenuButton> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _isOpen = false;

  Future<void> _openDropdown() async {
    if (_isOpen) return;

    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final anchorRect = offset & renderBox.size;

    setState(() => _isOpen = true);
    ref.read(authProvider.notifier).refreshCurrentUserSilently();

    await Navigator.of(context, rootNavigator: true).push<void>(
      _CustomerProfileDropdownRoute(
        anchorRect: anchorRect,
        isRtl: Directionality.of(context) == TextDirection.rtl,
        onLogout: widget.onLogout,
      ),
    );

    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: 'پڕۆفایڵی هەژمار',
      child: Material(
        key: _anchorKey,
        color: _isOpen
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _openDropdown,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOpen
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GardiLogo(height: widget.logoHeight),
                const SizedBox(width: 2),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _isOpen
                        ? AppColors.primary
                        : theme.colorScheme.onSurfaceVariant,
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

class _CustomerProfileDropdownRoute extends PopupRoute<void> {
  final Rect anchorRect;
  final bool isRtl;
  final VoidCallback onLogout;

  _CustomerProfileDropdownRoute({
    required this.anchorRect,
    required this.isRtl,
    required this.onLogout,
  });

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.16);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'داخستن';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    final double menuWidth = (screenWidth - 24).clamp(240.0, 330.0);
    final double rawLeft = isRtl
        ? (anchorRect.right - menuWidth)
        : anchorRect.left;
    final double left = rawLeft.clamp(12.0, screenWidth - menuWidth - 12.0);
    final double top = (anchorRect.bottom + 8).clamp(
      mediaQuery.padding.top + 8,
      (screenHeight - 220.0).clamp(mediaQuery.padding.top + 8, screenHeight),
    );
    final double maxHeight =
        (screenHeight - top - mediaQuery.padding.bottom - 16).clamp(
          180.0,
          520.0,
        );

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: left,
            width: menuWidth,
            child: FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  curvedAnimation,
                ),
                alignment: isRtl ? Alignment.topRight : Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: _CustomerProfileDropdownCard(
                    onClose: () => Navigator.of(context).pop(),
                    onLogout: onLogout,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerProfileDropdownCard extends ConsumerWidget {
  final VoidCallback onClose;
  final VoidCallback onLogout;

  const _CustomerProfileDropdownCard({
    required this.onClose,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider.select((s) => s.user));
    final customer = user?.customer;

    final String displayName = (customer?.name.trim().isNotEmpty ?? false)
        ? customer!.name.trim()
        : (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'کڕیار';

    final String? contactPerson =
        (customer?.customerName?.trim().isNotEmpty ?? false) &&
            customer!.customerName!.trim() != displayName
        ? customer.customerName!.trim()
        : null;

    final String rawCustomerPhone = customer?.phone?.trim() ?? '';
    final bool hasValidPhone = rawCustomerPhone.isNotEmpty &&
        !rawCustomerPhone.toUpperCase().startsWith('CUSTPORTAL-');
    final String phoneDisplay = hasValidPhone ? rawCustomerPhone : 'نیە';

    final String? address = (customer?.address?.trim().isNotEmpty ?? false)
        ? customer!.address!.trim()
        : null;

    final String? routeName =
        (customer?.route?.name.trim().isNotEmpty ?? false)
        ? customer!.route!.name.trim()
        : null;

    final String? imageUrl =
        (customer?.imageUrl?.trim().isNotEmpty ?? false)
        ? customer!.imageUrl!.trim()
        : user?.imageUrl?.trim();

    final double debt = customer?.balance ?? 0.0;
    final bool hasDebt = debt > 0;

    return Material(
      color: isDark ? const Color(0xFF1E242E) : Colors.white,
      elevation: 14,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? const Color(0xFF333E4F)
                : theme.dividerColor.withValues(alpha: 0.35),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Customer Avatar & Primary Identity
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1),
                      AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.03),
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                            ),
                            child: CustomerAvatar(
                              imageUrl: imageUrl,
                              size: 58,
                              borderRadius: 15,
                              placeholderIcon: Icons.storefront_rounded,
                              iconSize: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    fontSize: 15,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (contactPerson != null) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'بەڕێز : $contactPerson',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: theme.colorScheme.onSurfaceVariant,
                      tooltip: 'داخستن',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),

              // 2. Profile Contact / Location Info & Debt
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'مۆبایل',
                      value: phoneDisplay,
                      isLtr: hasValidPhone,
                    ),
                      if (routeName != null)
                        _ProfileInfoRow(
                          icon: Icons.alt_route_rounded,
                          label: 'ڕاوت',
                          value: routeName,
                        ),
                      if (address != null)
                        _ProfileInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'ناونیشان',
                          value: address,
                        ),
                      if (hasDebt) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(
                              alpha: isDark ? 0.16 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(
                                alpha: isDark ? 0.45 : 0.28,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'قەرزی ئێستا',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isDark
                                            ? Colors.red.shade200
                                            : AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      Formatters.currency(debt),
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: isDark
                                            ? Colors.red.shade300
                                            : AppColors.danger,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Divider(height: 1),
              ),

              // 3. Compact Icon-Only Logout Button at bottom-left
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: 'چوونەدەرەوە',
                    child: Material(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          onClose();
                          onLogout();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLtr;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLtr = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.caption.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textDirection: isLtr ? TextDirection.ltr : null,
              textAlign: isLtr ? TextAlign.end : TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
