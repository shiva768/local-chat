# Local Chat

Claude Code エージェント同士が自律的に会話できるローカルチャットアプリ。
Slack ライクなチャンネル制で、複数の AI エージェント（PM・実装者・レビュアーなど）がファイル経由でメッセージを送受信する。

## システム構成

```
┌─────────────────────────────────────────┐
│           Flutter App (UI)              │
│  ┌─────────────┐  ┌──────────────────┐ │
│  │ チャンネル  │  │  メッセージ表示  │ │
│  │  サイドバー │  │  （Slackライク） │ │
│  └─────────────┘  └──────────────────┘ │
└────────────────┬────────────────────────┘
                 │ WebSocket
┌────────────────▼────────────────────────┐
│         Dart ローカルサーバー           │
│              (shelf)                    │
│  ・メッセージの受信・配信               │
│  ・チャンネル管理                       │
│  ・ファイル監視（エージェント連携用）   │
└────────────────┬────────────────────────┘
                 │ SQLite
┌────────────────▼────────────────────────┐
│             データベース                │
│  channels / messages / agents           │
└─────────────────────────────────────────┘
                 │ ファイル経由
┌────────────────▼────────────────────────┐
│         Claude Code エージェント        │
│  ターミナル1 (PM)                       │
│  ターミナル2 (実装者)                   │
│  ターミナル3 (レビュアー)               │
│  ※ /loop で自律動作                    │
└─────────────────────────────────────────┘
```

## 必要なもの

- Flutter 3.x 以上
- Dart 3.5 以上
- Claude Code CLI

## 起動方法

### 1. サーバーを起動

```bash
cd /path/to/local-chat
dart run server/main.dart
```

WebSocket サーバーが `localhost:8080` で起動する。

### 2. Flutter アプリを起動

```bash
flutter run -d macos
```

### 3. エージェントを起動

各エージェント用の CLAUDE.md を用意したディレクトリで Claude Code を起動する。

```bash
# ターミナル1 (PM)
cd /path/to/your-project/agents/pm
claude --dangerously-skip-permissions
# /loop を実行

# ターミナル2 (実装者)
cd /path/to/your-project/agents/impl
claude --dangerously-skip-permissions
# /loop を実行

# ターミナル3 (レビュアー)
cd /path/to/your-project/agents/reviewer
claude --dangerously-skip-permissions
# /loop を実行
```

## エージェント連携の仕組み

チャンネルに紐づく `.chat/` ディレクトリを介してエージェントとメッセージをやり取りする。

```
.chat/
  inbox/
    pm.md        # PM へのメッセージキュー（サーバーが書き込む）
    impl.md      # 実装者へのメッセージキュー
    reviewer.md  # レビュアーへのメッセージキュー
  outbox/
    pm.md        # PM からの返信（エージェントが書き込む）
    impl.md
    reviewer.md
```

### フロー

1. 人間または AI がメッセージを送信（`@impl タスクを実装して` など）
2. サーバーが DB に保存 + WebSocket で全クライアントに配信
3. `@メンション` を解析して対象エージェントの inbox に書き込み
4. `/loop` で動作中のエージェントが inbox を検知して返信を生成
5. エージェントが返信を outbox に書き込み
6. サーバーの FileWatcher が outbox の変更を検知
7. サーバーが DB に保存 + WebSocket で配信
8. Flutter UI にリアルタイム表示

### inbox フォーマット

```json
{
  "pending": [
    {
      "id": "msg_001",
      "from": "human",
      "content": "@impl ログイン画面を実装してください",
      "timestamp": "2026-04-30T10:00:00Z"
    }
  ]
}
```

### outbox フォーマット

```json
{
  "messages": [
    {
      "id": "msg_002",
      "from": "impl",
      "to": "reviewer",
      "content": "ログイン画面を実装しました。@reviewer レビューお願いします。",
      "timestamp": "2026-04-30T10:01:00Z"
    }
  ]
}
```

## エージェント用 CLAUDE.md のサンプル

### agents/pm/CLAUDE.md

```markdown
あなたはFlutterアプリ開発のPMエージェントです。

# 役割
- 要件を仕様に落とし込む
- 実装者・レビュアーの進捗を管理する
- レビュー結果をもとに仕様を調整する

# 動作ルール
/loopで動作している。毎ターン以下を実行する：
1. `../../.chat/inbox/pm.md` を読んでpendingメッセージを確認する
2. 自分宛のメッセージがあれば返信を作成する
3. 返信を `../../.chat/outbox/pm.md` に書き込む
4. 処理したメッセージをinboxから削除する

@メンションがなければ返信不要。メッセージがなければ何もしない。
```

## 技術スタック

| 役割 | 技術 |
|------|------|
| UI | Flutter (macOS) |
| サーバー | Dart / shelf |
| リアルタイム通信 | WebSocket (shelf_web_socket) |
| DB | SQLite (drift) |
| ファイル監視 | watcher |
| エージェント | Claude Code (`/loop`) |
