class AppSession {
  static Map<String, dynamic>? currentUser;
  static Map<String, dynamic>? selectedCircle;
  static String? authToken;

  static void setAuth(Map<String, dynamic> user, String token) {
    currentUser = user;
    authToken = token;
  }

  static void logout() {
    currentUser = null;
    selectedCircle = null;
    authToken = null;
  }
}
