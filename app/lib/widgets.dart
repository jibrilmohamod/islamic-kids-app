import 'package:flutter/material.dart';

import 'app_state.dart';
import 'strings.dart';

/// Right-to-left Arabic, large and spaced for young readers.
class ArabicText extends StatelessWidget {
  final String text;
  final double size;
  const ArabicText(this.text, {super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: size, height: 1.9, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

/// Shows where a text came from, with the version where the source has one.
class SourceLabel extends StatelessWidget {
  final String sourceKey;
  final String? extra;
  const SourceLabel(this.sourceKey, {super.key, this.extra});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final info = state.bundle?.source(sourceKey);
    final parts = [
      tr('source', state.lang),
      info?.label ?? sourceKey,
      if (extra != null && extra!.isNotEmpty) extra!,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        parts.join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// Placeholder for the illustrated scene. Real art replaces the gradient; the
/// title stays an overlay so no text is ever baked into an image.
class SceneHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Color> colors;
  const SceneHeader({super.key, required this.title, this.subtitle, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(subtitle!, style: const TextStyle(fontSize: 30, color: Colors.white)),
            ),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

const sceneNight = [Color(0xFF1B2A4A), Color(0xFF3E5C8A)];
const sceneDesert = [Color(0xFFB5652B), Color(0xFFE8B66B)];
const sceneGarden = [Color(0xFF2F6B4F), Color(0xFF7DB38A)];

class ContentCard extends StatelessWidget {
  final Widget child;
  const ContentCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class Heading extends StatelessWidget {
  final String text;
  const Heading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
