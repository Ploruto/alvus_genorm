-- Clear existing data
TRUNCATE TABLE comments, posts, profiles, users RESTART IDENTITY CASCADE;

-- Seed Users
INSERT INTO users (id, username, bio) VALUES
(1, 'alice', 'Software developer and cat lover.'),
(2, 'bob', 'Enjoys hiking and photography.'),
(3, 'charlie', 'Loves to comment on things.'),
(4, 'diana', 'Musician and artist.');

-- Seed Profiles (One-to-One)
-- Alice and Bob have profiles with avatars.
-- Diana has a profile record, but the optional avatar_url is NULL.
-- Charlie has no profile record at all.
INSERT INTO profiles (user_id, avatar_url) VALUES
(1, 'https://example.com/avatars/alice.png'),
(2, 'https://example.com/avatars/bob.png'),
(4, NULL);

-- Seed Posts (One-to-Many)
-- Alice has two posts.
-- Bob has one post.
-- Charlie and Diana have no posts.
INSERT INTO posts (id, title, content, author_id) VALUES
(1, 'My First Gleam Project', 'I am writing my first project in Gleam, it is a fantastic experience!', 1),
(2, 'Thoughts on Functional Programming', 'Functional programming paradigms help in writing clean and maintainable code.', 1),
(3, 'A Trip to the Mountains', 'The views were breathtaking. Here are some photos.', 2);

-- Seed Comments (Many-to-One)
-- Comments from various users on different posts.
-- Bob comments on Alice''s post.
-- Charlie (who has no posts himself) comments on posts by Alice and Bob.
-- Alice comments on her own post.
INSERT INTO comments (content, user_id, post_id) VALUES
('Great post, Alice! Looking forward to more.', 2, 1),
('This is a very interesting read. Thanks for sharing.', 3, 1),
('I agree, FP is fantastic. It really changes how you think about problems.', 1, 2),
('Beautiful photos! Makes me want to go there.', 3, 3);
