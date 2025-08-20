/// UUID validation rules
pub type UuidValidation {
  /// Field is required
  Required
  /// UUID must be a specific version (1, 4, etc.)
  Version(Int)
}