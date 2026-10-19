import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'dua_screen.dart';

/// One stop on the "My day" path.
class DayStop {
  final String id;
  final String moment; // which bundle moment the duas come from
  final String labelKey;
  final IconData icon;
  final Color color;
  final bool dark;
  const DayStop(this.id, this.moment, this.labelKey, this.icon, this.color, {this.dark = false});
}

/// The day in order. Morning and evening share HadeethEnc's
/// "Morning and Evening Dhikr" category, so both stops open the same duas.
const dayStops = [
  DayStop('morning', 'morning-evening', 'morning', Icons.wb_twilight_rounded, Pop.lemon),
  DayStop('home', 'home', 'moment.home', Icons.home_rounded, Colors.white),
  DayStop('mosque', 'mosque', 'moment.mosque', Icons.mosque_rounded, Colors.white),
  DayStop('bathroom', 'bathroom', 'moment.bathroom', Icons.wc_rounded, Colors.white),
  DayStop('evening', 'morning-evening', 'evening', Icons.nightlight_round, Pop.violet, dark: true),
];

const anytimeStop = DayStop('anytime', 'anytime', 'anytimeQuran', Icons.auto_stories_rounded, Pop.pink);

/// Which stop is "now": morning before 11, evening from 16, else none.
String? currentStopId(DateTime now) {
  if (now.hour >= 4 && now.hour < 11) return 'morning';
  if (now.hour >= 16 && now.hour < 22) return 'evening';
  return null;
}

/// The stop a dua belongs to, picking morning or evening by the time.
DayStop stopFor(Dua d, DateTime now) {
  if (d.moment == 'morning-evening') {
    return dayStops.firstWhere((s) => s.id == (currentStopId(now) == 'evening' ? 'evening' : 'morning'));
  }
  return [...dayStops, anytimeStop].firstWhere((s) => s.moment == d.moment, orElse: () => anytimeStop);
}

String duaCountLabel(int n, String lang) => n == 1 ? tr('duaCountOne', lang) : tr('duaCount', lang, {'n': n});

class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final duas = state.bundle!.duas;
    final nowId = currentStopId(DateTime.now());
    List<Dua> of(String moment) => duas.where((d) => d.moment == moment).toList();
    final stops = dayStops.where((s) => of(s.moment).isNotEmpty).toList();
    final anytime = of(anytimeStop.moment);

    return PopPage(
      title: tr('myDay', lang),
      subtitle: tr('myDaySub', lang),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          Stack(
            children: [
              Positioned(left: 15, top: 24, bottom: 24, child: Container(width: 6, color: Pop.ink)),
              Column(
                children: [
                  for (final stop in stops)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StopRow(
                        stop: stop,
                        count: of(stop.moment).length,
                        isNow: stop.id == nowId,
                        onTap: () => go(context, MomentScreen(stop: stop, duas: of(stop.moment))),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (anytime.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Caption(tr('anytimeQuran', lang), color: Colors.white)),
            const SizedBox(height: 10),
            InkPanel(
              color: anytimeStop.color,
              halftone: true,
              dotColor: const Color(0x331B1035),
              shadow: 5,
              padding: const EdgeInsets.all(14),
              onTap: () => go(context, MomentScreen(stop: anytimeStop, duas: anytime)),
              child: Row(
                children: [
                  Icon(anytimeStop.icon, color: Pop.ink, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(duaCountLabel(anytime.length, lang),
                        style: const TextStyle(fontFamily: Pop.display, fontSize: 16)),
                  ),
                  if (state.audio != null)
                    Text(tr('withAudio', lang), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final DayStop stop;
  final int count;
  final bool isNow;
  final VoidCallback onTap;
  const _StopRow({required this.stop, required this.count, required this.isNow, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final ink = stop.dark ? Colors.white : Pop.ink;
    final big = isNow || stop.color != Colors.white;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Center(
            child: Container(
              width: big ? 36 : 28,
              height: big ? 36 : 28,
              decoration: BoxDecoration(
                color: stop.color == Colors.white ? Pop.cyan : stop.color,
                shape: BoxShape.circle,
                border: Border.all(color: Pop.ink, width: 4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkPanel(
            color: stop.color,
            border: big ? 4 : 3,
            shadow: big ? 5 : 4,
            halftone: stop.dark,
            dotColor: const Color(0x40FFFFFF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: onTap,
            child: Row(
              children: [
                Icon(stop.icon, color: ink, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(stop.labelKey, lang),
                          style: TextStyle(fontFamily: Pop.display, fontSize: 15, color: ink)),
                      Text(duaCountLabel(count, lang),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink)),
                    ],
                  ),
                ),
                if (isNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    color: stop.dark ? Colors.white : Pop.ink,
                    child: Text(tr('now', lang),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: stop.dark ? Pop.ink : Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The duas of one stop, as cards.
class MomentScreen extends StatelessWidget {
  final DayStop stop;
  final List<Dua> duas;
  const MomentScreen({super.key, required this.stop, required this.duas});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return PopPage(
      title: tr(stop.labelKey, lang),
      subtitle: duaCountLabel(duas.length, lang),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: duas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = duas[i];
          return InkPanel(
            border: 3,
            shadow: 4,
            padding: const EdgeInsets.all(14),
            onTap: () => go(context, DuaScreen(duas: duas, index: i, stop: stop)),
            child: Row(
              children: [
                StarTile(
                  size: 36,
                  glaze: Glaze.full,
                  color: stop.color == Colors.white ? Pop.cyan : stop.color,
                  label: '${i + 1}',
                  semanticsLabel: '${i + 1}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(duaTitle(d, lang),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String duaTitle(Dua d, String lang) {
  final h = d.hadith;
  if (h != null) return h.t(lang).title;
  final m = d.meaningFor(lang);
  return m?.text ?? '${tr('quran', lang)} ${d.quranKey}';
}
