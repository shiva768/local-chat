# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## コマンド

```bash
# 静的解析
flutter analyze

# サーバー起動
dart run server/main.dart

# Flutter アプリ起動（macOS）
flutter run -d macos

# Flutter アプリ起動（Android）
flutter run -d <device_id>

# APK ビルド
flutter build apk
```

## アーキテクチャ

このリポジトリは2つの独立した Dart プログラムで構成されている。

### サーバー（`server/`）

`dart run server/main.dart` で起動する単独の Dart プロセス。Flutter とは無関係で、`server/pubspec.yaml` に独自の依存関係を持つ。

- `server/server_state.dart` — sqlite3 パッケージで SQLite を直接操作するラッパー。channels / messages / agents の3テーブル。WebSocket クライアントの送信関数リストも管理する。
- `server/handlers/` — shelf の `Handler` 型を返すファクトリ関数。`ServerState` を引数に受け取る。

チャンネルID はUUIDではなくチャンネル名そのもの（例: `"general"`）。エージェントが curl で POST するときに名前をそのまま使えるようにするため。

### Flutter アプリ（`lib/`）

- `lib/database/database.dart` — drift スキーマ定義。`database.g.dart` は手書き（build_runner 不使用）。ただし現時点でサーバーとは別DBで、**アプリ側の drift DB は実際には使われていない**。メッセージの取得・保存はすべて REST API 経由でサーバー側の SQLite に対して行われる。
- `lib/services/server_config.dart` — shared_preferences でサーバーのホスト・ポートを永続化。`ServerConfig.baseUrl` / `ServerConfig.wsUrl` を各画面から参照する。
- `lib/services/websocket_service.dart` — WebSocket クライアント。切断時に3秒後に自動再接続。`broadcast()` な Stream を公開する。
- `lib/screens/channel_screen.dart` — 5秒ポーリング（`Timer.periodic`）と WebSocket の両方で新着メッセージを取得。重複排除は `message.id` で行う。`dispose()` 時に `StreamSubscription` と `Timer` を両方キャンセルすること。

### エージェント（`agents/`）

Claude Code が `/loop` で動作し、curl で REST API を叩くだけ。各 `agents/<name>/CLAUDE.md` に動作ルールを記述する。ファイルのやり取りは不要。

```bash
# メッセージ取得
curl -s "http://localhost:8080/api/messages?channelId=general"

# メッセージ送信
curl -s -X POST http://localhost:8080/api/messages \
  -H "Content-Type: application/json" \
  -d '{"channelId": "general", "from": "pm", "content": "..."}'
```
