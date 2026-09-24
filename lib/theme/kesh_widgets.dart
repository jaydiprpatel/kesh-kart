import 'package:flutter/material.dart';
import 'package:kesh_kart/theme/keshkart_theme.dart';
import 'package:shimmer/shimmer.dart';

class KeshCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final VoidCallback? onTap;

  const KeshCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius = 20.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? KeshColors.cardSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: KeshColors.borderIvory, width: 1),
        boxShadow: [
          BoxShadow(
            color: KeshColors.navyPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

class KeshBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;

  const KeshBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = KeshColors.chipBackground,
    this.textColor = KeshColors.navyPrimary,
  });

  factory KeshBadge.verified() {
    return const KeshBadge(
      label: 'Verified',
      icon: Icons.verified,
      backgroundColor: Color(0xFFE8F5E9),
      textColor: KeshColors.emeraldSuccess,
    );
  }

  factory KeshBadge.open() {
    return const KeshBadge(
      label: 'Open Now',
      icon: Icons.circle,
      backgroundColor: Color(0xFFE8F5E9),
      textColor: KeshColors.emeraldSuccess,
    );
  }

  factory KeshBadge.closed() {
    return const KeshBadge(
      label: 'Closed',
      icon: Icons.circle,
      backgroundColor: Color(0xFFFFEBEE),
      textColor: Color(0xFFD32F2F),
    );
  }

  factory KeshBadge.pro() {
    return const KeshBadge(
      label: 'PRO',
      icon: Icons.workspace_premium,
      backgroundColor: Color(0xFFFFF8E1),
      textColor: KeshColors.proGold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class KeshButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;
  final bool isOutlined;
  final bool isGold;
  final double? width;

  const KeshButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
    this.isOutlined = false,
    this.isGold = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = KeshColors.signatureCoral;
    Color fg = Colors.white;
    BorderSide border = BorderSide.none;

    if (isGold) {
      bg = KeshColors.proGold;
    } else if (isSecondary) {
      bg = KeshColors.navyPrimary;
    } else if (isOutlined) {
      bg = Colors.transparent;
      fg = KeshColors.navyPrimary;
      border = const BorderSide(color: KeshColors.navyPrimary, width: 1.5);
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: isOutlined ? 0 : 2,
          shadowColor: bg.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border,
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class KeshHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback? onNotificationTap;

  const KeshHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.avatarUrl,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KeshColors.signatureCoral.withValues(alpha: 0.12),
                  border: Border.all(
                    color: KeshColors.signatureCoral,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: KeshColors.signatureCoral,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: KeshColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: KeshColors.navyPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: onNotificationTap,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: KeshColors.borderIvory),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: KeshColors.navyPrimary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeshSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const KeshSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: KeshColors.chipBackground,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class KeshEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onAction;

  const KeshEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.search_off_rounded,
    this.buttonLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KeshColors.chipBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: KeshColors.signatureCoral),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: KeshColors.navyPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KeshColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (buttonLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              KeshButton(label: buttonLabel!, onPressed: onAction!, width: 200),
            ],
          ],
        ),
      ),
    );
  }
}
