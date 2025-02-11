---
layout: post
title: Search In Postgres
---

# {{ page.title }}

<p class="meta">02 May, 2025</p>

It's inevitable at some point you'll need to implement user facing search on one of more fields in your database. I had to implement searching file and user given title for the file, but not the contents of the file.

Here's an example table `files`.

```sql
CREATE TABLE public.files (
	id SERIAL PRIMARY KEY,
	path text NOT NULL,
	title text NOT NULL
);


INSERT INTO files (title, path)
VALUES
    ('document', '/documents/document.pdf'),
    ('image', '/images/image.jpg'),
    ('script', '/code/script.rb');
```

If you're thinking that's easy, Postgres has [full text search](https://www.postgresql.org/docs/current/textsearch.html), yes that's true, but that wouldn't work in this scenarios where user might search partial names and also wouldn't work with stop words like 'a'.

```sql
postgres=# SELECT title
FROM files
WHERE to_tsvector('english', title) @@ to_tsquery('english', 'document');
  title
----------
 document
(1 row)

postgres=# SELECT title
FROM files
WHERE to_tsvector('english', title) @@ to_tsquery('english', 'doc');
 title
-------
(0 rows)

postgres=# SELECT title
FROM files
WHERE to_tsvector('english', title) @@ to_tsquery('english', 'a');
NOTICE:  text-search query contains only stop words or doesn't contain lexemes, ignored
 title
-------
(0 rows)
```

Well, that's not really full text search, but

```sql
postgres=# SELECT * FROM files WHERE title LIKE 'doc%';
 id |          path           |  title
----+-------------------------+----------
  1 | /documents/document.pdf | document
(1 row)

postgres=# SELECT * FROM files WHERE title LIKE '%c%';
 id |          path           |  title
----+-------------------------+----------
  1 | /documents/document.pdf | document
  3 | /code/script.rb         | script
(2 rows)
```

This works great, but using wildcard in the beginning of the search query (`%c%` ) means you can't use BTree indexes.

> The optimizer can also use a B-tree index for queries involving the pattern matching operators `LIKE` and `~` _if_ the pattern is a constant and is anchored to the beginning of the string — for example, `col LIKE 'foo%'` or `col ~ '^foo'`, but not `col LIKE '%bar'`

Source: https://www.postgresql.org/docs/current/indexes-types.html#INDEXES-TYPES-BTREE

The other option is to use trigrams through `pg_tgrm` module, which works great however will only use index for searches 3 characters or more.
