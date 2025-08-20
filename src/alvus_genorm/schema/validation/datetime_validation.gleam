/// DateTime validation rules
pub type DateTimeValidation {
  /// DateTime must be after this datetime (ISO format)
  After(String)
  /// DateTime must be before this datetime (ISO format)
  Before(String)
  /// DateTime must be within this range (inclusive)
  Range(min: String, max: String)
  /// Field is required
  Required
}