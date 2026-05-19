class AccessControl {
  static String calculateAgeGroupFromYear(String birthYearText) {
    final birthYear = int.tryParse(birthYearText);

    if (birthYear == null) return 'adult';

    return calculateAgeGroupFromDate(
      birthYear: birthYear,
      birthMonth: 1,
      birthDay: 1,
    );
  }

  static String calculateAgeGroupFromDate({
    required int birthYear,
    required int birthMonth,
    required int birthDay,
  }) {
    final today = DateTime.now();
    var age = today.year - birthYear;
    final birthdayThisYear = DateTime(today.year, birthMonth, birthDay);

    if (today.isBefore(birthdayThisYear)) {
      age -= 1;
    }

    if (age <= 12) return 'kids';
    if (age <= 17) return 'teen';
    if (age >= 60) return 'senior';

    return 'adult';
  }

  static int calculateAge({
    required int birthYear,
    required int birthMonth,
    required int birthDay,
  }) {
    final today = DateTime.now();
    var age = today.year - birthYear;
    final birthdayThisYear = DateTime(today.year, birthMonth, birthDay);

    if (today.isBefore(birthdayThisYear)) {
      age -= 1;
    }

    return age;
  }

  static List<String> allowedContentAges(String ageGroup) {
    if (ageGroup == 'kids') return ['kids'];
    if (ageGroup == 'teen') return ['kids', 'teen'];
    if (ageGroup == 'adult') return ['teen', 'adult'];
    if (ageGroup == 'senior') return ['kids', 'teen', 'adult', 'senior'];

    return ['adult'];
  }

  static List<String> allowedConnectionAges(String ageGroup) {
    if (ageGroup == 'kids') return ['kids'];
    if (ageGroup == 'teen') return ['teen'];
    if (ageGroup == 'adult') return ['adult', 'senior'];
    if (ageGroup == 'senior') return ['adult', 'senior'];

    return ['adult'];
  }

  static bool canSeeContent(String viewerAge, String contentAge) {
    return allowedContentAges(viewerAge).contains(contentAge);
  }

  static bool canConnect(String myAge, String targetAge) {
    return allowedConnectionAges(myAge).contains(targetAge);
  }

  static bool canUseFeature(String ageGroup, String feature) {
    if (ageGroup == 'kids') {
      return ['feed', 'explore', 'chat', 'profile'].contains(feature);
    }

    if (ageGroup == 'teen') {
      return ['feed', 'explore', 'reels', 'people', 'circles', 'chat', 'help', 'profile'].contains(feature);
    }

    if (ageGroup == 'adult') {
      return ['feed', 'explore', 'reels', 'shop', 'people', 'circles', 'chat', 'help', 'profile'].contains(feature);
    }

    if (ageGroup == 'senior') {
      return ['feed', 'explore', 'reels', 'shop', 'people', 'circles', 'chat', 'help', 'profile'].contains(feature);
    }

    return ['feed', 'profile'].contains(feature);
  }

  static String ageGroupLabel(String ageGroup) {
    if (ageGroup == 'kids') return 'Kids Safe';
    if (ageGroup == 'teen') return 'Teen Safe';
    if (ageGroup == 'adult') return 'Adult';
    if (ageGroup == 'senior') return 'Senior Citizen';

    return 'Adult';
  }

  static String accessDescription(String ageGroup) {
    if (ageGroup == 'kids') {
      return 'Kids can use safe Feed, Explore, Chat and Profile. Kids connect to guardians only by code.';
    }

    if (ageGroup == 'teen') {
      return 'Teenagers can access kids + teen safe content, and connect only with teens.';
    }

    if (ageGroup == 'adult') {
      return 'Adults can access teen + adult content, and connect with adults/seniors.';
    }

    if (ageGroup == 'senior') {
      return 'Senior citizens can access all content, and connect with adults/seniors.';
    }

    return 'Default safe access.';
  }
}
