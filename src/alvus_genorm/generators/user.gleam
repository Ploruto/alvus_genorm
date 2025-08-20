import gleam/list
import gleam/option.{type Option}

// Types that would be imported/generated
pub type Post

pub type Error

/// Type for full users with optional relationships loaded
pub type UserWithRelationships {
  UserWithRelationships(
    id: Int,
    username: String,
    bio: Option(String),
    // Relationships - None if not queried, Some(data) if loaded
    posts: Option(List(Post)),
  )
}

/// Query state for full queries (always all fields, optional relationships)
pub type UserQueryState {
  UserQueryState(
    where_clauses: List(UserWhereClause),
    relationships: List(String),
    // ["posts"] - relationship names to load
    order_by: List(UserOrderClause),
    limit: Option(Int),
  )
}

/// Type-safe where clauses for User model
pub type UserWhereClause {
  WhereId(Int)
  WhereUsername(String)
  WhereBio(Option(String))
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

/// Full user query (always returns all fields, optional relationships)
pub type UserQuery {
  UserQuery(state: UserQueryState)
}

// ============ QUERY BUILDER FUNCTIONS ============

/// Start a full user query selecting all fields
pub fn all() -> UserQuery {
  UserQuery(UserQueryState(
    where_clauses: [],
    relationships: [],
    order_by: [],
    limit: option.None,
  ))
}

// ============ WHERE CLAUSE BUILDERS ============

/// Add where clause for id field
pub fn where_id(query: UserQuery, id: Int) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, where_clauses: [WhereId(id), ..state.where_clauses]),
  )
}

/// Add where clause for username field
pub fn where_username(query: UserQuery, username: String) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, where_clauses: [
      WhereUsername(username),
      ..state.where_clauses
    ]),
  )
}

/// Add where clause for bio field
pub fn where_bio(query: UserQuery, bio: Option(String)) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, where_clauses: [
      WhereBio(bio),
      ..state.where_clauses
    ]),
  )
}

// ============ RELATIONSHIP LOADERS ============

/// Load posts relationship
pub fn with_posts(query: UserQuery) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, relationships: ["posts", ..state.relationships]),
  )
}

// ============ ORDER BY BUILDERS ============

pub fn order_by_id(query: UserQuery, direction: Direction) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, order_by: [OrderById(direction), ..state.order_by]),
  )
}

pub fn order_by_username(query: UserQuery, direction: Direction) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, order_by: [
      OrderByUsername(direction),
      ..state.order_by
    ]),
  )
}

pub fn order_by_bio(query: UserQuery, direction: Direction) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(
    UserQueryState(..state, order_by: [OrderByBio(direction), ..state.order_by]),
  )
}

// ============ LIMIT BUILDERS ============

pub fn limit(query: UserQuery, count: Int) -> UserQuery {
  let UserQuery(state) = query
  UserQuery(UserQueryState(..state, limit: option.Some(count)))
}

// ============ EXECUTION FUNCTIONS ============

/// Execute full user query, returns users with optional relationships
pub fn execute(query: UserQuery) -> Result(List(UserWithRelationships), Error) {
  // TODO: 
  // 1. Generate main SQL from query state (all fields)
  // 2. Execute main query  
  // 3. If relationships requested, execute relationship queries
  // 4. Combine results into UserWithRelationships
  todo
}

// ============ PAGINATION SUPPORT ============

pub type PaginatedUserResult {
  PaginatedUserResult(
    data: List(UserWithRelationships),
    total_count: Int,
    page: Int,
    per_page: Int,
    has_next: Bool,
  )
}

pub fn with_pagination(query: UserQuery, page: Int, per_page: Int) -> UserQuery {
  // TODO: Add pagination info to query state
  todo
}

pub fn execute_with_pagination(
  query: UserQuery,
) -> Result(PaginatedUserResult, Error) {
  // TODO: Execute with LIMIT/OFFSET and separate COUNT query
  todo
}
