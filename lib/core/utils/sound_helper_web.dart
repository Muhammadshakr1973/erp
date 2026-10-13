// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Web implementation of notification chime sound synthesizer
void playChimeSoundWeb() {
  try {
    // 1. Try Web Audio API oscillator synth first if context is available
    final webAudioPlayed = _tryWebAudioSynth();
    if (webAudioPlayed) return;

    // 2. Fallback to HTML5 Audio Element with generated PCM WAV Blob
    final wavBytes = _generateChimeWav();
    final blob = html.Blob([wavBytes], 'audio/wav');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final audio = html.AudioElement(url);
    audio.volume = 0.85;
    audio.play().then((_) {
      Timer(const Duration(seconds: 3), () {
        html.Url.revokeObjectUrl(url);
      });
    }).catchError((e) {
      debugPrint("Web audio element play error: $e");
    });
  } catch (e) {
    debugPrint("Web audio chime error: $e");
  }
}

bool _tryWebAudioSynth() {
  try {
    final audioCtxClass = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
    if (audioCtxClass == null) return false;

    final ctx = js.JsObject(audioCtxClass, []);
    final now = ctx['currentTime'] as num? ?? 0.0;

    // First chime tone: F5 (698.46 Hz)
    final osc1 = ctx.callMethod('createOscillator') as js.JsObject;
    final gain1 = ctx.callMethod('createGain') as js.JsObject;
    osc1['type'] = 'sine';
    (osc1['frequency'] as js.JsObject).callMethod('setValueAtTime', [698.46, now]);
    (gain1['gain'] as js.JsObject).callMethod('setValueAtTime', [0.4, now]);
    (gain1['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [0.001, now + 0.18]);
    osc1.callMethod('connect', [gain1]);
    gain1.callMethod('connect', [ctx['destination']]);
    osc1.callMethod('start', [now]);
    osc1.callMethod('stop', [now + 0.18]);

    // Second chime tone: A5 (880.00 Hz)
    final osc2 = ctx.callMethod('createOscillator') as js.JsObject;
    final gain2 = ctx.callMethod('createGain') as js.JsObject;
    osc2['type'] = 'sine';
    (osc2['frequency'] as js.JsObject).callMethod('setValueAtTime', [880.00, now + 0.10]);
    (gain2['gain'] as js.JsObject).callMethod('setValueAtTime', [0.5, now + 0.10]);
    (gain2['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [0.001, now + 0.42]);
    osc2.callMethod('connect', [gain2]);
    gain2.callMethod('connect', [ctx['destination']]);
    osc2.callMethod('start', [now + 0.10]);
    osc2.callMethod('stop', [now + 0.42]);

    return true;
  } catch (e) {
    debugPrint("Web Audio API synth exception: $e");
    return false;
  }
}

Uint8List _generateChimeWav() {
  const sampleRate = 22050;
  const duration1 = 0.12;
  const duration2 = 0.22;
  final totalSamples = (sampleRate * (duration1 + duration2)).toInt();

  final pcmData = Int16List(totalSamples);

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final isFirst = t < duration1;
    final freq = isFirst ? 698.46 : 880.00;
    final localT = isFirst ? t : (t - duration1);
    final localDur = isFirst ? duration1 : duration2;

    final envelope = (1.0 - (localT / localDur)).clamp(0.0, 1.0);
    final volume = envelope * envelope;

    final sample = math.sin(2 * math.pi * freq * localT) * volume * 0.6;
    pcmData[i] = (sample * 32767).toInt().clamp(-32768, 32767);
  }

  final byteData = ByteData(44 + totalSamples * 2);
  byteData.setUint8(0, 0x52); // 'R'
  byteData.setUint8(1, 0x49); // 'I'
  byteData.setUint8(2, 0x46); // 'F'
  byteData.setUint8(3, 0x46); // 'F'
  byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
  byteData.setUint8(8, 0x57);  // 'W'
  byteData.setUint8(9, 0x41);  // 'A'
  byteData.setUint8(10, 0x56); // 'V'
  byteData.setUint8(11, 0x45); // 'E'

  byteData.setUint8(12, 0x66); // 'f'
  byteData.setUint8(13, 0x6d); // 'm'
  byteData.setUint8(14, 0x74); // 't'
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little); // PCM
  byteData.setUint16(22, 1, Endian.little); // Mono
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);

  byteData.setUint8(36, 0x64); // 'd'
  byteData.setUint8(37, 0x61); // 'a'
  byteData.setUint8(38, 0x74); // 't'
  byteData.setUint8(39, 0x61); // 'a'
  byteData.setUint32(40, totalSamples * 2, Endian.little);

  for (int i = 0; i < totalSamples; i++) {
    byteData.setInt16(44 + i * 2, pcmData[i], Endian.little);
  }

  return byteData.buffer.asUint8List();
}

/// Web implementation of scanner/action failure sound synthesizer (distinct low-pitch rejection buzz)
void playErrorSoundWeb() {
  try {
    // 1. Try Web Audio API oscillator synth first if context is available
    final webAudioPlayed = _tryWebAudioErrorSynth();
    if (webAudioPlayed) return;

    // 2. Fallback to HTML5 Audio Element with generated PCM WAV Blob
    final wavBytes = _generateErrorWav();
    final blob = html.Blob([wavBytes], 'audio/wav');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final audio = html.AudioElement(url);
    audio.volume = 0.85;
    audio.play().then((_) {
      Timer(const Duration(seconds: 3), () {
        html.Url.revokeObjectUrl(url);
      });
    }).catchError((e) {
      debugPrint("Web audio element error sound error: $e");
    });
  } catch (e) {
    debugPrint("Web audio error sound exception: $e");
  }
}

bool _tryWebAudioErrorSynth() {
  try {
    final audioCtxClass = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
    if (audioCtxClass == null) return false;

    final ctx = js.JsObject(audioCtxClass, []);
    final now = ctx['currentTime'] as num? ?? 0.0;

    // First low rejection tone: 200 Hz -> 170 Hz (sawtooth wave for classic scanner rejection buzz)
    final osc1 = ctx.callMethod('createOscillator') as js.JsObject;
    final gain1 = ctx.callMethod('createGain') as js.JsObject;
    osc1['type'] = 'sawtooth';
    (osc1['frequency'] as js.JsObject).callMethod('setValueAtTime', [200.0, now]);
    (osc1['frequency'] as js.JsObject).callMethod('linearRampToValueAtTime', [170.0, now + 0.12]);
    (gain1['gain'] as js.JsObject).callMethod('setValueAtTime', [0.35, now]);
    (gain1['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [0.001, now + 0.12]);
    osc1.callMethod('connect', [gain1]);
    gain1.callMethod('connect', [ctx['destination']]);
    osc1.callMethod('start', [now]);
    osc1.callMethod('stop', [now + 0.12]);

    // Second low rejection tone (lower & heavier): 140 Hz -> 100 Hz
    final osc2 = ctx.callMethod('createOscillator') as js.JsObject;
    final gain2 = ctx.callMethod('createGain') as js.JsObject;
    osc2['type'] = 'sawtooth';
    (osc2['frequency'] as js.JsObject).callMethod('setValueAtTime', [140.0, now + 0.14]);
    (osc2['frequency'] as js.JsObject).callMethod('linearRampToValueAtTime', [100.0, now + 0.32]);
    (gain2['gain'] as js.JsObject).callMethod('setValueAtTime', [0.45, now + 0.14]);
    (gain2['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [0.001, now + 0.32]);
    osc2.callMethod('connect', [gain2]);
    gain2.callMethod('connect', [ctx['destination']]);
    osc2.callMethod('start', [now + 0.14]);
    osc2.callMethod('stop', [now + 0.32]);

    return true;
  } catch (e) {
    debugPrint("Web Audio API error synth exception: $e");
    return false;
  }
}

Uint8List _generateErrorWav() {
  const sampleRate = 22050;
  const duration1 = 0.12;
  const gap = 0.02;
  const duration2 = 0.18;
  final totalSamples = (sampleRate * (duration1 + gap + duration2)).toInt();

  final pcmData = Int16List(totalSamples);

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    if (t < duration1) {
      final localT = t;
      final envelope = (1.0 - (localT / duration1)).clamp(0.0, 1.0);
      final freq = 200.0 - (30.0 * (localT / duration1));
      final phase = (localT * freq) % 1.0;
      final sample = (phase * 2.0 - 1.0) * envelope * 0.45;
      pcmData[i] = (sample * 32767).toInt().clamp(-32768, 32767);
    } else if (t < duration1 + gap) {
      pcmData[i] = 0;
    } else {
      final localT = t - duration1 - gap;
      final envelope = (1.0 - (localT / duration2)).clamp(0.0, 1.0);
      final freq = 140.0 - (40.0 * (localT / duration2));
      final phase = (localT * freq) % 1.0;
      final sample = (phase * 2.0 - 1.0) * envelope * 0.55;
      pcmData[i] = (sample * 32767).toInt().clamp(-32768, 32767);
    }
  }

  final byteData = ByteData(44 + totalSamples * 2);
  byteData.setUint8(0, 0x52); // 'R'
  byteData.setUint8(1, 0x49); // 'I'
  byteData.setUint8(2, 0x46); // 'F'
  byteData.setUint8(3, 0x46); // 'F'
  byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
  byteData.setUint8(8, 0x57);  // 'W'
  byteData.setUint8(9, 0x41);  // 'A'
  byteData.setUint8(10, 0x56); // 'V'
  byteData.setUint8(11, 0x45); // 'E'

  byteData.setUint8(12, 0x66); // 'f'
  byteData.setUint8(13, 0x6d); // 'm'
  byteData.setUint8(14, 0x74); // 't'
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little); // PCM
  byteData.setUint16(22, 1, Endian.little); // Mono
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);

  byteData.setUint8(36, 0x64); // 'd'
  byteData.setUint8(37, 0x61); // 'a'
  byteData.setUint8(38, 0x74); // 't'
  byteData.setUint8(39, 0x61); // 'a'
  byteData.setUint32(40, totalSamples * 2, Endian.little);

  for (int i = 0; i < totalSamples; i++) {
    byteData.setInt16(44 + i * 2, pcmData[i], Endian.little);
  }

  return byteData.buffer.asUint8List();
}
