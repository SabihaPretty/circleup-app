export function calculateAgeGroupFromBirthYear(birthYear?: number | null) {
  if (!birthYear || Number.isNaN(Number(birthYear))) {
    return 'adult';
  }

  const currentYear = new Date().getFullYear();
  const age = currentYear - Number(birthYear);

  if (age <= 12) return 'kids';
  if (age <= 17) return 'teen';
  if (age >= 60) return 'senior';

  return 'adult';
}

export function calculateAgeGroupFromBirthDate(
  birthYear?: number | null,
  birthMonth?: number | null,
  birthDay?: number | null,
) {
  if (!birthYear || Number.isNaN(Number(birthYear))) {
    return 'adult';
  }

  const today = new Date();
  let age = today.getFullYear() - Number(birthYear);

  if (birthMonth && birthDay) {
    const birthdayThisYear = new Date(
      today.getFullYear(),
      Number(birthMonth) - 1,
      Number(birthDay),
    );

    if (today < birthdayThisYear) {
      age -= 1;
    }
  }

  if (age <= 12) return 'kids';
  if (age <= 17) return 'teen';
  if (age >= 60) return 'senior';

  return 'adult';
}

export function allowedContentAges(ageGroup: string) {
  if (ageGroup === 'kids') return ['kids'];
  if (ageGroup === 'teen') return ['kids', 'teen'];
  if (ageGroup === 'adult') return ['teen', 'adult'];
  if (ageGroup === 'senior') return ['kids', 'teen', 'adult', 'senior'];

  return ['adult'];
}

export function isContentSafeForViewer(viewerAgeGroup: string, contentAgeGroup: string) {
  return allowedContentAges(viewerAgeGroup).includes(contentAgeGroup);
}

export function allowedConnectionAges(ageGroup: string) {
  if (ageGroup === 'kids') return ['kids'];
  if (ageGroup === 'teen') return ['teen'];
  if (ageGroup === 'adult') return ['adult', 'senior'];
  if (ageGroup === 'senior') return ['adult', 'senior'];

  return ['adult'];
}

export function canConnectSafely(myAgeGroup: string, targetAgeGroup: string) {
  return allowedConnectionAges(myAgeGroup).includes(targetAgeGroup);
}
