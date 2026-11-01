# SQLite Android compilation source

Official unmodified SQLite 3.50.4 amalgamation, matching the existing Windows 3.50.4 runtime version.

- Download: https://www.sqlite.org/2025/sqlite-amalgamation-3500400.zip
- Files: sqlite3.c, sqlite3.h, sqlite3ext.h, extracted verbatim.
- License: SQLite public domain (see file headers and https://www.sqlite.org/copyright.html).
- Android compiles this real source through sqlite3 3.7.1 native hooks with its default defines, including FTS5. Windows retains the existing DLL binding; other platforms retain package-managed binaries.
- Download checksum and exact source hashes are recorded in the S5 QA evidence/manifest. No handwritten SQLite substitute or platform-private Android library is used.
