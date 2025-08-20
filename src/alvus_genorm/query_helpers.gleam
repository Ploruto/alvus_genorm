/// Helper functions for building SQL queries that can be shared across generated query builders.
/// These functions handle common patterns like where clause management, SQL parameter building,
/// and query execution to reduce code duplication in generated code.
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import pog

/// Updates an existing where clause or appends a new one if it doesn't exist.
/// This prevents duplicate where clauses for the same field, ensuring valid SQL generation.
/// 
/// ## Examples
/// 
/// ```gleam
/// let clauses = [WhereId(1), WhereUsername("alice")]
/// let new_clauses = update_or_append_where_clause(
///   clauses,
///   fn(clause) { case clause { WhereUsername(_) -> True; _ -> False } },
///   WhereUsername("bob")
/// )
/// // Result: [WhereId(1), WhereUsername("bob")]
/// 
/// // Prevents invalid SQL like: WHERE id = 1 AND id = 2
/// let clauses = [WhereId(1)]
/// let new_clauses = update_or_append_where_clause(
///   clauses,
///   fn(clause) { case clause { WhereId(_) -> True; _ -> False } },
///   WhereId(2)
/// )
/// // Result: [WhereId(2)] - replaces, doesn't accumulate
/// ```
pub fn update_or_append_where_clause(
  clauses: List(where_clause),
  matcher: fn(where_clause) -> Bool,
  new_clause: where_clause,
) -> List(where_clause) {
  let exists_already = clauses |> list.any(matcher)

  case exists_already {
    True -> {
      clauses
      |> list.map(fn(clause) {
        case matcher(clause) {
          True -> new_clause
          False -> clause
        }
      })
    }
    False -> [new_clause, ..clauses]
  }
}


/// Helper type for building SQL conditions with parameters
pub type SqlBuilder {
  SqlBuilder(
    conditions: List(String),
    params: List(pog.Value),
    param_count: Int,
  )
}

/// Creates a new empty SQL builder
/// 
/// ## Examples
/// 
/// ```gleam
/// let builder = new_sql_builder()
/// // SqlBuilder(conditions: [], params: [], param_count: 1)
/// ```
pub fn new_sql_builder() -> SqlBuilder {
  SqlBuilder(conditions: [], params: [], param_count: 1)
}

/// Adds a parameterized condition to the SQL builder
/// 
/// ## Examples
/// 
/// ```gleam
/// let builder = new_sql_builder()
/// let updated = add_sql_condition(builder, "name = $1", pog.text("alice"))
/// // SqlBuilder(conditions: ["name = $1"], params: [pog.text("alice")], param_count: 2)
/// ```
pub fn add_sql_condition(
  builder: SqlBuilder,
  condition: String,
  param: pog.Value,
) -> SqlBuilder {
  SqlBuilder(
    conditions: [condition, ..builder.conditions],
    params: [param, ..builder.params],
    param_count: builder.param_count + 1,
  )
}

/// Adds a non-parameterized condition to the SQL builder (e.g., "field IS NULL")
/// 
/// ## Examples
/// 
/// ```gleam
/// let builder = new_sql_builder()
/// let updated = add_sql_condition_no_param(builder, "deleted_at IS NULL")
/// // SqlBuilder(conditions: ["deleted_at IS NULL"], params: [], param_count: 1)
/// ```
pub fn add_sql_condition_no_param(
  builder: SqlBuilder,
  condition: String,
) -> SqlBuilder {
  SqlBuilder(
    conditions: [condition, ..builder.conditions],
    params: builder.params,
    param_count: builder.param_count,
  )
}

/// Finalizes the SQL builder into a WHERE clause string and parameter list
/// 
/// ## Examples
/// 
/// ```gleam
/// let builder = new_sql_builder()
///   |> add_sql_condition("name = $1", pog.text("alice"))
///   |> add_sql_condition("age > $2", pog.int(18))
/// let #(where_sql, params) = finalize_sql_builder(builder)
/// // #(" WHERE age > $2 AND name = $1", [pog.int(18), pog.text("alice")])
/// ```
pub fn finalize_sql_builder(builder: SqlBuilder) -> #(String, List(pog.Value)) {
  case builder.conditions {
    [] -> #("", [])
    conditions -> {
      let where_clause =
        conditions
        |> list.reverse
        |> string.join(" AND ")
      #(" WHERE " <> where_clause, list.reverse(builder.params))
    }
  }
}

/// Builds a complete SQL query from its component parts
/// 
/// ## Examples
/// 
/// ```gleam
/// let sql = build_complete_sql(
///   "SELECT id, name",
///   "FROM users",
///   " WHERE active = true",
///   " ORDER BY created_at DESC",
///   " LIMIT 10"
/// )
/// // "SELECT id, name FROM users WHERE active = true ORDER BY created_at DESC LIMIT 10"
/// ```
pub fn build_complete_sql(
  select_clause: String,
  from_clause: String,
  where_clause: String,
  order_clause: String,
  limit_clause: String,
) -> String {
  select_clause <> from_clause <> where_clause <> order_clause <> limit_clause
}

/// Adds parameters to a pog query efficiently
/// 
/// ## Examples
/// 
/// ```gleam
/// let query = pog.query("SELECT * FROM users WHERE name = $1 AND age = $2")
/// let params = [pog.text("alice"), pog.int(25)]
/// let final_query = add_parameters_to_query(query, params)
/// // Query with both parameters added
/// ```
pub fn add_parameters_to_query(
  query: pog.Query(a),
  params: List(pog.Value),
) -> pog.Query(a) {
  case params {
    [] -> query
    params -> {
      params
      |> list.fold(query, fn(query_acc, param) {
        pog.parameter(query_acc, param)
      })
    }
  }
}

/// Common error types for database operations
pub type DatabaseError {
  DatabaseConnectionError
  QueryExecutionError
  GenericError(String)
}

/// Executes a pog query with proper error handling and logging
/// 
/// ## Examples
/// 
/// ```gleam
/// let query = pog.query("SELECT * FROM users") |> pog.returning(user_decoder())
/// let result = execute_query_with_connection(query, db_connection, "fetch users")
/// // Result(List(User), DatabaseError)
/// ```
pub fn execute_query_with_connection(
  query: pog.Query(a),
  connection: pog.Connection,
  operation_name: String,
) -> Result(List(a), DatabaseError) {
  case pog.execute(query, connection) {
    Ok(result) -> Ok(result.rows)
    Error(error) -> {
      io.println_error("Query execution failed for: " <> operation_name)
      io.println_error("Error: " <> string.inspect(error))
      Error(QueryExecutionError)
    }
  }
}

/// Builds an ORDER BY clause from a list of order conditions
/// 
/// ## Examples
/// 
/// ```gleam
/// let conditions = ["name ASC", "created_at DESC"]
/// let order_clause = build_order_clause(conditions)
/// // " ORDER BY name ASC, created_at DESC"
/// ```
pub fn build_order_clause(order_conditions: List(String)) -> String {
  case order_conditions {
    [] -> ""
    conditions -> {
      " ORDER BY " <> string.join(conditions, ", ")
    }
  }
}

/// Builds a LIMIT clause from an optional limit value
/// 
/// ## Examples
/// 
/// ```gleam
/// let limit_clause = build_limit_clause(Some(10))
/// // " LIMIT 10"
/// 
/// let no_limit = build_limit_clause(None)
/// // ""
/// ```
pub fn build_limit_clause(limit: Option(Int)) -> String {
  case limit {
    None -> ""
    Some(limit_value) -> " LIMIT " <> int.to_string(limit_value)
  }
}

/// Direction enum for ORDER BY clauses - commonly used across all query builders
pub type Direction {
  Asc
  Desc
}

/// Converts Direction to SQL string
/// 
/// ## Examples
/// 
/// ```gleam
/// direction_to_sql(Asc)  // "ASC"
/// direction_to_sql(Desc) // "DESC"
/// ```
pub fn direction_to_sql(direction: Direction) -> String {
  case direction {
    Asc -> "ASC"
    Desc -> "DESC"
  }
}
