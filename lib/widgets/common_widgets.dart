// ─────────────────────────────────────────────────────────────
// common_widgets.dart  –  Small reusable widgets
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme.dart';

// ── Section heading ───────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      );
}

// ── Muted subtitle ─────────────────────────────────────────────
class SubTitle extends StatelessWidget {
  final String text;
  const SubTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.mutedForeground,
        ),
      );
}

// ── Chip / badge ───────────────────────────────────────────────
class AppBadge extends StatelessWidget {
  final String label;
  final bool outlined;
  final Color? color;

  const AppBadge(
    this.label, {
    super.key,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (outlined ? Colors.transparent : AppTheme.secondary);
    final fg = color != null ? Colors.white : const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: outlined
            ? Border.all(color: AppTheme.border)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

// ── Network image with a grey placeholder ─────────────────────
class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: AppTheme.secondary,
          child: const Icon(Icons.broken_image_outlined,
              color: AppTheme.mutedForeground),
        ),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                width: width,
                height: height,
                color: AppTheme.secondary,
              ),
      );
}

// ── Member color avatar ────────────────────────────────────────
class MemberAvatar extends StatelessWidget {
  final String name;
  final int colorIndex;
  final double radius;

  const MemberAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.memberColors[colorIndex % AppTheme.memberColors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Stat card (used in Dashboard and Scrapbook) ───────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubTitle(label),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (icon != null)
                Icon(icon, size: 28, color: AppTheme.mutedForeground),
            ],
          ),
        ),
      );
}
