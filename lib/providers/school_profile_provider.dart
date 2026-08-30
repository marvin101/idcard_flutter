import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/school_profile.dart';
import '../services/api_service.dart';

class SchoolProfileProvider extends ChangeNotifier {
  SchoolProfileProvider({
    required this.api,
    required this.schoolUuid,
    required this.canEdit,
    bool autoLoad = true,
  }) {
    if (autoLoad) load();
  }

  static const maxLogoBytes = 2 * 1024 * 1024;
  static const allowedLogoExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  final ApiService api;
  final String schoolUuid;
  final bool canEdit;

  SchoolProfile? profile;
  XFile? selectedLogo;
  Uint8List? selectedLogoBytes;
  bool loading = false;
  bool saving = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await api.getSchoolProfile(schoolUuid);
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Unable to load the school profile.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> chooseLogo(XFile logo) async {
    if (!canEdit) {
      throw const ApiException(403, 'This school profile is read-only.');
    }
    final lowerName = logo.name.toLowerCase();
    if (!allowedLogoExtensions.any(lowerName.endsWith)) {
      error = 'Choose a JPEG, PNG or WebP school logo.';
      notifyListeners();
      return;
    }
    final bytes = await logo.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxLogoBytes) {
      error = 'School logo must be a non-empty image no larger than 2 MB.';
      notifyListeners();
      return;
    }
    selectedLogo = logo;
    selectedLogoBytes = bytes;
    error = null;
    notifyListeners();
  }

  Future<bool> save(SchoolProfile draft) async {
    if (!canEdit) {
      error = 'This school profile is read-only.';
      notifyListeners();
      return false;
    }

    saving = true;
    error = null;
    notifyListeners();
    try {
      profile = await api.updateSchoolProfile(draft);
      if (selectedLogo != null) {
        profile = await api.uploadSchoolLogo(
          schoolUuid: schoolUuid,
          logo: selectedLogo!,
        );
      }
      selectedLogo = null;
      selectedLogoBytes = null;
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Unable to save the school profile.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
