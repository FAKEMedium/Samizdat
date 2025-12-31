# Database migrations files

This folder contains all database migration files used to manage changes to the
database schema over time. Each migration file is responsible for applying a specific
change to the database structure, such as adding or modifying tables, columns, indexes,
or constraints.

Development is mainly targetedat Postgresql (Mojo::Pg), but we also aim to support
other databases like SQLite (Mojo::SQLite) and MySQL (Mojo::mysql) too.
