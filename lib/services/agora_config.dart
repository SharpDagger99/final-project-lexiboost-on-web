class AgoraConfig {
  // Agora App ID
  static const String appId = 'ad58fb30521d4a2ba58e9fa663d8557b';

  // Optional: For token-based authentication
  static const String token =
      ''; // Leave empty for testing, generate token for production

  // Primary Certificate
  static const String primaryCertificate = '16b55f42cdb14dd89d30e6afa2b76a28';

  // Channel naming convention
  static String getClassChannelName(String classId) {
    return 'class_$classId';
  }
}
