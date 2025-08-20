import gleam/option.{type Option}

pub type Post

pub type User {
  User(id: Int, username: String, bio: Option(String))
}

pub type UserWhereClause {
  WhereId(Int)
  WhereUsername(String)
  WhereBio(Option(String))
  // Could add more complex clauses like WhereIdIn(List(Int)) later
}

/// Type for full users with optional relationships loaded
pub type UserWithRelationships {
  UserWithRelationships(
    id: Int,
    username: String,
    bio: Option(String),
    // Relationships - None if not queried, Some(data) if loaded
    posts: Option(List(Post)),
    // Note: Post type would be imported/generated
  )
}

/// Order by clauses for User model  
pub type UserOrderClause {
  OrderById(Direction)
  OrderByUsername(Direction)
  OrderByBio(Direction)
}

pub type Direction {
  Asc
  Desc
}

/// Query state tracking what has been selected and filtered
pub type UserQueryState {
  UserQueryState(
    where_clauses: List(UserWhereClause),
    relationships: List(String),
    // ["posts"] - relationship names to load
    order_by: List(UserOrderClause),
    limit: Option(Int),
  )
}

/// Full user query (returns User or UserWithRelationships)
pub type UserQuery {
  UserQuery(state: UserQueryState)
}

/// Start a full user query selecting all fields
pub fn all() -> UserQuery {
  // TODO: Initialize with AllFields, empty clauses
  todo
}
