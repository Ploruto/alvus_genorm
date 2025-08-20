/// Binary validation rules
pub type BinaryValidation {
  /// Binary data must be at least this many bytes
  MinSize(Int)
  /// Binary data must be at most this many bytes
  MaxSize(Int)
  /// Binary data size must be within this range
  SizeRange(min: Int, max: Int)
  /// Field is required
  Required
}