class AgoraConfig {
  // Agora App ID for test mode
  static const String appId = 'ef1a1d0d999f4d73b034428f6f5a28ce';
  
  // Generate channel name for a class
  static String getClassChannelName(String classId) {
    return 'class_$classId';
  }

  // Fixed UIDs for consistent peer identification
  static const int teacherBaseUid = 1000;
  static const int studentBaseUid = 2000;
  
  // Generate UID for teacher
  static int getTeacherUid(String teacherId) {
    return teacherBaseUid + teacherId.hashCode.abs() % 1000;
  }
  
  // Generate UID for student
  static int getStudentUid(String studentId) {
    return studentBaseUid + studentId.hashCode.abs() % 1000;
  }
}

