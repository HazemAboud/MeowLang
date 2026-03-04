# Meow Lang

A Flutter project that translates cat meows into human sentences.

> ⚠️ **Server connectivity**
>
> The mobile app relies on a local HTTP server for audio processing. On Android
> emulators the host machine is accessible via `10.0.2.2`; on a real device set
> `androidServerIp` in `lib/server_config.dart` to your computer's LAN address
> (leave it blank to auto‑select the emulator address).

### Database schema notes

The server uses a MySQL database to store synced user data. Early versions
expected numeric primary keys for translations/history; the Flutter client now
uses text IDs like `1623456789123_123456`. When you start the Python server it
will automatically attempt to migrate the `translations` and `history` tables
so their ID columns are `VARCHAR(255)` and can accept these values. If you
receive errors such as `Out of range value for column 'translationId'`, stop
the server, restart it, and verify the alteration statements ran successfully
(they're printed to the console). You may also manually run the following
SQL against your database if needed:

```sql
ALTER TABLE translations MODIFY translationId VARCHAR(255) PRIMARY KEY;
ALTER TABLE history MODIFY id VARCHAR(255) PRIMARY KEY;
ALTER TABLE history MODIFY translationId VARCHAR(255);
```

These migrations are idempotent; running them again won't harm an already
correct schema.

### Database connection pooling

To reduce overhead the Python server now uses a `mysql.connector` connection
pool rather than opening a new socket on every `/sync` call.  The pool is
created lazily on first use with a default size of 5 connections; you can
adjust `_POOL_SIZE` in `lib/DB/server.py` if you expect higher concurrency.
The `get_db_connection()` helper simply returns a connection from this pool,
and callers are responsible for closing it (which returns it to the pool).

### UI changes

The analytics tab has been removed and replaced by a dedicated **Cats** tab in
the bottom navigation bar.  This new section centralizes cat management—each
pet is shown as a large card (with an optional photo) and may be added, edited
(long‑press) or deleted using the floating action button.  When adding or
editing a cat you can now tap the avatar area to pick an image from the
gallery; the chosen picture is copied to the app's documents folder.

Tapping a cat opens a history page showing only that animal's translation
records.  The Profile tab no longer displays cats; it now only shows account
details and includes a "Manage Cats" button that navigates to the Cats tab.
