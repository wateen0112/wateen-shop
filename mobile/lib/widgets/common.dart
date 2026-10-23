/// Shared UI building blocks — the Flutter counterpart of the CSS classes
/// (`.card`, `.field`, `.btn`, `.pill`, `.msg`, `.kpi-card`, `.empty-state`…).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// The app is a mobile-first, max-560pt-wide column (like `.app { max-width: 560px }`).
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children, this.padding = const EdgeInsets.all(16)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: padding.add(const EdgeInsets.only(bottom: 24)),
          children: children,
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, this.title, this.subtitle, this.trailing});

  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(title!, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

enum MsgType { success, error }

class MsgBox extends StatelessWidget {
  const MsgBox({super.key, required this.text, this.type = MsgType.error});

  final String text;
  final MsgType type;

  @override
  Widget build(BuildContext context) {
    final bool ok = type == MsgType.success;
    final Color bg = ok ? AppColors.softSuccess : AppColors.softDanger;
    final Color fg = ok ? AppColors.success : AppColors.danger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.suffix,
    this.textInputAction,
    this.autofocus = false,
    this.obscureText = false,
    this.focusNode,
    this.onSubmitted,
    this.style,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscureText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final TextField field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      textInputAction: textInputAction,
      autofocus: autofocus,
      obscureText: obscureText,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      style: style ?? const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      ),
    );

    if (label == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: field);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label!,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          field,
        ],
      ),
    );
  }
}

/// Two-column grid used by the forms (`.form-grid`).
class FormGrid extends StatelessWidget {
  const FormGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i % 2 == 0 && i + 1 < children.length) spaced.add(const SizedBox(width: 10));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < spaced.length; i += 2)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  spaced[i],
                  if (i + 1 < spaced.length) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(child: spaced[i + 1]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum PillKind { normal, ok, warn, danger }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.kind = PillKind.normal});

  final String text;
  final PillKind kind;

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final Color bg;
    switch (kind) {
      case PillKind.ok:
        fg = AppColors.success;
        bg = AppColors.softSuccess;
        break;
      case PillKind.warn:
        fg = AppColors.warn;
        bg = AppColors.softWarn;
        break;
      case PillKind.danger:
        fg = AppColors.danger;
        bg = AppColors.softDanger;
        break;
      case PillKind.normal:
        fg = AppColors.primary;
        bg = AppColors.primarySoft;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 30, color: AppColors.muted),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class HintText extends StatelessWidget {
  const HintText(this.text, {super.key, this.warn = false, this.center = false});

  final String text;
  final bool warn;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: warn ? AppColors.warn : AppColors.muted,
          fontSize: 12,
          fontWeight: warn ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

enum AppButtonKind { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.block = true,
    this.small = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;
  final bool block;
  final bool small;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (kind) {
      case AppButtonKind.primary:
        bg = AppColors.primary;
        fg = Colors.white;
        break;
      case AppButtonKind.secondary:
        bg = AppColors.primarySoft;
        fg = AppColors.primary;
        break;
      case AppButtonKind.danger:
        bg = AppColors.softDanger;
        fg = AppColors.danger;
        break;
    }

    final Widget button = ElevatedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : (icon == null ? const SizedBox.shrink() : Icon(icon, size: small ? 16 : 19, color: fg)),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.6),
        disabledForegroundColor: fg.withValues(alpha: 0.8),
        minimumSize: Size(block ? double.infinity : 0, small ? 38 : 50),
        padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: TextStyle(fontSize: small ? 13 : 15, fontWeight: FontWeight.w700),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: block ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Dropdown styled like the other fields (`.field > select`).
class AppDropdown extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(AppRadius.field),
                items: items,
                onChanged: (String? v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon button used inside the app bar and the sheets (`.icon-btn`).
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, this.onPressed, this.color, this.background});

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 19, color: color ?? Colors.white),
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = 'ابحث',
    this.onScan,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onScan;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
          suffixIcon: onScan == null
              ? null
              : IconButton(
                  onPressed: onScan,
                  icon: const Icon(Icons.photo_camera_rounded, size: 19, color: AppColors.primary),
                  tooltip: 'مسح بالباركود',
                ),
        ),
      ),
    );
  }
}

/// KPI tile (`.kpi-card`).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.foot,
    this.icon,
    this.iconColor,
    this.highlight = false,
    this.negative = false,
  });

  final String label;
  final String value;
  final String? foot;
  final IconData? icon;
  final Color? iconColor;
  final bool highlight;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final Color valueColor = negative
        ? AppColors.danger
        : (highlight ? AppColors.primary : AppColors.ink);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primarySoft : AppColors.softGrey,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: valueColor),
                ),
                if (foot != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(foot!, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog — the equivalent of `window.confirm`.
Future<bool> confirmDialog(BuildContext context, String message) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      title: const Text('تأكيد', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(fontSize: 14)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Simple toast for transient feedback.
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Filters that only allow digits (and a single dot for decimals).
List<TextInputFormatter> numericFormatters({bool allowDecimal = true}) => <TextInputFormatter>[
      FilteringTextInputFormatter.allow(
        RegExp(allowDecimal ? r'^\d*\.?\d*' : r'^\d*'),
      ),
    ];
