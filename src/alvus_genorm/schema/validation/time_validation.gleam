/// Time validation rules
pub type TimeValidation {
  /// Time must be after this time (ISO format: HH:MM:SS)
  After(String)
  /// Time must be before this time (ISO format: HH:MM:SS)
  Before(String)
  /// Time must be within this range (inclusive)
  Range(min: String, max: String)
  /// Field is required
  Required
}