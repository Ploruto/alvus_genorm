# Notes

### Relationships
We should provide relationships on models, such that when generating
the type safe code for models we have something like:

for example:
User: UUID id, String name, Optional String bio, FK posts, FK friends


// pseudo-code
```gleam
pub type User{id: UUID, name: String, bio: Option(String)}
// partial makes every field Optional and null represented as Some(None)
pub type PartialUser{id: Option(UUID), name: Option(String), bio: Option(Option(String))}
pub type UserWithRelationships{id: UUID, name: String, bio: Option(String),
// Optional allows us to not load the relationship the original query didn't want that.
posts: Option(List(Post)), fiends: Option(List(User))
}

pub type UserWithRelationshipsPartial{
  id: UUID, name: String, bio: Option(String),
// Partial is what gets returned if the user only wanted some fields of the relationship
posts: Option(List(PartialPost)), fiends: Option(List(PartialUser))
}
```

So it might look like this:
```gleam
user.all() |> where_name('superman') // -> List(User)
// this would return List(UserWithRelationshipsPartial)
// where the posts field is Some(List(PartialPosts)) and only the id and title columns
// are populated
user.all() |> where_name('superman') |> with_partial_posts([PostID, PostTitle])
// this is a full relationship call -> UserWithRelationships
user.all() |> where_name('superman') |> with_posts() |> with_partial_friends([UserId, UserName])
```
