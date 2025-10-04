import 'dart:math';
import '../models/player.dart';

class SanEffectResult {
  final String text;
  final Map<String, int>? tempDebuff; // 暫時能力值減少
  final int? turns; // 持續回合

  SanEffectResult({required this.text, this.tempDebuff, this.turns});
}

class SanEffect {
  final String severity;
  final String text;
  final Map<String,int>? tempDebuff;
  final int? turns;

  SanEffect({
    required this.severity,
    required this.text,
    this.tempDebuff,
    this.turns,
  });

  factory SanEffect.fromJson(Map<String, dynamic> json) {
    return SanEffect(
      severity: json['severity'],
      text: json['text'],
      tempDebuff: json['tempDebuff'] != null
          ? Map<String,int>.from(json['tempDebuff'])
          : null,
      turns: json['turns'],
    );
  }
}

class SanEffectChecker {
  final List<SanEffect> sanEffects;
  final Random rng = Random();

  SanEffectChecker({required this.sanEffects});

  SanEffectResult? checkSanEffect(Player player) {
    String severity;
    if (player.SAN <= 30) {
      severity = "heavy";
    } else if (player.SAN <= 50) {
      severity = "medium";
    } else if (player.SAN <= 60) {
      severity = "light";
    } else {
      return null;
    }

    final options = sanEffects.where((e) => e.severity == severity).toList();
    if (options.isEmpty) return null;

    final effect = options[rng.nextInt(options.length)];
    return SanEffectResult(
      text: effect.text,
      tempDebuff: effect.tempDebuff,
      turns: effect.turns,
    );
  }
}
