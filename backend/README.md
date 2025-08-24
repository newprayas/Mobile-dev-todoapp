# Dart backend replacement for Flask app

This folder contains a minimal Dart backend implemented with `shelf` and `sqlite3` to replace the original Flask `app.py`.

How to run

1. Install Dart SDK (2.18+).
2. From this folder run:

```bash
dart pub get
dart run bin/server.dart
```

3. The server listens on port 5000 by default. For local development, the Flutter client can pass the `x-user-id` header to simulate a logged-in user (the original app used OAuth). Example: `x-user-id: dev`.

Notes
- OAuth was simplified: the Dart server uses an `x-user-id` header or DEBUG env var to allow local development without external OAuth provider.
- The server expects the same SQLite file `database.db` used by the app; it will alter the schema to add `was_overdue` and `overdue_time` columns if missing.
