import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import pog

pub type Error {
  DatabaseConnectionError
  QueryExecutionError
  GenericError(String)
}

pub type UserField {
  UserId
  UserUsername
  UserBio
}

/// Full user query (always returns all fields, optional relationships)
pub type UserQuery {
  UserQuery(state: UserQueryState)
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

pub type UserWhereClause {
  WhereId(Int)
  WhereUsername(String)
  WhereBio(Option(String))
}

/// Full user with all fields (no relationships for now)
pub type User {
  User(id: Int, username: String, bio: Option(String))
}

/// Query state for full queries (no field selection, optional relationships later)
pub type UserQueryState {
  UserQueryState(
    where_clauses: List(UserWhereClause),
    // relationships: List(String), // TODO: Add when implementing relationships
    order_by: List(UserOrderClause),
    limit: Option(Int),
  )
}

/// Start a full user query selecting all fields
pub fn all() -> UserQuery {
  UserQuery(state: UserQueryState(where_clauses: [], order_by: [], limit: None))
}

/// Add a WHERE username = ? clause to the query  
pub fn where_username(query: UserQuery, username: String) -> UserQuery {
  let clauses = query.state.where_clauses
  // check if where clause exists already in the query
  let exists_already =
    clauses
    |> list.any(fn(clause) {
      case clause {
        WhereUsername(_) -> True
        _ -> False
      }
    })

  // now either replace or insert the clause:
  let new_clauses = case exists_already {
    True -> {
      list.map(clauses, fn(c) {
        case c {
          WhereUsername(_) -> WhereUsername(username)
          _ -> {
            c
          }
        }
      })
    }
    _ -> {
      [WhereUsername(username), ..clauses]
    }
  }

  UserQuery(state: UserQueryState(..query.state, where_clauses: new_clauses))
}

/// Add a WHERE id = ? clause to the query
pub fn where_id(query: UserQuery, id: Int) -> UserQuery {
  let new_clauses = [WhereId(id), ..query.state.where_clauses]
  UserQuery(state: UserQueryState(..query.state, where_clauses: new_clauses))
}

/// Add a WHERE bio = ? or bio IS NULL clause to the query
pub fn where_bio(query: UserQuery, bio: Option(String)) -> UserQuery {
  let new_clauses = [WhereBio(bio), ..query.state.where_clauses]
  UserQuery(state: UserQueryState(..query.state, where_clauses: new_clauses))
}

/// Add an ORDER BY clause to the query
pub fn order_by(
  query: UserQuery,
  field: UserField,
  direction: Direction,
) -> UserQuery {
  let order_clause = case field {
    UserId -> OrderById(direction)
    UserUsername -> OrderByUsername(direction)
    UserBio -> OrderByBio(direction)
  }
  let new_order = [order_clause, ..query.state.order_by]
  UserQuery(state: UserQueryState(..query.state, order_by: new_order))
}

/// Add a LIMIT clause to the query
pub fn limit(query: UserQuery, limit_value: Int) -> UserQuery {
  UserQuery(state: UserQueryState(..query.state, limit: Some(limit_value)))
}

fn user_field_to_column_name(field: UserField) -> String {
  case field {
    UserId -> "id"
    UserUsername -> "username"
    UserBio -> "bio"
  }
}

fn direction_to_sql(direction: Direction) -> String {
  case direction {
    Asc -> "ASC"
    Desc -> "DESC"
  }
}

// For full queries, always select all fields explicitly
fn build_select_clause() -> String {
  let all_fields = [UserId, UserUsername, UserBio]
  let field_expressions =
    all_fields
    |> list.map(user_field_to_column_name)
  "SELECT " <> string.join(field_expressions, ", ")
}

fn build_where_clause_sql_with_params(
  clauses: List(UserWhereClause),
) -> #(String, List(pog.Value)) {
  let conditions_and_params =
    clauses
    |> list.fold(#([], [], 1), fn(acc, clause) {
      let #(conditions, params, param_count) = acc
      case clause {
        WhereId(value) -> {
          let condition = "id = $" <> int.to_string(param_count)
          #(
            [condition, ..conditions],
            [pog.int(value), ..params],
            param_count + 1,
          )
        }
        WhereUsername(value) -> {
          let condition = "username = $" <> int.to_string(param_count)
          #(
            [condition, ..conditions],
            [pog.text(value), ..params],
            param_count + 1,
          )
        }
        WhereBio(Some(value)) -> {
          let condition = "bio = $" <> int.to_string(param_count)
          #(
            [condition, ..conditions],
            [pog.text(value), ..params],
            param_count + 1,
          )
        }
        WhereBio(None) -> {
          let condition = "bio IS NULL"
          #([condition, ..conditions], params, param_count)
        }
      }
    })

  let #(conditions, params, _) = conditions_and_params
  let where_clause =
    conditions
    |> list.reverse
    |> string.join(" AND ")

  #(where_clause, list.reverse(params))
}

fn build_order_clause_sql(clause: UserOrderClause) -> String {
  case clause {
    OrderById(direction) -> "id " <> direction_to_sql(direction)
    OrderByUsername(direction) -> "username " <> direction_to_sql(direction)
    OrderByBio(direction) -> "bio " <> direction_to_sql(direction)
  }
}

fn build_complete_sql_query(
  query_state: UserQueryState,
) -> #(String, List(pog.Value)) {
  let select_clause = build_select_clause()
  let from_clause = " FROM users"

  let #(where_clause, parameters) = case query_state.where_clauses {
    [] -> #("", [])
    clauses -> {
      let #(conditions, params) = build_where_clause_sql_with_params(clauses)
      #(" WHERE " <> conditions, params)
    }
  }

  let order_clause = case query_state.order_by {
    [] -> ""
    clauses -> {
      let order_conditions =
        clauses
        |> list.map(build_order_clause_sql)
        |> string.join(", ")
      " ORDER BY " <> order_conditions
    }
  }

  let limit_clause = case query_state.limit {
    None -> ""
    Some(limit_value) -> " LIMIT " <> int.to_string(limit_value)
  }

  let sql =
    select_clause <> from_clause <> where_clause <> order_clause <> limit_clause
  #(sql, parameters)
}

// Simple decoder for full user (all fields always present)
fn user_decoder() {
  {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    use bio <- decode.field(2, decode.optional(decode.string))

    decode.success(User(id: id, username: username, bio: bio))
  }
}

pub fn execute(query: UserQuery) -> Result(List(User), Error) {
  let #(sql_query, parameters) = build_complete_sql_query(query.state)

  let pog_query =
    pog.query(sql_query)
    |> pog.returning(user_decoder())

  let final_query = case parameters {
    [] -> pog_query
    params -> {
      params
      |> list.fold(pog_query, fn(query_acc, param) {
        pog.parameter(query_acc, param)
      })
    }
  }

  case start_database() {
    Ok(db) -> {
      case pog.execute(final_query, db) {
        Ok(result) -> Ok(result.rows)
        Error(error) -> {
          io.println_error("Query execution failed")
          echo error
          Error(QueryExecutionError)
        }
      }
    }
    Error(_) -> {
      Error(DatabaseConnectionError)
    }
  }
}

pub fn example_dev() {
  let query =
    all()
    // |> where_username("user1")
    // |> where_bio(Some("A programmer."))
    |> order_by(UserBio, Desc)
    |> limit(5)

  let #(sql_query, parameters) = build_complete_sql_query(query.state)

  io.println("=== Generated Full SQL Query ===")
  io.println(sql_query)
  io.println("\n=== Parameters ===")
  parameters
  |> list.each(fn(param) { io.println("Parameter: " <> string.inspect(param)) })

  io.println("\n=== Query State ===")
  io.println("Where clauses: " <> string.inspect(query.state.where_clauses))
  io.println("Order by: " <> string.inspect(query.state.order_by))
  io.println("Limit: " <> string.inspect(query.state.limit))

  // Execute the query
  io.println("\n=== Attempting to execute full query ===")
  let res = execute(query)
  case res {
    Ok(users) -> {
      io.println("\n=== Query Results ===")
      io.println("Found " <> int.to_string(list.length(users)) <> " users")
      users
      |> list.each(fn(user) {
        io.println("User ID: " <> int.to_string(user.id))
        io.println("User Username: " <> user.username)
        case user.bio {
          None -> io.println("Bio: NULL")
          Some(bio_text) -> io.println("Bio: " <> bio_text)
        }
        io.println("---")
      })
    }
    Error(err) -> {
      io.println("\n=== Query Error ===")
      echo err
      Nil
    }
  }
}

pub fn start_database() {
  let pool_name = process.new_name("db_pool")

  let config =
    pog.default_config(pool_name)
    |> pog.host("localhost")
    |> pog.port(5432)
    |> pog.database("genau_db")
    |> pog.user("postgres")
    |> pog.password(None)

  case pog.start(config) {
    Ok(started) -> {
      Ok(started.data)
    }
    Error(error) -> {
      io.println_error("Failed to connect to database")
      Error(error)
    }
  }
}
