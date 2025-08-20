/// Decimal validation rules
pub type DecimalValidation {
  /// Minimum allowed value (as string to preserve precision)
  Min(String)
  /// Maximum allowed value (as string to preserve precision)
  Max(String)
  /// Value must be within this range (inclusive)
  Range(min: String, max: String)
  /// Value must be positive
  Positive
  /// Value must be non-negative
  NonNegative
  /// Field is required
  Required
}