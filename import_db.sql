-- Notice that tables are always named lowercase and plural. This is a
-- convention.
DROP TABLE users;
DROP TABLE questions;
DROP TABLE question_follows;
DROP TABLE replies;
DROP TABLE question_likes;

CREATE TABLE users (
  -- SQLite3 will automatically populate an integer primary key
  -- (unless it is specifically provided). The conventional primary
  -- key name is 'id'.
  id INTEGER PRIMARY KEY,
  -- NOT NULL specifies that the column must be provided. This is a
  -- useful check of the integrity of the data.
  fname VARCHAR(255) NOT NULL,
  lname VARCHAR(255) NOT NULL

  -- Not strictly necessary, but informs the DB not to
  --  (1) create a professor with an invalid department_id,
  --  (2) delete a department (or change its id) if professors
  --      reference it.
  -- Either event would leave the database in an invalid state, with a
  -- foreign key that doesn't point to a valid record. Older versions
  -- of SQLite3 may not enforce this, and will just ignore the foreign
  -- key constraint.
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body VARCHAR(1000) NOT NULL,
  user_id INTEGER,

  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  question_id INTEGER,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  parent_id INTEGER,
  question_id INTEGER,
  user_id INTEGER NOT NULL,
  body VARCHAR(1000) NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (parent_id) REFERENCES replies(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  question_id INTEGER,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

-- In addition to creating tables, we can seed our database with some
-- starting data.
INSERT INTO
  users (fname, lname)
VALUES
  ('Scott', 'Dikowitz'),
  ('Fred', 'Sladkey');

INSERT INTO
  replies (parent_id, question_id, user_id, body)
VALUES
  (null, 1, 2, "the meaning of life is 42"),
  (null, 2, 1, "11"),
  (2, 2, 2, "thank you!"),
  (null, 3, 1, "why cant i think of any answers"),
  (null, 4, 1, "delete system32");

INSERT INTO
  questions (title, body, user_id)
VALUES
  ('Very important question...', 'What is the meaning of life?', 1),
  ('what is 1 + 1', 'I am wondering what the answer to 1 + 1 is.', 1),
  ('Something Ive been wondering', 'Why cant I think of any questions?', 2),
  ('How do I google altavista?', 'On bing?', 2);


INSERT INTO
  question_follows (user_id, question_id)
VALUES
  (1,2),
  (2,1),
  (2,2);

  INSERT INTO
    question_likes (user_id, question_id)
  VALUES
    (1,2),
    (1,3),
    (1,3),
    (1,3),
    (1,4),
    (1,4),
    (1,4),
    (1,3),
    (1,3),
    (2,3),
    (2,3),
    (2,1),
    (2,2);
