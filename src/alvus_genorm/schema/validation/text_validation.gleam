import gleam/list
import gleam/string

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

/// Mirrored error types for text validation failures
pub type TextValidationError {
  EmailError(value: String)
  UrlError(value: String)
  MinLengthError(required: Int, actual: Int, value: String)
  MaxLengthError(max: Int, actual: Int, value: String)
  RegexError(pattern: String, value: String)
  InError(allowed: List(String), value: String)
  NotInError(forbidden: List(String), value: String)
  PhoneNumberError(value: String)
  CreditCardError(value: String)
  PostalCodeError(country: String, value: String)
  RequiredError
}

/// Validate a string value against a text validation rule
pub fn validate(
  value: String,
  rule: TextValidation,
) -> Result(String, TextValidationError) {
  case rule {
    Required -> {
      case string.trim(value) {
        "" -> Error(RequiredError)
        _ -> Ok(value)
      }
    }
    MinLength(min) -> {
      let actual = string.length(value)
      case actual >= min {
        True -> Ok(value)
        False ->
          Error(MinLengthError(required: min, actual: actual, value: value))
      }
    }
    MaxLength(max) -> {
      let actual = string.length(value)
      case actual <= max {
        True -> Ok(value)
        False -> Error(MaxLengthError(max: max, actual: actual, value: value))
      }
    }
    In(allowed) -> {
      case list.contains(allowed, value) {
        True -> Ok(value)
        False -> Error(InError(allowed: allowed, value: value))
      }
    }
    NotIn(forbidden) -> {
      case list.contains(forbidden, value) {
        True -> Error(NotInError(forbidden: forbidden, value: value))
        False -> Ok(value)
      }
    }
    Email -> {
      // TODO: Implement proper email validation
      case string.contains(value, "@") {
        True -> Ok(value)
        False -> Error(EmailError(value))
      }
    }
    Url -> {
      // TODO: Implement proper URL validation
      case string.starts_with(value, "http") {
        True -> Ok(value)
        False -> Error(UrlError(value))
      }
    }
    Regex(_pattern) -> {
      // TODO: Implement regex validation when regex support is available
      Ok(value)
    }
    PhoneNumber -> {
      // TODO: Implement phone number validation
      Ok(value)
    }
    CreditCard -> {
      // TODO: Implement credit card validation
      Ok(value)
    }
    PostalCode(_country) -> {
      // TODO: Implement country-specific postal code validation
      Ok(value)
    }
  }
}

/// Validate a string against multiple text validation rules
pub fn validate_all(
  value: String,
  rules: List(TextValidation),
) -> Result(String, List(TextValidationError)) {
  let errors =
    rules
    |> list.filter_map(fn(rule) {
      case validate(value, rule) {
        Ok(_) -> Error(Nil)
        Error(err) -> Ok(err)
      }
    })

  case errors {
    [] -> Ok(value)
    _ -> Error(errors)
  }
}
