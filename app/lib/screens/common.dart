import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

Future<T?> go<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// Page frame: dotted paper, a back button and a Bungee title.
class PopPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? trailing;
  final Color background;
  final Color dot;
  const PopPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.trailing,
    this.background = Pop.paper,
    this.dot = const Color(0x5519C3FF),
  });

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Scaffold(
      body: DottedPaper(
        color: background,
        dot: dot,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    InkIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: tr('back', lang),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontFamily: Pop.display, fontSize: 21, height: 1.1)),
                          if (subtitle != null)
                            Text(subtitle!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
