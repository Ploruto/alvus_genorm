/// Text field validation rules
pub type TextValidation {
  /// Validates that the field contains a valid email address
  Email
  /// Validates that the field contains a valid URL
  Url
  /// Ensures the field has at least the specified number of characters
  MinLength(Int)
  /// Ensures the field has at most the specified number of characters
  MaxLength(Int)
  /// Validates field against a regular expression pattern
  Regex(String)
  /// Field value must be one of the provided values
  In(List(String))
  /// Field value must not be any of the provided values
  NotIn(List(String))
  /// Validates phone number format
  PhoneNumber
  /// Validates credit card number format
  CreditCard
  /// Validates postal code for a specific country
  PostalCode(country: String)
  /// Field is required (non-empty for strings)
  Required
}