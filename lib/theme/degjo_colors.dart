import 'package:flutter/material.dart';

class DegjoColors extends ThemeExtension<DegjoColors> {
  final Color background;
  final Color card;
  final Color accent;
  final Color text;
  final Color muted;
  final Color separator;
  final Color inputBg;
  final Color lessonDone;     // done lesson row bg tint
  final Color activeLessonBg; // active lesson row bg
  final Color blobRed;
  final Color blobPurple;
  final Color errorBorder;
  final Color dashedBorder;
  final Color dotInactive;
  final Color dotDone;

  const DegjoColors({
    required this.background,
    required this.card,
    required this.accent,
    required this.text,
    required this.muted,
    required this.separator,
    required this.inputBg,
    required this.lessonDone,
    required this.activeLessonBg,
    required this.blobRed,
    required this.blobPurple,
    required this.errorBorder,
    required this.dashedBorder,
    required this.dotInactive,
    required this.dotDone,
  });

  static DegjoColors of(BuildContext context) =>
      Theme.of(context).extension<DegjoColors>()!;

  static const light = DegjoColors(
    background:    Color(0xFFF0F0F0),
    card:          Color(0xFFFFFFFF),
    accent:        Color(0xFFFF0000),
    text:          Color(0xFF0F0F0F),
    muted:         Color(0xFFAAAAAA),
    separator:     Color(0xFFF5F5F5),
    inputBg:       Color(0xFFFAFAFA),
    lessonDone:    Color(0xFFFFFFFF),
    activeLessonBg:Color(0xFFFFF0F0),
    blobRed:       Color(0xFFFF0000),
    blobPurple:    Color(0xFF6C63FF),
    errorBorder:   Color(0xFFFF0000),
    dashedBorder:  Color(0xFFE8E8E8),
    dotInactive:   Color(0xFFF0F0F0),
    dotDone:       Color(0xFFFFCCCC),
  );

  static const dark = DegjoColors(
    background:    Color(0xFF0D0D0D),
    card:          Color(0xFF1A1A1A),
    accent:        Color(0xFFFF453A),
    text:          Color(0xFFF0F0F0),
    muted:         Color(0xFF666666),
    separator:     Color(0xFF2A2A2A),
    inputBg:       Color(0xFF252525),
    lessonDone:    Color(0xFF1A1A1A),
    activeLessonBg:Color(0xFF2A1515),
    blobRed:       Color(0xFFFF453A),
    blobPurple:    Color(0xFF6C63FF),
    errorBorder:   Color(0xFFFF453A),
    dashedBorder:  Color(0xFF333333),
    dotInactive:   Color(0xFF2A2A2A),
    dotDone:       Color(0xFF5A2020),
  );

  @override
  DegjoColors copyWith({
    Color? background, Color? card, Color? accent, Color? text,
    Color? muted, Color? separator, Color? inputBg, Color? lessonDone,
    Color? activeLessonBg, Color? blobRed, Color? blobPurple,
    Color? errorBorder, Color? dashedBorder, Color? dotInactive, Color? dotDone,
  }) => DegjoColors(
    background:     background ?? this.background,
    card:           card ?? this.card,
    accent:         accent ?? this.accent,
    text:           text ?? this.text,
    muted:          muted ?? this.muted,
    separator:      separator ?? this.separator,
    inputBg:        inputBg ?? this.inputBg,
    lessonDone:     lessonDone ?? this.lessonDone,
    activeLessonBg: activeLessonBg ?? this.activeLessonBg,
    blobRed:        blobRed ?? this.blobRed,
    blobPurple:     blobPurple ?? this.blobPurple,
    errorBorder:    errorBorder ?? this.errorBorder,
    dashedBorder:   dashedBorder ?? this.dashedBorder,
    dotInactive:    dotInactive ?? this.dotInactive,
    dotDone:        dotDone ?? this.dotDone,
  );

  @override
  DegjoColors lerp(DegjoColors? other, double t) {
    if (other == null) return this;
    return DegjoColors(
      background:     Color.lerp(background, other.background, t)!,
      card:           Color.lerp(card, other.card, t)!,
      accent:         Color.lerp(accent, other.accent, t)!,
      text:           Color.lerp(text, other.text, t)!,
      muted:          Color.lerp(muted, other.muted, t)!,
      separator:      Color.lerp(separator, other.separator, t)!,
      inputBg:        Color.lerp(inputBg, other.inputBg, t)!,
      lessonDone:     Color.lerp(lessonDone, other.lessonDone, t)!,
      activeLessonBg: Color.lerp(activeLessonBg, other.activeLessonBg, t)!,
      blobRed:        Color.lerp(blobRed, other.blobRed, t)!,
      blobPurple:     Color.lerp(blobPurple, other.blobPurple, t)!,
      errorBorder:    Color.lerp(errorBorder, other.errorBorder, t)!,
      dashedBorder:   Color.lerp(dashedBorder, other.dashedBorder, t)!,
      dotInactive:    Color.lerp(dotInactive, other.dotInactive, t)!,
      dotDone:        Color.lerp(dotDone, other.dotDone, t)!,
    );
  }
}
