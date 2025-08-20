/// JSON validation rules
pub type JsonValidation {
  /// Field is required (not null)
  Required
  /// JSON must contain this key at root level
  HasKey(String)
  /// JSON must validate against a JSON Schema (as string)
  Schema(String)
}