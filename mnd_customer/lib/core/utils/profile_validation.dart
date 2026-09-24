/// Shared name/email rules for the complete-profile and edit-profile pages,
/// kept in step with [CustomerProfile.hasRealName] so a saved name never
/// sends the customer back to the setup step.
enum ProfileNameError { empty, tooShort, tooLong, placeholder }

const int kProfileNameMinLength = 2;
const int kProfileNameMaxLength = 80;

/// Name the profile falls back to when none is saved; not a real name.
const String kPlaceholderCustomerName = 'Customer';

ProfileNameError? validateProfileName(String? value) {
  final String t = (value ?? '').trim();
  if (t.isEmpty) {
    return ProfileNameError.empty;
  }
  if (t.length < kProfileNameMinLength) {
    return ProfileNameError.tooShort;
  }
  if (t.length > kProfileNameMaxLength) {
    return ProfileNameError.tooLong;
  }
  if (t.toLowerCase() == kPlaceholderCustomerName.toLowerCase()) {
    return ProfileNameError.placeholder;
  }
  return null;
}

final RegExp _emailPattern = RegExp(
  r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
);

/// Empty is valid (email is optional); otherwise needs user@domain.tld.
bool isValidOptionalEmail(String? value) {
  final String t = (value ?? '').trim();
  return t.isEmpty || _emailPattern.hasMatch(t);
}
