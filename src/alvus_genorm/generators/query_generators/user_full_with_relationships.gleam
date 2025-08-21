import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import pog

import alvus_genorm/query_helpers.{
  type DatabaseError, type Direction, Asc, Desc, add_parameters_to_query,
  execute_query_with_connection, update_or_append_where_clause,
}

// ============ RELATIONSHIP TRACKING TYPES ============

pub type RelationshipToLoad {
  LoadPosts
  LoadComments
  LoadProfile
}

pub type RelationshipStatus(t) {
  NotFetched
  Loaded(t)
  Failed(DatabaseError)
}

// ============ RELATIONSHIP DATA TYPES ============

// These would be imported from generated model files
pub type Post {
  Post(id: Int, title: String, content: String, author_id: Int)
}

pub type Comment {
  Comment(id: Int, content: String, user_id: Int, post_id: Int)
}

pub type Profile {
  Profile(id: Int, user_id: Int, avatar_url: Option(String))
}

// ============ QUERY STATE TYPES ============

pub type UserWithRelationships {
  UserWithRelationships(
    id: Int,
    username: String,
    bio: Option(String),
    // One-to-Many relationship
    posts: RelationshipStatus(List(Post)),
    // One-to-Many relationship 
    comments: RelationshipStatus(List(Comment)),
    // One-to-One relationship
    profile: RelationshipStatus(Option(Profile)),
  )
}

pub type UserWhereClause {
  WhereId(Int)
  WhereUsername(String)
  WhereBio(Option(String))
}

pub type UserOrderClause {
  OrderById(Direction)
  OrderByUsername(Direction)
  OrderByBio(Direction)
}

pub type UserQueryState {
  UserQueryState(
    where_clauses: List(UserWhereClause),
    order_by: List(UserOrderClause),
    limit: Option(Int),
  )
}

pub type UserQuery {
  UserQuery(
    state: UserQueryState,
    relationships_to_load: List(RelationshipToLoad),
  )
}

// ============ QUERY BUILDER FUNCTIONS ============

pub fn all() -> UserQuery {
  UserQuery(
    state: UserQueryState(where_clauses: [], order_by: [], limit: option.None),
    relationships_to_load: [],
  )
}

// ============ WHERE CLAUSE BUILDERS ============

pub fn where_id(query: UserQuery, id: Int) -> UserQuery {
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

  UserQuery(
    ..query,
    state: UserQueryState(..query.state, where_clauses: new_clauses),
  )
}

pub fn where_username(query: UserQuery, username: String) -> UserQuery {
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

  UserQuery(
    ..query,
    state: UserQueryState(..query.state, where_clauses: new_clauses),
  )
}

// ============ RELATIONSHIP MARKERS ============

pub fn with_posts(query: UserQuery) -> UserQuery {
  case list.contains(query.relationships_to_load, LoadPosts) {
    True -> query
    False ->
      UserQuery(..query, relationships_to_load: [
        LoadPosts,
        ..query.relationships_to_load
      ])
  }
}

pub fn with_comments(query: UserQuery) -> UserQuery {
  case list.contains(query.relationships_to_load, LoadComments) {
    True -> query
    False ->
      UserQuery(..query, relationships_to_load: [
        LoadComments,
        ..query.relationships_to_load
      ])
  }
}

pub fn with_profile(query: UserQuery) -> UserQuery {
  case list.contains(query.relationships_to_load, LoadProfile) {
    True -> query
    False ->
      UserQuery(..query, relationships_to_load: [
        LoadProfile,
        ..query.relationships_to_load
      ])
  }
}

// ============ EXECUTION FUNCTIONS ============

// Execute base query only - no relationships loaded
pub fn execute(
  query: UserQuery,
) -> Result(List(UserWithRelationships), DatabaseError) {
  case build_user_sql(query.state) {
    Ok(#(sql, parameters)) -> {
      let pog_query =
        pog.query(sql)
        |> pog.returning(user_decoder())
        |> add_parameters_to_query(parameters)

      case start_database() {
        Ok(db) -> {
          case execute_query_with_connection(pog_query, db, "fetch users") {
            Ok(users) -> Ok(users)
            Error(db_err) -> Error(db_err)
          }
        }
        Error(db_err) -> Error(db_err)
      }
    }
    Error(err) -> Error(err)
  }
}

// Execute with relationship loading
pub fn execute_with_relationships(
  query: UserQuery,
) -> Result(List(UserWithRelationships), DatabaseError) {
  case execute(query) {
    Ok(users) -> load_relationships_batch(users, query.relationships_to_load)
    Error(err) -> Error(err)
  }
}

// ============ RELATIONSHIP BATCH LOADER ============

pub fn load_relationships_batch(
  users: List(UserWithRelationships),
  relationships_to_load: List(RelationshipToLoad),
) -> Result(List(UserWithRelationships), DatabaseError) {
  let user_ids = users |> list.map(fn(user) { user.id })

  // Load all requested relationships
  list.try_fold(relationships_to_load, users, fn(current_users, relationship) {
    case relationship {
      LoadPosts -> load_and_apply_posts(current_users, user_ids)
      LoadComments -> load_and_apply_comments(current_users, user_ids)
      LoadProfile -> load_and_apply_profile(current_users, user_ids)
    }
  })
}

// ============ INDIVIDUAL RELATIONSHIP LOADERS ============

fn load_and_apply_posts(
  users: List(UserWithRelationships),
  user_ids: List(Int),
) -> Result(List(UserWithRelationships), DatabaseError) {
  case load_posts_for_users(user_ids) {
    Ok(posts_dict) -> {
      let updated_users =
        users
        |> list.map(fn(user) {
          let user_posts = dict.get(posts_dict, user.id) |> result.unwrap([])
          UserWithRelationships(..user, posts: Loaded(user_posts))
        })
      Ok(updated_users)
    }
    Error(err) -> {
      let failed_users =
        users
        |> list.map(fn(user) {
          UserWithRelationships(..user, posts: Failed(err))
        })
      Ok(failed_users)
    }
  }
}

fn load_and_apply_comments(
  users: List(UserWithRelationships),
  user_ids: List(Int),
) -> Result(List(UserWithRelationships), DatabaseError) {
  case load_comments_for_users(user_ids) {
    Ok(comments_dict) -> {
      let updated_users =
        users
        |> list.map(fn(user) {
          let user_comments =
            dict.get(comments_dict, user.id) |> result.unwrap([])
          UserWithRelationships(..user, comments: Loaded(user_comments))
        })
      Ok(updated_users)
    }
    Error(err) -> {
      let failed_users =
        users
        |> list.map(fn(user) {
          UserWithRelationships(..user, comments: Failed(err))
        })
      Ok(failed_users)
    }
  }
}

fn load_and_apply_profile(
  users: List(UserWithRelationships),
  user_ids: List(Int),
) -> Result(List(UserWithRelationships), DatabaseError) {
  case load_profile_for_users(user_ids) {
    Ok(profile_dict) -> {
      let updated_users =
        users
        |> list.map(fn(user) {
          let user_profile =
            dict.get(profile_dict, user.id) |> result.unwrap(option.None)
          UserWithRelationships(..user, profile: Loaded(user_profile))
        })
      Ok(updated_users)
    }
    Error(err) -> {
      let failed_users =
        users
        |> list.map(fn(user) {
          UserWithRelationships(..user, profile: Failed(err))
        })
      Ok(failed_users)
    }
  }
}

// ============ RESOLVER FUNCTIONS ============

// One-to-Many: User has many Posts
fn load_posts_for_users(
  user_ids: List(Int),
) -> Result(Dict(Int, List(Post)), DatabaseError) {
  case user_ids {
    [] -> Ok(dict.new())
    _ -> {
      let placeholders =
        user_ids
        |> list.index_map(fn(_, idx) { "$" <> int.to_string(idx + 1) })
        |> string.join(", ")

      let sql =
        "SELECT id, title, content, author_id FROM posts WHERE author_id IN ("
        <> placeholders
        <> ") ORDER BY author_id, id"

      let parameters = user_ids |> list.map(pog.int)

      let pog_query =
        pog.query(sql)
        |> pog.returning(post_decoder())
        |> add_parameters_to_query(parameters)

      case start_database() {
        Ok(db) -> {
          case execute_query_with_connection(pog_query, db, "load posts") {
            Ok(posts) -> {
              let posts_by_user =
                posts
                |> list.group(fn(post) { post.author_id })
              Ok(posts_by_user)
            }
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

// One-to-Many: User has many Comments  
fn load_comments_for_users(
  user_ids: List(Int),
) -> Result(Dict(Int, List(Comment)), DatabaseError) {
  case user_ids {
    [] -> Ok(dict.new())
    _ -> {
      let placeholders =
        user_ids
        |> list.index_map(fn(_, idx) { "$" <> int.to_string(idx + 1) })
        |> string.join(", ")

      let sql =
        "SELECT id, content, user_id, post_id FROM comments WHERE user_id IN ("
        <> placeholders
        <> ") ORDER BY user_id, id"

      let parameters = user_ids |> list.map(pog.int)

      let pog_query =
        pog.query(sql)
        |> pog.returning(comment_decoder())
        |> add_parameters_to_query(parameters)

      case start_database() {
        Ok(db) -> {
          case execute_query_with_connection(pog_query, db, "load comments") {
            Ok(comments) -> {
              let comments_by_user =
                comments
                |> list.group(fn(comment) { comment.user_id })
              Ok(comments_by_user)
            }
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

// One-to-One: User has one Profile
fn load_profile_for_users(
  user_ids: List(Int),
) -> Result(Dict(Int, Option(Profile)), DatabaseError) {
  case user_ids {
    [] -> Ok(dict.new())
    _ -> {
      let placeholders =
        user_ids
        |> list.index_map(fn(_, idx) { "$" <> int.to_string(idx + 1) })
        |> string.join(", ")

      let sql =
        "SELECT id, user_id, avatar_url FROM profiles WHERE user_id IN ("
        <> placeholders
        <> ")"

      let parameters = user_ids |> list.map(pog.int)

      let pog_query =
        pog.query(sql)
        |> pog.returning(profile_decoder())
        |> add_parameters_to_query(parameters)

      case start_database() {
        Ok(db) -> {
          case execute_query_with_connection(pog_query, db, "load profiles") {
            Ok(profiles) -> {
              let profiles_by_user =
                profiles
                |> list.fold(dict.new(), fn(acc, profile) {
                  dict.insert(acc, profile.user_id, option.Some(profile))
                })

              // Ensure all user_ids are in the dict, even if no profile exists
              let complete_dict =
                user_ids
                |> list.fold(profiles_by_user, fn(acc, user_id) {
                  case dict.has_key(acc, user_id) {
                    True -> acc
                    False -> dict.insert(acc, user_id, option.None)
                  }
                })

              Ok(complete_dict)
            }
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

// ============ SQL GENERATION ============

fn build_user_sql(
  state: UserQueryState,
) -> Result(#(String, List(pog.Value)), DatabaseError) {
  let select_clause = "SELECT id, username, bio"
  let from_clause = " FROM users"

  let #(where_clause, parameters) = case state.where_clauses {
    [] -> #("", [])
    clauses -> build_where_clause_sql_with_params(clauses)
  }

  let order_clause = case state.order_by {
    [] -> ""
    clauses -> {
      let order_conditions =
        clauses
        |> list.map(build_order_clause_sql)
      query_helpers.build_order_clause(order_conditions)
    }
  }

  let limit_clause = query_helpers.build_limit_clause(state.limit)

  let sql =
    query_helpers.build_complete_sql(
      select_clause,
      from_clause,
      where_clause,
      order_clause,
      limit_clause,
    )

  Ok(#(sql, parameters))
}

fn build_where_clause_sql_with_params(
  clauses: List(UserWhereClause),
) -> #(String, List(pog.Value)) {
  let builder =
    clauses
    |> list.fold(query_helpers.new_sql_builder(), fn(builder, clause) {
      case clause {
        WhereId(value) -> {
          let condition = "id = $" <> int.to_string(builder.param_count)
          query_helpers.add_sql_condition(builder, condition, pog.int(value))
        }
        WhereUsername(value) -> {
          let condition = "username = $" <> int.to_string(builder.param_count)
          query_helpers.add_sql_condition(builder, condition, pog.text(value))
        }
        WhereBio(option.Some(value)) -> {
          let condition = "bio = $" <> int.to_string(builder.param_count)
          query_helpers.add_sql_condition(builder, condition, pog.text(value))
        }
        WhereBio(option.None) -> {
          query_helpers.add_sql_condition_no_param(builder, "bio IS NULL")
        }
      }
    })

  query_helpers.finalize_sql_builder(builder)
}

fn build_order_clause_sql(clause: UserOrderClause) -> String {
  case clause {
    OrderById(direction) -> "id " <> query_helpers.direction_to_sql(direction)
    OrderByUsername(direction) ->
      "username " <> query_helpers.direction_to_sql(direction)
    OrderByBio(direction) -> "bio " <> query_helpers.direction_to_sql(direction)
  }
}

// ============ DECODERS ============

import gleam/dynamic/decode

fn user_decoder() {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  use bio <- decode.field(2, decode.optional(decode.string))
  decode.success(UserWithRelationships(
    id: id,
    username: username,
    bio: bio,
    posts: NotFetched,
    comments: NotFetched,
    profile: NotFetched,
  ))
}

fn post_decoder() {
  use id <- decode.field(0, decode.int)
  use title <- decode.field(1, decode.string)
  use content <- decode.field(2, decode.string)
  use author_id <- decode.field(3, decode.int)
  decode.success(Post(
    id: id,
    title: title,
    content: content,
    author_id: author_id,
  ))
}

fn comment_decoder() {
  use id <- decode.field(0, decode.int)
  use content <- decode.field(1, decode.string)
  use user_id <- decode.field(2, decode.int)
  use post_id <- decode.field(3, decode.int)
  decode.success(Comment(
    id: id,
    content: content,
    user_id: user_id,
    post_id: post_id,
  ))
}

fn profile_decoder() {
  use id <- decode.field(0, decode.int)
  use user_id <- decode.field(1, decode.int)
  use avatar_url <- decode.field(2, decode.optional(decode.string))
  decode.success(Profile(id: id, user_id: user_id, avatar_url: avatar_url))
}

// ============ DATABASE CONNECTION ============

import gleam/erlang/process
import gleam/io

fn start_database() -> Result(pog.Connection, DatabaseError) {
  let pool_name = process.new_name("db_pool")

  let config =
    pog.default_config(pool_name)
    |> pog.host("localhost")
    |> pog.port(5432)
    |> pog.database("genau_db")
    |> pog.user("postgres")
    |> pog.password(option.None)

  case pog.start(config) {
    Ok(started) -> Ok(started.data)
    Error(_) -> {
      io.println_error("Failed to connect to database")
      Error(query_helpers.DatabaseConnectionError)
    }
  }
}

// ============ EXAMPLES ============

pub fn example_usage() {
  // Execute without relationships - fast base query
  let base_users =
    all()
    |> where_id(1)
    |> execute()

  echo base_users

  // Execute with relationships - batch loaded
  let users_with_data =
    all()
    |> where_id(1)
    |> with_posts()
    |> with_profile()
    |> execute_with_relationships()

  case users_with_data {
    Error(_) -> todo
    Ok(users) -> {
      users
      |> list.each(fn(user) {
        echo "id:"
        echo user.id
        echo "Profile:"
        echo user.profile
        echo "Posts:"
        echo user.posts
      })
    }
  }

  #(base_users, users_with_data)
}
