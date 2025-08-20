/// Array validation rules
pub type ArrayValidation {
  /// Array must have at least this many elements
  MinLength(Int)
  /// Array must have at most this many elements
  MaxLength(Int)
  /// Array length must be within this range
  LengthRange(min: Int, max: Int)
  /// Array must not be empty
  NotEmpty
  /// Field is required
  Required
}