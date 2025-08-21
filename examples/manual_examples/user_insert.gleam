import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import pog

import alvus_genorm/query_helpers.{
  type DatabaseError, add_parameters_to_query, execute_query_with_connection,
}
import alvus_genorm/schema/validation/text_validation.{
  type TextValidationError, validate_all,
}

// Phantom types for compile-time field tracking
pub type UsernameMissing

pub type BioMissing

pub type Validated

// Field enum for error tracking
pub type UserField {
  UsernameField
  BioField
}

// INSERT query that tracks phantom types AND accumulates validation errors
pub type UserInsertQuery(username_status, bio_status) {
  UserInsertQuery(
    username: Option(String),
    bio: Option(String),
    errors: List(#(UserField, UserInsertError)),
  )
}

// ============ FIELD VALIDATION ERRORS ============

pub type UserInsertError {
  UsernameValidationError(List(TextValidationError))
  BioValidationError(List(TextValidationError))
  DatabaseError(DatabaseError)
}

// ============ VALIDATED INSERT API ============

pub fn new() -> UserInsertQuery(UsernameMissing, BioMissing) {
  UserInsertQuery(username: option.None, bio: option.None, errors: [])
}

pub fn username(
  query: UserInsertQuery(UsernameMissing, bio_status),
  value: String,
) -> UserInsertQuery(Validated, bio_status) {
  // Apply username validation rules from schema
  let validation_rules = [
    text_validation.Required,
    text_validation.MaxLength(255),
    text_validation.MinLength(10),
    // TODO: Get from schema
  ]

  case validate_all(value, validation_rules) {
    Ok(validated_value) ->
      UserInsertQuery(..query, username: option.Some(validated_value))
    Error(errors) -> {
      let new_error = #(UsernameField, UsernameValidationError(errors))
      UserInsertQuery(..query, errors: [new_error, ..query.errors])
    }
  }
}

pub fn bio(
  query: UserInsertQuery(username_status, bio_status),
  value: String,
) -> UserInsertQuery(username_status, Validated) {
  // Apply bio validation rules from schema
  let validation_rules = [
    text_validation.MaxLength(1400),
    // TODO: Get from schema
  ]

  case validate_all(value, validation_rules) {
    Ok(validated_value) ->
      UserInsertQuery(..query, bio: option.Some(validated_value))
    Error(errors) -> {
      let new_error = #(BioField, BioValidationError(errors))
      UserInsertQuery(..query, errors: [new_error, ..query.errors])
    }
  }
}

// Execute - only compiles if username is provided (required field)
// Bio is optional so any bio_status is allowed
pub fn execute(
  query: UserInsertQuery(Validated, bio_status),
) -> Result(InsertedUser, List(#(UserField, UserInsertError))) {
  // Check for validation errors first
  case query.errors {
    [] -> {
      // No validation errors, proceed with database insert
      case build_insert_sql(query) {
        Ok(#(sql, parameters)) -> {
          let pog_query =
            pog.query(sql)
            |> pog.returning(user_decoder())
            |> add_parameters_to_query(parameters)

          case start_database() {
            Ok(db) -> {
              case execute_query_with_connection(pog_query, db, "insert user") {
                Ok([user]) -> Ok(user)
                Ok([]) ->
                  Error([
                    #(
                      UsernameField,
                      DatabaseError(query_helpers.GenericError(
                        "No user returned",
                      )),
                    ),
                  ])
                Ok(_) ->
                  Error([
                    #(
                      UsernameField,
                      DatabaseError(query_helpers.GenericError(
                        "Multiple users returned",
                      )),
                    ),
                  ])
                Error(db_err) ->
                  Error([#(UsernameField, DatabaseError(db_err))])
              }
            }
            Error(db_err) -> Error([#(UsernameField, DatabaseError(db_err))])
          }
        }
        Error(err) -> Error([#(UsernameField, err)])
      }
    }
    errors -> Error(errors)
  }
}

// ============ SQL GENERATION ============

fn build_insert_sql(
  query: UserInsertQuery(Validated, bio_status),
) -> Result(#(String, List(pog.Value)), UserInsertError) {
  // Since we have Validated phantom type, username must be present
  case query.username {
    option.Some(username) -> {
      let #(columns, parameters) = case query.bio {
        option.Some(bio) -> #(["username", "bio"], [
          pog.text(username),
          pog.text(bio),
        ])
        option.None -> #(["username"], [pog.text(username)])
      }

      let column_list = string.join(columns, ", ")
      let placeholders =
        list.range(1, list.length(parameters))
        |> list.map(fn(idx) { "$" <> int.to_string(idx) })
        |> string.join(", ")

      let sql =
        "INSERT INTO users ("
        <> column_list
        <> ") VALUES ("
        <> placeholders
        <> ") RETURNING id, username, bio"

      Ok(#(sql, parameters))
    }
    option.None -> {
      // This should never happen with phantom types, but we handle it for safety
      Error(
        DatabaseError(query_helpers.GenericError(
          "Username is required but not provided",
        )),
      )
    }
  }
}

// ============ DECODING ============

import gleam/dynamic/decode

pub type InsertedUser {
  InsertedUser(id: Int, username: String, bio: Option(String))
}

fn user_decoder() {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  use bio <- decode.field(2, decode.optional(decode.string))
  decode.success(InsertedUser(id: id, username: username, bio: bio))
}

// ============ DATABASE CONNECTION ============

import gleam/erlang/process
import gleam/io

fn start_database() -> Result(pog.Connection, DatabaseError) {
  let pool_name = process.new_name("db_pool")

  let config =
    pog.default_config(pool_name)
    |> pog.host("localhost")
    |> pog.port(5432)
    |> pog.database("genau_db")
    |> pog.user("postgres")
    |> pog.password(option.None)

  case pog.start(config) {
    Ok(started) -> Ok(started.data)
    Error(_) -> {
      io.println_error("Failed to connect to database")
      Error(query_helpers.DatabaseConnectionError)
    }
  }
}

// ============ EXAMPLES ============

pub fn example_usage() {
  // Great UX - accumulates all errors
  let insert_query =
    new()
    |> username("a")
    // Too short, will add validation error
    |> bio(
      "This bio is way too long and exceeds the maximum length allowed by the database schema which should be 1400 characters but this text is designed to be much longer than that limit to trigger a validation error that will be accumulated in the errors list rather than immediately failing the entire operation allowing the user to see all validation issues at once instead of having to fix them one by one",
    )
  // Too long, will add validation error

  // Execute and get all validation errors at once
  case execute(insert_query) {
    Ok(user) -> {
      io.println("User inserted successfully!")
      Ok(user)
    }
    Error(errors) -> {
      io.println("Validation errors:")
      errors
      |> list.each(fn(error) {
        let #(field, error_details) = error
        case field {
          UsernameField ->
            io.println("Username: " <> string.inspect(error_details))
          BioField -> io.println("Bio: " <> string.inspect(error_details))
        }
      })
      Error(errors)
    }
  }
}

pub fn example_wont_succeed() {
  let res = new() |> bio("test") |> username("Too short") |> execute()
  case res {
    Ok(a) -> {
      echo a
      Nil
    }
    Error(err) -> {
      echo err
      Nil
    }
  }
}
