enum ConversionJobStatus {
  pending,
  converting,
  optimizing,
  done,
  error,
}

class ConversionJob {
  final String inputPath;
  ConversionJobStatus status;
  double progress;
  String? outputPath;
  String? errorMessage;
  int? outputFileSize;
  String statusText;

  ConversionJob({
    required this.inputPath,
    this.status = ConversionJobStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    this.outputFileSize,
    this.statusText = '',
  });
}
