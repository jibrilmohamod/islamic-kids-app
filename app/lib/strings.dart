// Neutral interface text only. Nothing here may say what a verse or hadith
// means; that comes from the sources.
//
// Somali strings are a first draft for a native speaker to check. Somali is
// switched off until content coverage is ready (AppState.somaliEnabled).

const Map<String, Map<String, String>> _strings = {
  'appName': {'en': 'Little Muslim', 'so': 'Muslinka Yar'},
  'salaam': {'en': 'Assalamu alaikum', 'so': 'Assalaamu calaykum'},
  'yourMosaic': {'en': 'Your mosaic', 'so': 'Mosaic-gaaga'},
  'glazedCount': {'en': '{n} of {total} glazed', 'so': '{n} ka mid ah {total}'},
  'nextUp': {'en': 'Next up: {name}', 'so': 'Xigta: {name}'},
  'allGlazed': {'en': 'Every tile is glazed. MashaAllah!', 'so': 'Dhammaan waa la dhammeeyay. MaashaAllaah!'},
  'openMosaic': {'en': 'All surahs', 'so': 'Dhammaan suuradaha'},
  'surahs': {'en': 'Surahs', 'so': 'Suuradaha'},
  'duas': {'en': 'Duas', 'so': 'Ducooyin'},
  'hadith': {'en': 'Hadith', 'so': 'Xadiisyada'},
  'ayat': {'en': '{n} ayat', 'so': '{n} aayadood'},
  'surahNumber': {'en': 'Surah {n}', 'so': 'Suuradda {n}'},
  'meaning': {'en': 'Meaning', 'so': 'Macnaha'},
  'footnotes': {'en': 'Notes', 'so': 'Faallo'},
  'understand': {'en': 'Understand it', 'so': 'Faham'},
  'source': {'en': 'Source', 'so': 'Isha'},
  'grade': {'en': 'Grade', 'so': 'Darajada'},
  'play': {'en': 'Put the ayat in order', 'so': 'Isku xigxig aayadaha'},
  'playRound': {'en': 'Play round {n}', 'so': 'Ciyaar wareegga {n}'},
  'roundLabel': {'en': 'Round {n}: ayat {from} to {to}', 'so': 'Wareegga {n}: aayadaha {from} ilaa {to}'},
  'roundsProgress': {'en': '{n} of {total} rounds done', 'so': '{n} ka mid ah {total} wareeg'},
  'pickRound': {'en': 'Pick a round', 'so': 'Dooro wareeg'},
  'placed': {'en': '{n} of {total}', 'so': '{n} / {total}'},
  'whichNext': {'en': 'Which ayah comes next?', 'so': 'Aayaddee xigta?'},
  'tapNext': {'en': 'Tap the next one', 'so': 'Taabo tan xigta'},
  'nice': {'en': 'Nice!', 'so': 'Fiican!'},
  'tryAgain': {'en': 'Not that one. Try again', 'so': 'Taas maaha. Isku day mar kale'},
  'roundDone': {'en': 'Round done!', 'so': 'Wareeggii waa dhammaaday!'},
  'tileGlazed': {'en': 'Tile glazed!', 'so': 'Waa la dhammeeyay!'},
  'nextRound': {'en': 'Next round', 'so': 'Wareegga xiga'},
  'backToSurah': {'en': 'Back to the surah', 'so': 'Ku noqo suuradda'},
  'listen': {'en': 'Listen to ayah {n}', 'so': 'Dhegayso aayadda {n}'},
  'listenAll': {'en': 'Listen to the surah', 'so': 'Dhegayso suuradda'},
  'stop': {'en': 'Stop', 'so': 'Jooji'},
  'saveAudio': {'en': 'Save audio for offline', 'so': 'Kaydi codka'},
  'savingAudio': {'en': 'Saving audio {n} of {total}', 'so': 'Kaydinta codka {n} / {total}'},
  'audioSaved': {'en': 'Audio saved, plays offline', 'so': 'Codka waa la kaydiyay'},
  'audioFailed': {
    'en': 'Audio could not load. Connect to the internet once to save it.',
    'so': 'Codku ma soo degin. Ku xir internetka hal mar si loo kaydiyo.',
  },
  'deleteAudio': {'en': 'Remove saved audio', 'so': 'Tirtir codka'},
  'recitation': {'en': 'Recitation', 'so': 'Akhriska'},
  'duaForNow': {'en': 'Dua for now', 'so': 'Ducada hadda'},
  'memorise': {'en': 'Memorise', 'so': 'Xifdi'},
  'memoriseHint': {'en': 'Tap a word to hide or show it', 'so': 'Taabo eray si aad u qariso ama u muujiso'},
  'showAll': {'en': 'Show all', 'so': 'Muuji dhammaan'},
  'hideAll': {'en': 'Hide all', 'so': 'Qari dhammaan'},
  'parents': {'en': 'Parents', 'so': 'Waalidiinta'},
  'language': {'en': 'Language', 'so': 'Luqadda'},
  'sources': {'en': 'Sources and credits', 'so': 'Ilaha iyo mahadnaqa'},
  'bundleVersion': {'en': 'Content version', 'so': 'Nuqulka nuxurka'},
  'fontLicenses': {'en': 'Font licences', 'so': 'Shatiyada farta'},
  'loadError': {
    'en': 'Content is missing. Run the content pipeline first.',
    'so': 'Nuxurku ma jiro. Marka hore socodsii pipeline-ka.',
  },
  'quran': {'en': 'Quran', 'so': 'Quraan'},
  'back': {'en': 'Back', 'so': 'Dib'},
  'moment.morning-evening': {'en': 'Morning and evening', 'so': 'Subax iyo fiid'},
  'moment.home': {'en': 'Leaving and entering home', 'so': 'Ka bixidda iyo gelidda guriga'},
  'moment.bathroom': {'en': 'Bathroom', 'so': 'Musqusha'},
  'moment.mosque': {'en': 'Mosque', 'so': 'Masjidka'},
  'moment.anytime': {'en': 'Any time', 'so': 'Wakhti kasta'},
  'group.manners-eating': {'en': 'Eating and drinking', 'so': 'Cunidda iyo cabbidda'},
  'group.manners-sleeping': {'en': 'Sleeping and waking', 'so': 'Hurdada iyo toosidda'},
};

String tr(String key, String lang, [Map<String, Object> args = const {}]) {
  var s = _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}
