import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}

// import gleam/option.{type Option, None, Some}
import pog

pub type Error

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

pub type Direction {
  Asc
  Desc
}

pub type UserWhereClause {
  WhereId(Int)
  WhereUsername(String)
  WhereBio(Option(String))
  // WhereIdIn(List(Int))
  // WhereUsernameIn(List(String))
  // WhereBioIn(List(Option(String)))
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

// use the field_to_gleam_type to get the 2nd argument
fn where_username(query: PartialUserQuery, username: String) -> PartialUserQuery {
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

  PartialUserQuery(
    state: PartialUserQueryState(..query.state, where_clauses: new_clauses),
  )
}

fn user_field_to_column_name(field: UserField) -> String {
  case field {
    UserId -> "id"
    UserUsername -> "username"
    UserBio -> "bio"
  }
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
  let selected_fields_as_string =
    query.state.selected_fields |> list.map(user_field_to_column_name)

  let sql_select_fields =
    ["id", "username", "bio"]
    |> list.map(fn(column) {
      case list.contains(selected_fields_as_string, column) {
        True -> column
        False -> "NULL"
      }
    })
  echo sql_select_fields
  echo query.state.where_clauses

  let q =
    pog.query("select id, NULL, NULL from users")
    |> pog.returning(partial_user_decoder(query.state.selected_fields))

  case start_database() {
    Ok(db) -> {
      echo q
      case pog.execute(q, db) {
        Ok(res) -> {
          Ok(res.rows)
        }
        Error(_) -> {
          todo
        }
      }
    }
    _ -> {
      todo
    }
  }
}

pub fn example_dev() {
  let res =
    select([UserId, UserBio])
    |> where_username("Hello")
    |> where_username("Overriden")
    |> execute()

  case res {
    Ok(users) -> {
      users
      |> list.each(fn(user) {
        case user.bio {
          NotFetched -> {
            echo "value was not fetched"
          }
          Null -> {
            echo "value was null"
          }
          Value(bio) -> {
            echo bio
            todo as "bio return"
          }
        }
      })
    }
    _ -> {
      todo
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
