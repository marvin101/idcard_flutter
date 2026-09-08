import 'card_template.dart';
import 'school_profile.dart';

class PublicDesignShare {
  const PublicDesignShare({required this.enabled, this.publicToken});

  final bool enabled;
  final String? publicToken;

  factory PublicDesignShare.fromJson(Map<String, dynamic> json) =>
      PublicDesignShare(
        enabled: json['enabled'] == true,
        publicToken: json['public_token'] as String?,
      );
}

class PublicDesignView {
  const PublicDesignView({required this.template, required this.school});

  final CardTemplate template;
  final SchoolProfile school;

  factory PublicDesignView.fromJson(Map<String, dynamic> json) {
    final school = json['school'];
    if (school is! Map) {
      throw const FormatException('Public design school profile is invalid.');
    }
    return PublicDesignView(
      template: CardTemplate.fromApi({
        'name': json['name'],
        'design': json['design'],
      }),
      school: SchoolProfile.fromJson(Map<String, dynamic>.from(school)),
    );
  }
}
