## Conventions:

```gleam
Model(table_name, fields, relationships)
```
generates types for the different operations on that type.
Naming conventions: we expect the table_name to be snake_case and plural.
E.g. `users`, `posts`, `order_records`
while we expect the field's `column_name` to be singular by default.
(But relationships or arrays often have plural names)
E.g. `id`, `author_id`, `created_at`

all relationships contain the `as_name` field, which is used to
reference the relationship.

We'd want to generate the following types:
'basic type definitions':
```gleam
type User {
  User(
    id: Int
    name: String
    created_at: DateTime
  )
}

type Post {
  Post(
    id: UUID
    title: String
    author_id: Int
  )
}
```

then we have a seperated type of the model with their relationships:
```gleam
type UserWithRelationships {
  UserWithRelationships (
    id: Int
    // ... all the normal fields
    posts: Selection(List(Post))
    // .. other relationships
  )
}
```
The `Selection` type here, refers to the type that all models that that simply is:
```gleam
type Selection(a) {
  Fetched(a)
  NotFetched
}
```
This allows us to later only populate the model with relationships type
with only the relationships that were requested.


Thus far we have a default model type (all fields expect relationships are requested)
and the full model - maximum amount of data; all fields + selected (potentially all) relationships -
so to allow small and partial selections we introduce:
```gleam
type PartialUser{
  User(
    id: Selection(Int)
    name: Selection(String)
    created_at: Selection(DateTime)
  )
}
```
in other words. Each field is simply optionally fetched. The API might look like this:
```gleam
  user.select([UserId, UserName, UserCreated])
  |> partial.where_id(12)
  |> partial.execute()
```

For this to be fully type-safe we also introduce the model field type:
```gleam
type UserField {
  UserId
  UserName
  UserCreatedAt
}
```
This only contains 'fields' of the model and therefore doesn't include relationships.
(`PostAuthorId` would exist as part of the model field type but `PostAuthor` would not)
