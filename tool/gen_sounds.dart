// Synthesizes every sound effect and the music loop into assets/audio/*.wav.
//
// Run from the project root:  dart run tool/gen_sounds.dart
//
// Everything is generated procedurally (no third-party samples), so the
// output is ours to ship and can be re-tuned here and regenerated.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

int sr = 44100;
final Random rng = Random(11);

void main() {
  Directory('assets/audio').createSync(recursive: true);
  for (var i = 0; i < 3; i++) {
    write('chomp_$i', chomp(1 + i * 0.12));
  }
  write('gulp', gulp());
  write('big', big());
  write('pop', pop());
  write('coin', coin());
  write('powerup', arpeggio([523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0], 0.045, 0.22, wobble: true));
  write('levelup', fanfare());
  write('click', click());
  write('eaten', eaten());
  write('win', win());
  write('tick', tick(1200));
  write(
    'go',
    mix([
      tick(1568),
      chord([523.3, 659.3, 784.0, 1046.5], 0.45, 0.2),
    ]),
  );
  write('star', arpeggio([1046.5, 1318.5, 1568.0, 2093.0], 0.06, 0.2));
  write('spin', tick(2200, gain: 0.25, decay: 0.012));
  write('whoosh', whoosh());
  write('combo', arpeggio([784.0, 987.8, 1174.7], 0.05, 0.24));
  sr = 22050;
  write('music', music());
}

// ---------------------------------------------------------------------------

Float64List buf(double seconds) => Float64List((seconds * sr).round());

/// A bite: a quick falling "nom" tone and a crunchy burst.
Float64List chomp(double pitch) {
  final out = buf(0.16);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / sr;
    final f = (420 - 260 * (1 - exp(-t / 0.03))) * pitch;
    phase += 2 * pi * f / sr;
    final env = (1 - exp(-t / 0.002)) * exp(-t / 0.045);
    // A little square-ish edge makes it chewy.
    out[i] = (sin(phase) + 0.3 * sin(phase * 2) + 0.15 * sin(phase * 3)) * env * 0.5;
  }
  final crunch = highpass(lowpass(noise(0.06), 0.45), 0.08);
  for (var i = 0; i < crunch.length; i++) {
    out[i] += crunch[i] * exp(-i / sr / 0.015) * 0.55;
  }
  return out;
}

/// A cartoon swallow: a bubble whose pitch drops.
Float64List gulp() {
  final out = buf(0.3);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / sr;
    final f = 330 * exp(-t / 0.14) + 90;
    phase += 2 * pi * f / sr;
    out[i] = sin(phase) * (1 - exp(-t / 0.004)) * exp(-t / 0.1) * 0.75;
  }
  return mix([out, chomp(0.8)]);
}

/// Something huge going down: a deep boom, crunch and a satisfied gulp.
Float64List big() {
  final out = buf(0.7);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / sr;
    final f = 140 * exp(-t / 0.25) + 45;
    phase += 2 * pi * f / sr;
    out[i] = sin(phase) * (1 - exp(-t / 0.003)) * exp(-t / 0.22) * 0.9;
  }
  final crunch = lowpass(noise(0.25), 0.3);
  for (var i = 0; i < crunch.length; i++) {
    out[i] += crunch[i] * exp(-i / sr / 0.06) * 0.6;
  }
  final g = gulp();
  final s = (0.12 * sr).round();
  for (var i = 0; i < g.length && s + i < out.length; i++) {
    out[s + i] += g[i] * 0.6;
  }
  return out;
}

Float64List pop() {
  final out = buf(0.12);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / sr;
    final f = 500 + 900 * (1 - exp(-t / 0.02));
    phase += 2 * pi * f / sr;
    out[i] = sin(phase) * (1 - exp(-t / 0.001)) * exp(-t / 0.03) * 0.6;
  }
  return out;
}

Float64List coin() {
  final out = buf(0.35);
  void note(double f, double start) {
    final s = (start * sr).round();
    for (var i = s; i < out.length; i++) {
      final t = (i - s) / sr;
      out[i] += (sin(2 * pi * f * t) + 0.3 * sin(4 * pi * f * t)) * (1 - exp(-t / 0.002)) * exp(-t / 0.08) * 0.32;
    }
  }

  note(1318.5, 0);
  note(1975.5, 0.07);
  return out;
}

Float64List click() {
  final out = buf(0.04);
  for (var i = 0; i < out.length; i++) {
    final t = i / sr;
    out[i] = sin(2 * pi * 1500 * t) * exp(-t / 0.006) * 0.35;
  }
  return out;
}

Float64List tick(double f, {double gain = 0.4, double decay = 0.03}) {
  final out = buf(decay * 5);
  for (var i = 0; i < out.length; i++) {
    final t = i / sr;
    out[i] = (sin(2 * pi * f * t) + 0.4 * sin(2 * pi * f * 2.01 * t)) * (1 - exp(-t / 0.001)) * exp(-t / decay) * gain;
  }
  return out;
}

Float64List whoosh() {
  final n = noise(0.3);
  final out = Float64List(n.length);
  var y = 0.0;
  for (var i = 0; i < n.length; i++) {
    final t = i / n.length;
    final a = 0.05 + 0.3 * sin(pi * t);
    y += a * (n[i] - y);
    out[i] = y * sin(pi * t) * 1.3;
  }
  return highpass(out, 0.02);
}

/// Rising notes, each ringing on under the next.
Float64List arpeggio(List<double> notes, double step, double gain, {bool wobble = false}) {
  final out = buf(step * notes.length + 0.5);
  for (var k = 0; k < notes.length; k++) {
    final s = (k * step * sr).round();
    for (var i = s; i < out.length; i++) {
      final t = (i - s) / sr;
      final f = notes[k] * (wobble ? 1 + 0.01 * sin(2 * pi * 7 * t) : 1);
      out[i] += (sin(2 * pi * f * t) + 0.25 * sin(4 * pi * f * t)) * (1 - exp(-t / 0.002)) * exp(-t / 0.16) * gain;
    }
  }
  return out;
}

Float64List chord(List<double> notes, double decay, double gain) {
  final out = buf(decay * 4);
  for (final f in notes) {
    for (var i = 0; i < out.length; i++) {
      final t = i / sr;
      out[i] += (sin(2 * pi * f * t) + 0.2 * sin(6 * pi * f * t)) * (1 - exp(-t / 0.004)) * exp(-t / decay) * gain;
    }
  }
  return out;
}

Float64List fanfare() => mix([
  arpeggio([523.3, 659.3, 784.0], 0.09, 0.22),
  _at(chord([523.3, 659.3, 784.0, 1046.5], 0.5, 0.16), 0.3),
]);

Float64List win() => mix([
  arpeggio([392.0, 523.3, 659.3, 784.0], 0.08, 0.2),
  _at(chord([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.7, 0.14), 0.34),
]);

/// A sad trombone "wah wah wah waaah".
Float64List eaten() {
  final out = buf(1.5);
  const notes = [(392.0, 0.0, 0.25), (370.0, 0.28, 0.25), (349.2, 0.56, 0.25), (329.6, 0.84, 0.6)];
  for (final (f, start, len) in notes) {
    final s = (start * sr).round();
    var phase = 0.0;
    for (var i = 0; i < (len * sr).round() && s + i < out.length; i++) {
      final t = i / sr;
      final vib = len > 0.4 ? 1 + 0.02 * sin(2 * pi * 6 * t) : 1;
      phase += 2 * pi * f * vib / sr;
      final env = (1 - exp(-t / 0.02)) * (t < len - 0.05 ? 1 : max(0, (len - t) / 0.05));
      // Brassy: odd harmonics.
      out[s + i] += (sin(phase) + 0.5 * sin(phase * 2) + 0.35 * sin(phase * 3) + 0.2 * sin(phase * 4)) * env * 0.22;
    }
  }
  return lowpass(out, 0.3);
}

// Music ------------------------------------------------------------------------

/// A bouncy 8-bar loop at 124 BPM: bass, plucked chords, a bell melody and
/// light drums. Rendered long and wrapped, so the loop point is seamless.
Float64List music() {
  const bpm = 124.0;
  const beat = 60 / bpm;
  const bars = 8;
  final length = bars * 4 * beat;
  final out = buf(length + 2);

  double midi(int n) => 440 * pow(2, (n - 69) / 12).toDouble();

  void tone(double f, double start, double dur, double gain, {String wave = 'sine', double decay = 0.2}) {
    final s = (start * sr).round();
    final n = ((dur + decay * 3) * sr).round();
    var phase = 0.0;
    for (var i = 0; i < n && s + i < out.length; i++) {
      final t = i / sr;
      phase += 2 * pi * f / sr;
      final env =
          (1 - exp(-t / 0.005)) *
          (t < dur ? exp(-t / (decay * 2)) : exp(-dur / (decay * 2)) * exp(-(t - dur) / decay * 3));
      final v = switch (wave) {
        'tri' => (2 / pi) * asin(sin(phase)),
        'pluck' => sin(phase) + 0.45 * sin(phase * 2) + 0.2 * sin(phase * 3),
        'bell' => sin(phase) + 0.35 * sin(phase * 2.76) * exp(-t / 0.15) + 0.2 * sin(phase * 4),
        _ => sin(phase),
      };
      out[s + i] += v * env * gain;
    }
  }

  void drum(String kind, double start) {
    final s = (start * sr).round();
    switch (kind) {
      case 'kick':
        var phase = 0.0;
        for (var i = 0; i < (0.25 * sr).round() && s + i < out.length; i++) {
          final t = i / sr;
          phase += 2 * pi * (50 + 110 * exp(-t / 0.03)) / sr;
          out[s + i] += sin(phase) * exp(-t / 0.08) * 0.55;
        }
      case 'snare':
        final n = highpass(noise(0.18), 0.12);
        for (var i = 0; i < n.length && s + i < out.length; i++) {
          final t = i / sr;
          out[s + i] += (n[i] * 0.8 + sin(2 * pi * 190 * t) * 0.4) * exp(-t / 0.05) * 0.28;
        }
      case 'hat':
        final n = highpass(noise(0.05), 0.5);
        for (var i = 0; i < n.length && s + i < out.length; i++) {
          out[s + i] += n[i] * exp(-i / sr / 0.012) * 0.12;
        }
    }
  }

  // C - Am - F - G, twice; the second time the melody answers.
  const roots = [48, 45, 41, 43, 48, 45, 41, 43];
  const triads = [
    [60, 64, 67],
    [57, 60, 64],
    [53, 57, 60],
    [55, 59, 62],
  ];
  // Melody: (beat offset in the bar, midi, length in beats).
  const phraseA = [(0.0, 72, 0.5), (0.5, 76, 0.5), (1.0, 79, 1.0), (2.5, 76, 0.5), (3.0, 74, 1.0)];
  const phraseB = [(0.0, 69, 0.5), (0.5, 72, 0.5), (1.0, 76, 1.0), (2.0, 74, 0.5), (2.5, 72, 1.5)];
  const phraseC = [(0.0, 69, 0.5), (0.5, 72, 0.5), (1.0, 77, 1.0), (2.5, 76, 0.5), (3.0, 72, 1.0)];
  const phraseD = [(0.0, 67, 0.5), (0.5, 71, 0.5), (1.0, 74, 0.75), (2.0, 79, 0.5), (2.5, 77, 0.5), (3.0, 74, 1.0)];
  const phraseE = [(0.0, 79, 1.0), (1.0, 76, 0.5), (1.5, 72, 0.5), (2.0, 76, 2.0)];
  const phraseF = [(0.0, 76, 0.5), (0.5, 74, 0.5), (1.0, 72, 1.0), (2.0, 69, 2.0)];
  const phraseG = [(0.0, 77, 0.5), (0.5, 76, 0.5), (1.0, 74, 0.5), (1.5, 72, 0.5), (2.0, 69, 2.0)];
  const phraseH = [(0.0, 71, 0.5), (0.5, 72, 0.5), (1.0, 74, 1.0), (2.0, 79, 1.0), (3.0, 83, 1.0)];
  const melody = [phraseA, phraseB, phraseC, phraseD, phraseE, phraseF, phraseG, phraseH];

  for (var bar = 0; bar < bars; bar++) {
    final t0 = bar * 4 * beat;
    final root = roots[bar];
    // Bass: root on 1 and 3, fifth on the "and" of 2 and 4.
    for (final (b, n) in [(0.0, root), (1.5, root + 7), (2.0, root), (3.5, root + 7)]) {
      tone(midi(n - 12), t0 + b * beat, beat * 0.45, 0.32, wave: 'tri', decay: 0.12);
    }
    // Off-beat chord plucks.
    for (final b in [0.5, 1.5, 2.5, 3.5]) {
      for (final n in triads[bar % 4]) {
        tone(midi(n), t0 + b * beat, beat * 0.2, 0.055, wave: 'pluck', decay: 0.06);
      }
    }
    for (final (b, n, len) in melody[bar]) {
      tone(midi(n), t0 + b * beat, len * beat * 0.9, 0.11, wave: 'bell', decay: 0.18);
    }
    for (var b = 0; b < 4; b++) {
      drum(b.isEven ? 'kick' : 'snare', t0 + b * beat);
      drum('hat', t0 + (b + 0.5) * beat);
    }
    drum('kick', t0 + 2.75 * beat);
  }

  // Wrap the tail into the head for a seamless loop.
  final loop = buf(length);
  for (var i = 0; i < out.length; i++) {
    loop[i % loop.length] += out[i];
  }
  return loop;
}

Float64List _at(Float64List x, double seconds) {
  final s = (seconds * sr).round();
  final out = Float64List(x.length + s);
  out.setAll(s, x);
  return out;
}

// ---------------------------------------------------------------------------

Float64List noise(double seconds) {
  final out = buf(seconds);
  for (var i = 0; i < out.length; i++) {
    out[i] = rng.nextDouble() * 2 - 1;
  }
  return out;
}

Float64List lowpass(Float64List x, double a) {
  final out = Float64List(x.length);
  var y = 0.0;
  for (var i = 0; i < x.length; i++) {
    y += a * (x[i] - y);
    out[i] = y;
  }
  return out;
}

Float64List highpass(Float64List x, double a) {
  final low = lowpass(x, a);
  final out = Float64List(x.length);
  for (var i = 0; i < x.length; i++) {
    out[i] = x[i] - low[i];
  }
  return out;
}

Float64List mix(List<Float64List> parts) {
  final len = parts.map((p) => p.length).reduce(max);
  final out = Float64List(len);
  for (final p in parts) {
    for (var i = 0; i < p.length; i++) {
      out[i] += p[i];
    }
  }
  return out;
}

void write(String name, Float64List samples) {
  var peak = 0.0;
  for (final s in samples) {
    peak = max(peak, s.abs());
  }
  final scale = peak > 0.92 ? 0.92 / peak : 1.0;
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sr, Endian.little);
  data.setUint32(28, sr * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * scale * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  File('assets/audio/$name.wav').writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('assets/audio/$name.wav  ${(samples.length / sr).toStringAsFixed(2)}s');
}
