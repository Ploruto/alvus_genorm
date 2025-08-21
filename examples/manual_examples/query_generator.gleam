import alvus_genorm/schema.{type Model}
import gleam/list
import gleam/option.{type Option}

const user_schema = schema.Model(
  table_name: "users",
  relationships: [
    schema.HasMany(
      target_table: "posts",
      local_key: "id",
      foreign_key: "author_id",
      as_name: "posts",
    ),
  ],
  fields: [
    schema.Field(
      column_name: "id",
      attributes: [schema.PrimaryKey],
      field_type: schema.Serial([]),
    ),
    schema.Field(
      column_name: "username",
      attributes: [schema.PrimaryKey],
      field_type: schema.Text(50, []),
    ),
    schema.Field(
      column_name: "bio",
      attributes: [schema.Nullable],
      field_type: schema.Text(1400, []),
    ),
  ],
)

// this is what is being generated already (from model generator):
pub type UserField {
  UserId
  UserUsername
  UserBio
}
// ============ PAGINATION SUPPORT ============

// pub type PaginatedUserResult {
//   PaginatedUserResult(
//     data: List(UserWithRelationships),
//     total_count: Int,
//     page: Int,
//     per_page: Int,
//     has_next: Bool,
//   )
// }

// pub fn with_pagination(query: UserQuery, page: Int, per_page: Int) -> UserQuery {
//   // TODO: Add pagination info to query state
//   todo
// }

// pub fn execute_with_pagination(
//   query: UserQuery,
// ) -> Result(PaginatedUserResult, Error) {
//   // TODO: Execute with LIMIT/OFFSET and separate COUNT query
//   todo
// }
