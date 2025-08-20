/// Float/Double validation rules
pub type FloatValidation {
  /// Minimum allowed value
  Min(Float)
  /// Maximum allowed value
  Max(Float)
  /// Value must be within this range (inclusive)
  Range(min: Float, max: Float)
  /// Value must be positive (> 0.0)
  Positive
  /// Value must be non-negative (>= 0.0)
  NonNegative
  /// Field is required
  Required
}