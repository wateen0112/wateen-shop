/// Permission matrix — the counterpart of the `.perm-block` markup in `pages/Users.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../core/theme.dart';

class PermissionMatrix extends StatelessWidget {
  const PermissionMatrix({
    super.key,
    required this.groups,
    required this.selected,
    required this.onToggle,
  });

  final Map<String, List<Permission>> groups;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'الصلاحيات',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        ...groups.entries.map(
          (MapEntry<String, List<Permission>> entry) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.softGrey,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                ...entry.value.map(
                  (Permission p) => _PermRow(
                    label: p.label,
                    checked: selected.contains(p.key),
                    onChanged: () => onToggle(p.key),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({required this.label, required this.checked, required this.onChanged});

  final String label;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onChanged(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      ),
    );
  }
}
