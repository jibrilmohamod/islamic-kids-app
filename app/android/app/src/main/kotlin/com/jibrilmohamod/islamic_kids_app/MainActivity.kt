package com.jibrilmohamod.islamic_kids_app

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity shares the Flutter engine with the media service, so
// recitation keeps playing when the activity goes away (ADR 0002).
class MainActivity : AudioServiceActivity()
