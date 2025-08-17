import alvus_genorm/generators/helpers/data_helpers.{
  field_type_to_gleam_type_as_string,
}
import alvus_genorm/schema.{type Field, type Model}
import alvus_inflector/inflector
import gleam/list
import gleam/set
import gleam/string

// example:
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

  echo codegen_model_fields(d)
  Nil
}

/// Turns `model: {table_name: "users"} -> "User"`
fn get_model_type_name(model: schema.Model) -> String {
  inflector.classify(model.table_name)
}

/// Turns `{table_name: "users", fields: [Field(column_name: "bio", ..)]}
/// -> "[UserBio, ...]"
fn get_model_type_field_names(model: schema.Model) -> List(String) {
  let type_name = get_model_type_name(model)
  model.fields
  |> list.map(fn(field) { field.column_name |> inflector.classify })
  |> list.map(fn(field_name) { string.append(type_name, field_name) })
}

fn codegen_model_type(model: schema.Model) -> String {
  let type_name = get_model_type_name(model)
  let field_types_with_annotation =
    model.fields
    |> list.map(fn(field) {
      let field_name =
        field.column_name |> inflector.transform([inflector.Underscore])
      let gleam_type_as_string =
        field.field_type |> field_type_to_gleam_type_as_string

      field_name <> ": " <> gleam_type_as_string
    })

  echo type_name
  echo field_types_with_annotation

  "pub type "
  <> type_name
  <> " {"
  <> type_name
  <> "("
  <> string.join(field_types_with_annotation, ", ")
  <> ")"
  <> "}"
}

/// This generates something like:
/// `type UserField {
/// UserId
/// UserBio
/// }`
fn codegen_model_fields(model: schema.Model) -> String {
  let model_name = get_model_type_name(model)
  let field_names = get_model_type_field_names(model)

  "pub type "
  <> model_name
  <> "Field"
  <> " {"
  <> string.join(field_names, " ")
  <> "}"
}
