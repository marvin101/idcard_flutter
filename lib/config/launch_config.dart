abstract final class LaunchConfig {
  static const organizationName = String.fromEnvironment(
    'ORGANIZATION_NAME',
    defaultValue: 'CampusID',
  );
  // Keep drafts visible until the operator supplies approved launch content.
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'campusid@proton.me',
  );
  static const supportConfigured =
      supportEmail != '';
  static const supportEmailNotice = supportConfigured
      ? ''
      : '[Replace before launch]';
  static const privacyNotice = String.fromEnvironment('PRIVACY_NOTICE');
  static const termsNotice = String.fromEnvironment('TERMS_NOTICE');
}
