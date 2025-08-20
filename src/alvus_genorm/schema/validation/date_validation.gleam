/// Date validation rules
pub type DateValidation {
  /// Date must be after this date (ISO format: YYYY-MM-DD)
  After(String)
  /// Date must be before this date (ISO format: YYYY-MM-DD)
  Before(String)
  /// Date must be within this range (inclusive)
  Range(min: String, max: String)
  /// Field is required
  Required
}