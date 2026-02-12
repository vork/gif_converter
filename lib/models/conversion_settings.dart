class ConversionSettings {
  final int? width;
  final int fps;
  final bool loop;
  final bool useLocalColorTables;
  final String ditherMode;
  final int bayerScale;
  final bool enableLossyCompression;
  final int lossyLevel;

  const ConversionSettings({
    this.width,
    this.fps = 15,
    this.loop = true,
    this.useLocalColorTables = true,
    this.ditherMode = 'bayer',
    this.bayerScale = 3,
    this.enableLossyCompression = false,
    this.lossyLevel = 40,
  });

  ConversionSettings copyWith({
    int? Function()? width,
    int? fps,
    bool? loop,
    bool? useLocalColorTables,
    String? ditherMode,
    int? bayerScale,
    bool? enableLossyCompression,
    int? lossyLevel,
  }) {
    return ConversionSettings(
      width: width != null ? width() : this.width,
      fps: fps ?? this.fps,
      loop: loop ?? this.loop,
      useLocalColorTables: useLocalColorTables ?? this.useLocalColorTables,
      ditherMode: ditherMode ?? this.ditherMode,
      bayerScale: bayerScale ?? this.bayerScale,
      enableLossyCompression:
          enableLossyCompression ?? this.enableLossyCompression,
      lossyLevel: lossyLevel ?? this.lossyLevel,
    );
  }

  static const List<int?> widthPresets = [
    null,
    256,
    320,
    480,
    512,
    640,
    800,
    1024,
  ];

  static const List<int> fpsPresets = [10, 15, 20, 24, 30];

  static const List<String> ditherModes = [
    'bayer',
    'floyd_steinberg',
    'sierra2_4a',
    'none',
  ];

  static String ditherModeLabel(String mode) {
    switch (mode) {
      case 'bayer':
        return 'Bayer (ordered)';
      case 'floyd_steinberg':
        return 'Floyd-Steinberg';
      case 'sierra2_4a':
        return 'Sierra';
      case 'none':
        return 'None';
      default:
        return mode;
    }
  }
}
