import alvus_genorm/schema.{type FieldType}

pub fn field_type_to_gleam_type_as_string(field_type: FieldType) -> String {
  case field_type {
    schema.BigInt -> "Int"
    schema.Int -> "Int"
    schema.Serial -> "Int"
    schema.Text(_) -> "String"
    schema.UUID -> "String"
  }
}
