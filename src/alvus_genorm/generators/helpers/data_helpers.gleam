import alvus_genorm/schema.{type Field}
import gleam/list

pub fn field_type_to_gleam_type_as_string(field: Field) -> String {
  let optional = is_field_optional(field)
  let base_type = case field.field_type {
    schema.BigInt -> "Int"
    schema.Int -> "Int"
    schema.Serial -> "Int"
    schema.Text(_) -> "String"
    schema.UUID -> "String"
  }
  case optional {
    True -> "Option(" <> base_type <> ")"
    _ -> base_type
  }
}

fn is_field_optional(field: Field) -> Bool {
  field.attributes
  |> list.any(fn(attr) { [schema.Nullable] |> list.contains(attr) })
}
