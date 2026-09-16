abstract final class LaunchConfig {
  static const organizationName = String.fromEnvironment(
    'ORGANIZATION_NAME',
    defaultValue: 'CampusID',
  );

  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'campusid@proton.me',
  );
  static const supportConfigured = supportEmail != '';
  static const supportEmailNotice = supportConfigured
      ? ''
      : '[Replace before launch]';

  static const operatorName = 'Paul Lakra';

  static const operatorAddress =
      'P.O. Bijuliya, Ratu, 835222, Ranchi, Jharkhand, India';

  static const jurisdiction = 'Ranchi, Jharkhand, India';

  static const legalEffectiveDate = '16 September 2026';
}
