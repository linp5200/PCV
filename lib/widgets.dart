// PCV · 公共组件
import 'package:flutter/material.dart';

import 'theme.dart';

Color tintOf(Color c, bool dark) => c.withValues(alpha: dark ? .13 : .10);

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final Color bg;
  final double size;
  final double iconSize;
  const IconTile({
    super.key,
    required this.icon,
    required this.fg,
    required this.bg,
    this.size = 34,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

class PcvCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  const PcvCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: p.dark
            ? null
            : [
                BoxShadow(
                  color: p.t1.withValues(alpha: .04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding ?? const EdgeInsets.all(16), child: child)
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
    );
    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final double fontSize;
  const Pill({
    super.key,
    required this.text,
    required this.fg,
    required this.bg,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1.1,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .6,
          color: p.t3,
        ),
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  const SettingRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          IconTile(icon: icon, fg: iconColor, bg: iconBg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: titleColor ?? p.t1,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: p.t3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right, size: 18, color: p.t4),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class RowDivider extends StatelessWidget {
  final double indent;
  const RowDivider({super.key, this.indent = 62});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: p.border),
    );
  }
}

class PcvNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const PcvNavBar({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    const items = [
      (Icons.home_outlined, Icons.home_rounded, '首页'),
      (Icons.folder_outlined, Icons.folder_rounded, '文件'),
      (Icons.search_outlined, Icons.search_rounded, '搜索'),
      (Icons.settings_outlined, Icons.settings_rounded, '设置'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i == index ? items[i].$2 : items[i].$1,
                          size: 22,
                          color: i == index ? accent : p.t3,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == index ? accent : p.t3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============ 文件图标 ============

(IconData, Color) fileStyleFor(String name, Pal p) {
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  switch (ext) {
    case 'py':
      return (Icons.code_rounded, p.yellow);
    case 'c':
    case 'h':
    case 'cc':
    case 'cpp':
    case 'hpp':
    case 'js':
    case 'ts':
    case 'dart':
    case 'go':
    case 'rs':
    case 'kt':
    case 'java':
    case 'gradle':
      return (Icons.code_rounded, p.blue);
    case 'md':
    case 'markdown':
      return (Icons.article_outlined, p.purple);
    case 'json':
    case 'yaml':
    case 'yml':
    case 'toml':
    case 'ini':
    case 'conf':
      return (Icons.data_object_rounded, p.teal);
    case 'sh':
    case 'bash':
      return (Icons.terminal_rounded, p.green);
    case 'html':
    case 'htm':
      return (Icons.html_rounded, p.orange);
    case 'css':
    case 'scss':
      return (Icons.css_rounded, p.cyan);
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return (Icons.image_outlined, p.purple);
    case 'txt':
    case 'log':
      return (Icons.notes_rounded, p.t3);
    default:
      return (Icons.insert_drive_file_outlined, p.t3);
  }
}
