import 'package:flutter/animation.dart';

/// Animation definition from config.json
class AnimationSpec {
  final int durationMs;
  final Curve curve;
  final double? scale;
  final double? opacity;
  final double? glowBoost;

  AnimationSpec({
    required this.durationMs,
    required this.curve,
    this.scale,
    this.opacity,
    this.glowBoost,
  });

  factory AnimationSpec.fromJson(Map<String, dynamic> json) {
    return AnimationSpec(
      durationMs: json['duration_ms'] ?? 200,
      curve: _parseCurve(json['curve'] as String?),
      scale: json['scale']?.toDouble(),
      opacity: json['opacity']?.toDouble(),
      glowBoost: json['glow_boost']?.toDouble(),
    );
  }

  static Curve _parseCurve(String? curve) {
    switch (curve) {
      case 'easeIn': return Curves.easeIn;
      case 'easeOut': return Curves.easeOut;
      case 'easeInOut': return Curves.easeInOut;
      case 'easeOutCubic': return Curves.easeOutCubic;
      case 'elasticOut': return Curves.elasticOut;
      case 'easeInOutBack': return Curves.easeInOutBack;
      case 'easeOutQuart': return Curves.easeOutQuart;
      case 'easeInOutSine': return Curves.easeInOutSine;
      case 'linear': return Curves.linear;
      default: return Curves.easeInOut;
    }
  }
}

/// Physics definition for sliders/joysticks
class PhysicsSpec {
  final double damping;
  final double stiffness;
  final double mass;
  final double deadzone;
  final String detents;

  PhysicsSpec({
    this.damping = 0.5,
    this.stiffness = 100.0,
    this.mass = 1.0,
    this.deadzone = 0.05,
    this.detents = 'none',
  });

  factory PhysicsSpec.fromJson(Map<String, dynamic> json) {
    return PhysicsSpec(
      damping: (json['damping'] ?? json['damping_ratio'])?.toDouble() ?? 0.5,
      stiffness: json['stiffness']?.toDouble() ?? 100.0,
      mass: json['mass']?.toDouble() ?? 1.0,
      deadzone: json['deadzone']?.toDouble() ?? 0.05,
      detents: json['detents'] ?? 'none',
    );
  }
}

/// Root config object for a widget variant.
/// Now handles both Asset Mapping (states/layers) and Behavioral Logic (physics/animations).
class BehaviorConfig {
  final Map<String, String> states;
  final Map<String, String> layers;
  final Map<String, AnimationSpec> animations;
  final PhysicsSpec physics;
  final Map<String, String> haptics;
  final Map<String, dynamic> audio;
  final Map<String, dynamic> effects;
  final Map<String, dynamic> options;

  BehaviorConfig({
    this.states = const {},
    this.layers = const {},
    required this.animations,
    required this.physics,
    required this.haptics,
    required this.audio,
    required this.effects,
    this.options = const {},
  });

  factory BehaviorConfig.empty() => BehaviorConfig(
        states: {},
        layers: {},
        animations: {},
        physics: PhysicsSpec(),
        haptics: {},
        audio: {},
        effects: {},
        options: {},
      );

  factory BehaviorConfig.fromJson(Map<String, dynamic> json) {
    final anims = <String, AnimationSpec>{};
    if (json['animations'] != null) {
      (json['animations'] as Map<String, dynamic>).forEach((key, value) {
        anims[key] = AnimationSpec.fromJson(value);
      });
    }

    return BehaviorConfig(
      states: (json['states'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      layers: (json['layers'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      animations: anims,
      physics: PhysicsSpec.fromJson(json['physics'] ?? {}),
      haptics: (json['haptics'] ?? {}).cast<String, String>(),
      audio: json['audio'] ?? {},
      effects: json['effects'] ?? {},
      options: (json['options'] as Map<String, dynamic>?) ?? {},
    );
  }
}
