import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../activity.dart';
import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// Asks an adult-level question before a parent-only action.
/// Returns true only when the answer is right.
Future<bool> askParent(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentGateDialog(question: ParentGateQuestion.random(DateTime.now().millisecondsSinceEpoch ~/ 1000)),
  );
  return ok ?? false;
}

class _ParentGateDialog extends StatefulWidget {
  final ParentGateQuestion question;
  const _ParentGateDialog({required this.question});

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _controller = TextEditingController();
  bool wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_controller.text.trim()) == widget.question.answer) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => wrong = true);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: InkPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('forGrownUps', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 20)),
            const SizedBox(height: 10),
            Text(tr('gateQuestion', lang, {'a': widget.question.a, 'b': widget.question.b}),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Pop.ink, width: 3)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Pop.ink, width: 3)),
              ),
              onSubmitted: (_) => _check(),
            ),
            if (wrong)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tr('gateWrong', lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 16),
            ComicButton(label: tr('continue', lang), onPressed: _check),
            const SizedBox(height: 10),
            ComicButton(label: tr('cancel', lang), color: Colors.white, onPressed: () => Navigator.of(context).pop(false)),
          ],
        ),
      ),
    );
  }
}

/// Shown over the whole app when today's time limit is used up.
class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    return Material(
      child: DottedPaper(
        color: Pop.violet,
        dot: const Color(0x40FFFFFF),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.nightlight_round, size: 72, color: Pop.lemon),
                const SizedBox(height: 16),
                MisprintText(tr('breakTitle', lang), size: 30, color: Colors.white, heavyShadow: true),
                const SizedBox(height: 12),
                Text(tr('breakBody', lang),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white, height: 1.35)),
                const SizedBox(height: 32),
                ComicButton(
                  label: '${tr('moreTime', lang)} (${tr('forGrownUps', lang)})',
                  color: Colors.white,
                  onPressed: () async {
                    if (await askParent(context)) state.allowMoreTime(15);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
