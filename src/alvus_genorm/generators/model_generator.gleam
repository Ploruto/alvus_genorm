/// This module is responsible for generating Gleam code for database models
/// based on a `schema.Model` definition. It creates the main model type
/// definition as well as a type for the model's fields.
import alvus_genorm/generators/helpers/data_helpers.{
  field_type_to_gleam_type_as_string,
}
import alvus_genorm/schema.{type Field, type Model}
import alvus_inflector/inflector
import gleam/io
import gleam/list
import gleam/string

// example:
/// A development helper function to demonstrate the code generation.
pub fn dev_example() {
  let d =
    schema.Model(
      table_name: "users",
      fields: [
        schema.Field(column_name: "id", field_type: schema.UUID, attributes: [
          schema.Indexed,
        ]),
        schema.Field(
          column_name: "bio_entry",
          field_type: schema.Text(1200),
          attributes: [],
        ),
      ],
      relationships: [],
    )

  echo get_model_type_name(d)
  echo get_model_type_field_names(d)
  echo codegen_model_type(d)
  echo codegen_model_fields(d)
  echo codegen_partial_model_type(d)
  Nil
}

/// Generates a Gleam type name from a database table name.
///
/// ## Examples
///
/// ```gleam
/// get_model_type_name(schema.Model(table_name: "users", ..))
/// // -> "User"
/// ```
///
/// ```gleam
/// get_model_type_name(schema.Model(table_name: "user_profiles", ..))
/// // -> "UserProfile"
/// ```
fn get_model_type_name(model: schema.Model) -> String {
  inflector.classify(model.table_name)
}

/// Generates a list of field type names for a given model.
///
/// The names are constructed by prepending the model's type name to each
/// classified field name.
///
/// ## Example
///
/// ```gleam
/// let model = schema.Model(
///   table_name: "users",
///   fields: [
///     schema.Field(column_name: "id", ..),
///     schema.Field(column_name: "bio_entry", ..),
///   ],
///   ..
/// )
/// get_model_type_field_names(model)
/// // -> ["UserId", "UserBioEntry"]
/// ```
fn get_model_type_field_names(model: schema.Model) -> List(String) {
  let type_name = get_model_type_name(model)
  model.fields
  |> list.map(fn(field) { field.column_name |> inflector.classify })
  |> list.map(fn(field_name) { string.append(type_name, field_name) })
}

/// Generates the `pub type` definition for a model.
///
/// This creates a Gleam type with a single constructor containing all the
/// fields of the model. The generated code is formatted for readability.
///
/// ## Example
///
/// For a `User` model with `id` and `full_name` fields, it generates:
///
/// ```gleam
/// pub type User {
///   User(
///     id: UUID,
///     full_name: String
///   )
/// }
/// ```
fn codegen_model_type(model: schema.Model) -> String {
  let type_name = get_model_type_name(model)
  let field_types_with_annotation =
    model.fields
    |> list.map(fn(field) {
      let field_name =
        field.column_name |> inflector.transform([inflector.Underscore])
      let gleam_type_as_string = field |> field_type_to_gleam_type_as_string

      "    " <> field_name <> ": " <> gleam_type_as_string
    })

  "pub type " <> type_name <> " {
" <> "  " <> type_name <> "(
" <> string.join(
    field_types_with_annotation,
    ",
",
  ) <> "
" <> "  )
" <> "}"
}

/// Generates the `pub type` definition for a partial model with optional fields.
///
/// This creates a Gleam type with a single constructor containing all the
/// fields of the model wrapped in `Option(...)`. This is useful for partial
/// updates or when some fields may not be present.
/// ## Example
///
/// For a `User` model with `id` and `full_name` fields, it generates:
///
/// ```gleam
/// pub type PartialUser {
///   PartialUser(
///     id: Option(String),
///     full_name: Option(String)
///   )
/// }
/// ```
///
/// Note: If a field is already nullable in the database (has `Nullable` attribute),
/// the partial type will be `Option(Option(...))`. For example, a nullable bio field
/// would become `bio: Option(Option(String))` in the partial type.
fn codegen_partial_model_type(model: schema.Model) -> String {
  let type_name = "Partial" <> get_model_type_name(model)
  let field_types_with_annotation =
    model.fields
    |> list.map(fn(field) {
      let field_name =
        field.column_name |> inflector.transform([inflector.Underscore])
      let gleam_type_as_string = field |> field_type_to_gleam_type_as_string

      "    " <> field_name <> ": Option(" <> gleam_type_as_string <> ")"
    })

  "pub type " <> type_name <> " {
" <> "  " <> type_name <> "(
" <> string.join(
    field_types_with_annotation,
    ",
",
  ) <> "
" <> "  )
" <> "}"
}

/// Generates a `pub type` for the fields of a model.
///
/// This is useful for creating a type-safe way to reference model fields.
/// The generated code is formatted for readability.
///
/// ## Example
///
/// For a `User` model with `id` and `bio_entry` fields, it generates:
///
/// ```gleam
/// pub type UserField {
///   UserId
///   UserBioEntry
/// }
/// ```
fn codegen_model_fields(model: schema.Model) -> String {
  let model_name = get_model_type_name(model)
  let field_names = get_model_type_field_names(model)

  "pub type " <> model_name <> "Field" <> " {
" <> "  " <> string.join(
    field_names,
    "
  ",
  ) <> "
}"
}
