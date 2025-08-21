import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import alvus_genorm/query_helpers.{
  type DatabaseError, type Direction, Asc, DatabaseConnectionError, Desc,
  add_parameters_to_query, add_sql_condition, add_sql_condition_no_param,
  build_complete_sql, build_limit_clause, build_order_clause, direction_to_sql,
  execute_query_with_connection, finalize_sql_builder, new_sql_builder,
  update_or_append_where_clause,
}
import pog

// Type aliases for cleaner imports
pub type Error =
  DatabaseError

pub type UserField {
  UserId
  UserUsername
  UserBio
}

/// Partial user query (returns PartialUser, no relationships)
pub type PartialUserQuery {
  PartialUserQuery(state: PartialUserQueryState)
}

/// Order by clauses for User model  
pub type UserOrderClause {
  OrderById(Direction)
  OrderByUsername(Direction)
  OrderByBio(Direction)
}

pub type UserWhereClause {
  WhereId(Int)
  WhereUsername(String)
  WhereBio(Option(String))
}

pub type PartialUser {
  PartialUser(
    id: Selection(Int),
    username: Selection(String),
    bio: Selection(Option(String)),
  )
}

/// Query state tracking what has been selected and filtered
pub type PartialUserQueryState {
  PartialUserQueryState(
    selected_fields: List(UserField),
    where_clauses: List(UserWhereClause),
    order_by: List(UserOrderClause),
    limit: Option(Int),
  )
}

/// Start a partial user query selecting specific fields
pub fn select(fields: List(UserField)) -> PartialUserQuery {
  PartialUserQuery(state: PartialUserQueryState(
    selected_fields: fields,
    where_clauses: [],
    order_by: [],
    limit: None,
  ))
}

/// Add a WHERE username = ? clause to the query (replaces existing username clause)
pub fn where_username(
  query: PartialUserQuery,
  username: String,
) -> PartialUserQuery {
  let new_clauses =
    update_or_append_where_clause(
      query.state.where_clauses,
      fn(clause) {
        case clause {
          WhereUsername(_) -> True
          _ -> False
        }
      },
      WhereUsername(username),
    )

  PartialUserQuery(
    state: PartialUserQueryState(..query.state, where_clauses: new_clauses),
  )
}

/// Add a WHERE id = $.. clause to the query (replaces existing id clause)
pub fn where_id(query: PartialUserQuery, id: Int) -> PartialUserQuery {
  let new_clauses =
    update_or_append_where_clause(
      query.state.where_clauses,
      fn(clause) {
        case clause {
          WhereId(_) -> True
          _ -> False
        }
      },
      WhereId(id),
    )
  PartialUserQuery(
    state: PartialUserQueryState(..query.state, where_clauses: new_clauses),
  )
}

/// Add a WHERE bio = ? or bio IS NULL clause to the query (replaces existing bio clause)
pub fn where_bio(
  query: PartialUserQuery,
  bio: Option(String),
) -> PartialUserQuery {
  let new_clauses =
    update_or_append_where_clause(
      query.state.where_clauses,
      fn(clause) {
        case clause {
          WhereBio(_) -> True
          _ -> False
        }
      },
      WhereBio(bio),
    )
  PartialUserQuery(
    state: PartialUserQueryState(..query.state, where_clauses: new_clauses),
  )
}

/// Add an ORDER BY clause to the query
pub fn order_by(
  query: PartialUserQuery,
  field: UserField,
  direction: Direction,
) -> PartialUserQuery {
  let order_clause = case field {
    UserId -> OrderById(direction)
    UserUsername -> OrderByUsername(direction)
    UserBio -> OrderByBio(direction)
  }
  let new_order = [order_clause, ..query.state.order_by]
  PartialUserQuery(
    state: PartialUserQueryState(..query.state, order_by: new_order),
  )
}

/// Add a LIMIT clause to the query
pub fn limit(query: PartialUserQuery, limit_value: Int) -> PartialUserQuery {
  PartialUserQuery(
    state: PartialUserQueryState(..query.state, limit: Some(limit_value)),
  )
}

fn user_field_to_column_name(field: UserField) -> String {
  case field {
    UserId -> "id"
    UserUsername -> "username"
    UserBio -> "bio"
  }
}

fn build_select_clause(selected_fields: List(UserField)) -> String {
  let all_fields = [UserId, UserUsername, UserBio]
  let field_expressions =
    all_fields
    |> list.map(fn(field) {
      case list.contains(selected_fields, field) {
        True -> user_field_to_column_name(field)
        False -> "NULL"
      }
    })
  "SELECT " <> string.join(field_expressions, ", ")
}

fn build_where_clause_sql_with_params(
  clauses: List(UserWhereClause),
) -> #(String, List(pog.Value)) {
  let builder =
    clauses
    |> list.fold(new_sql_builder(), fn(builder, clause) {
      case clause {
        WhereId(value) -> {
          let condition = "id = $" <> int.to_string(builder.param_count)
          add_sql_condition(builder, condition, pog.int(value))
        }
        WhereUsername(value) -> {
          let condition = "username = $" <> int.to_string(builder.param_count)
          add_sql_condition(builder, condition, pog.text(value))
        }
        WhereBio(Some(value)) -> {
          let condition = "bio = $" <> int.to_string(builder.param_count)
          add_sql_condition(builder, condition, pog.text(value))
        }
        WhereBio(None) -> {
          add_sql_condition_no_param(builder, "bio IS NULL")
        }
      }
    })

  finalize_sql_builder(builder)
}

fn build_order_clause_sql(clause: UserOrderClause) -> String {
  case clause {
    OrderById(direction) -> "id " <> direction_to_sql(direction)
    OrderByUsername(direction) -> "username " <> direction_to_sql(direction)
    OrderByBio(direction) -> "bio " <> direction_to_sql(direction)
  }
}

fn build_complete_sql_query(
  query_state: PartialUserQueryState,
) -> #(String, List(pog.Value)) {
  let select_clause = build_select_clause(query_state.selected_fields)
  let from_clause = " FROM users"

  let #(where_clause, parameters) = case query_state.where_clauses {
    [] -> #("", [])
    clauses -> build_where_clause_sql_with_params(clauses)
  }

  let order_clause = case query_state.order_by {
    [] -> ""
    clauses -> {
      let order_conditions =
        clauses
        |> list.map(build_order_clause_sql)
      build_order_clause(order_conditions)
    }
  }

  let limit_clause = build_limit_clause(query_state.limit)

  let sql =
    build_complete_sql(
      select_clause,
      from_clause,
      where_clause,
      order_clause,
      limit_clause,
    )
  #(sql, parameters)
}

pub type Selection(a) {
  Value(a)
  Null
  NotFetched
}

fn decode_selected_field(
  field: UserField,
  selected_fields: List(UserField),
  field_index: Int,
  type_decoder: decode.Decoder(a),
  callback: fn(Selection(a)) -> decode.Decoder(b),
) -> decode.Decoder(b) {
  case list.contains(selected_fields, field) {
    False -> callback(NotFetched)
    True -> {
      use value <- decode.field(field_index, decode.optional(type_decoder))
      case value {
        None -> callback(Null)
        Some(v) -> callback(Value(v))
      }
    }
  }
}

fn partial_user_decoder(selected_fields: List(UserField)) {
  {
    use id <- decode_selected_field(UserId, selected_fields, 0, decode.int)
    use username <- decode_selected_field(
      UserUsername,
      selected_fields,
      1,
      decode.string,
    )
    use bio <- decode_selected_field(
      UserBio,
      selected_fields,
      2,
      decode.optional(decode.string),
    )

    decode.success(PartialUser(id: id, username: username, bio: bio))
  }
}

pub fn execute(query: PartialUserQuery) -> Result(List(PartialUser), Error) {
  let #(sql_query, parameters) = build_complete_sql_query(query.state)

  let pog_query =
    pog.query(sql_query)
    |> pog.returning(partial_user_decoder(query.state.selected_fields))
    |> add_parameters_to_query(parameters)

  case start_database() {
    Ok(db) ->
      execute_query_with_connection(pog_query, db, "fetch partial users")
    Error(err) -> Error(err)
  }
}

pub fn example_dev() {
  let query =
    select([UserId, UserBio])
    |> where_id(1)
    |> where_id(2)
    // This should replace the first where_id(1)
    |> where_username("Hello")
    |> where_username("user1")
    // This should replace the first where_username
    |> order_by(UserId, Desc)
    |> limit(10)

  let #(sql_query, parameters) = build_complete_sql_query(query.state)

  io.println("=== Generated SQL Query ===")
  io.println(sql_query)
  io.println("\n=== Parameters ===")
  parameters
  |> list.each(fn(param) { io.println("Parameter: " <> string.inspect(param)) })

  io.println("\n=== Query State ===")
  io.println("Selected fields: " <> string.inspect(query.state.selected_fields))
  io.println("Where clauses: " <> string.inspect(query.state.where_clauses))
  io.println("Order by: " <> string.inspect(query.state.order_by))
  io.println("Limit: " <> string.inspect(query.state.limit))

  // Now let's actually try to execute the query
  io.println("\n=== Attempting to execute query ===")

  let pog_query =
    pog.query(sql_query)
    |> pog.returning(partial_user_decoder(query.state.selected_fields))

  let final_query = case parameters {
    [] -> pog_query
    params -> {
      params
      |> list.fold(pog_query, fn(query_acc, param) {
        pog.parameter(query_acc, param)
      })
    }
  }

  io.println("Final pog query object:")
  echo final_query

  let res = execute(query)
  case res {
    Ok(users) -> {
      io.println("\n=== Query Results ===")
      io.println("Found " <> int.to_string(list.length(users)) <> " users")
      users
      |> list.each(fn(user) {
        io.println("User ID: " <> string.inspect(user.id))
        io.println("User Username: " <> string.inspect(user.username))
        case user.bio {
          NotFetched -> io.println("Bio: Not fetched")
          Null -> io.println("Bio: NULL")
          Value(Some(bio_text)) -> io.println("Bio: " <> bio_text)
          Value(None) -> io.println("Bio: Empty")
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

pub fn start_database() -> Result(pog.Connection, Error) {
  let pool_name = process.new_name("db_pool")

  let config =
    pog.default_config(pool_name)
    |> pog.host("localhost")
    |> pog.port(5432)
    |> pog.database("genau_db")
    |> pog.user("postgres")
    |> pog.password(None)

  case pog.start(config) {
    Ok(started) -> Ok(started.data)
    Error(_) -> {
      io.println_error("Failed to connect to database")
      Error(DatabaseConnectionError)
    }
  }
}
