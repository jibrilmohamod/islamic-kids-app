// Neutral interface text only. Nothing here may say what a verse or hadith
// means; that comes from the sources.
//
// The Somali strings are a first draft and need checking by a native speaker.

const Map<String, Map<String, String>> _strings = {
  'appName': {'en': 'Little Muslim', 'so': 'Muslinka Yar'},
  'salaam': {'en': 'Assalamu alaikum!', 'so': 'Assalaamu calaykum!'},
  'learn': {'en': 'Learn', 'so': 'Baro'},
  'duas': {'en': 'Duas', 'so': 'Ducooyin'},
  'play': {'en': 'Play', 'so': 'Ciyaar'},
  'watch': {'en': 'Watch', 'so': 'Daawo'},
  'comingSoon': {'en': 'Coming soon', 'so': 'Dhowaan'},
  'surahs': {'en': 'Surahs', 'so': 'Suuradaha'},
  'hadith': {'en': 'Hadith', 'so': 'Xadiisyada'},
  'ayat': {'en': 'ayat', 'so': 'aayadood'},
  'meaning': {'en': 'Meaning', 'so': 'Macnaha'},
  'understand': {'en': 'Understand it', 'so': 'Faham'},
  'source': {'en': 'Source', 'so': 'Isha'},
  'grade': {'en': 'Grade', 'so': 'Darajada'},
  'orderGame': {'en': 'Put the ayat in order', 'so': 'Isku xigxig aayadaha'},
  'orderHint': {'en': 'Tap the ayat from first to last', 'so': 'Taabo aayadaha laga bilaabo tan koowaad'},
  'tryAgain': {'en': 'Not that one, try again', 'so': 'Taas maaha, isku day mar kale'},
  'wellDone': {'en': 'Well done! MashaAllah!', 'so': 'Waad ku guulaysatay! MaashaAllaah!'},
  'playAgain': {'en': 'Play again', 'so': 'Mar kale ciyaar'},
  'pickSurah': {'en': 'Pick a surah', 'so': 'Dooro suurad'},
  'duaForNow': {'en': 'Dua for now', 'so': 'Ducada hadda'},
  'memorise': {'en': 'Memorise', 'so': 'Xifdi'},
  'memoriseHint': {'en': 'Tap a hidden word to check it', 'so': 'Taabo erayga qarsoon si aad u hubiso'},
  'showAll': {'en': 'Show all', 'so': 'Muuji dhammaan'},
  'hideAll': {'en': 'Hide all', 'so': 'Qari dhammaan'},
  'parents': {'en': 'Parents', 'so': 'Waalidiinta'},
  'language': {'en': 'Language', 'so': 'Luqadda'},
  'sources': {'en': 'Sources and credits', 'so': 'Ilaha iyo mahadnaqa'},
  'bundleVersion': {'en': 'Content version', 'so': 'Nuqulka nuxurka'},
  'loadError': {
    'en': 'Content is missing. Run the content pipeline first.',
    'so': 'Nuxurku ma jiro. Marka hore socodsii pipeline-ka.',
  },
  'quran': {'en': 'Quran', 'so': 'Quraan'},
  'moment.morning-evening': {'en': 'Morning and evening', 'so': 'Subax iyo fiid'},
  'moment.home': {'en': 'Leaving and entering home', 'so': 'Ka bixidda iyo gelidda guriga'},
  'moment.bathroom': {'en': 'Bathroom', 'so': 'Musqusha'},
  'moment.mosque': {'en': 'Mosque', 'so': 'Masjidka'},
  'moment.anytime': {'en': 'Any time', 'so': 'Wakhti kasta'},
  'group.manners-eating': {'en': 'Eating and drinking', 'so': 'Cunidda iyo cabbidda'},
  'group.manners-sleeping': {'en': 'Sleeping and waking', 'so': 'Hurdada iyo toosidda'},
};

String tr(String key, String lang) => _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
