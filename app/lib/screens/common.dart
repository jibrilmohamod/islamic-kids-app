import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'now_playing.dart';

Future<T?> go<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// Page frame (canvas row G): a striped hero band with the title, then the
/// body on dotted paper.
class PopPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? trailing;
  final Color background;
  final Color dot;

  /// The hero band's two glazes, top and bottom.
  final Color bandTop;
  final Color bandBottom;
  const PopPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.trailing,
    this.background = Pop.paper,
    this.dot = const Color(0x5519C3FF),
    this.bandTop = Pop.violet,
    this.bandBottom = Pop.pink,
  });

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Scaffold(
      // Recitation that carries on from another screen shows here (ADR 0002).
      bottomNavigationBar: const NowPlayingBar(),
      body: DottedPaper(
        color: background,
        dot: dot,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroBand(
              title: title,
              subtitle: subtitle,
              top: bandTop,
              bottom: bandBottom,
              trailing: trailing,
              backLabel: tr('back', lang),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.only(top: 12), child: body))),
          ],
        ),
      ),
    );
  }
}
