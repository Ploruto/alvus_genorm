/// Integer field validation rules
pub type IntValidation {
  /// Minimum allowed value
  Min(Int)
  /// Maximum allowed value
  Max(Int)
  /// Value must be within this range (inclusive)
  Range(min: Int, max: Int)
  /// Value must be one of the provided values
  In(List(Int))
  /// Value must not be any of the provided values
  NotIn(List(Int))
  /// Value must be positive (> 0)
  Positive
  /// Value must be non-negative (>= 0)
  NonNegative
  /// Field is required
  Required
}