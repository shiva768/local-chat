# ローカルチャットアプリ 設計書

## 概要

Claude Codeエージェント同士が自律的に会話できるローカルチャットアプリ。
Slackライクなチャンネル制で、プロジェクトごとにエージェントを切り替えて使う。

---

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
                 │ SQLite (drift)
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
│  ※ /loop + --dangerously-skip-permissions │
└─────────────────────────────────────────┘
```

---

## ディレクトリ構成

```
~/projects/my-flutter-app/          # 既存のFlutterプロジェクト
  .chat/                            # チャット連携用ディレクトリ
    inbox/
      pm.md                         # PMへのメッセージキュー
      impl.md                       # 実装者へのメッセージキュー
      reviewer.md                   # レビュアーへのメッセージキュー
    outbox/
      pm.md                         # PMからの返信
      impl.md
      reviewer.md
    status.json                     # 各エージェントの状態

  agents/
    pm/
      CLAUDE.md                     # PMエージェントの指示
    impl/
      CLAUDE.md                     # 実装者エージェントの指示
    reviewer/
      CLAUDE.md                     # レビュアーエージェントの指示

~/projects/local-chat/              # チャットアプリ本体
  lib/
    main.dart
    models/
      channel.dart
      message.dart
      agent.dart
    repositories/
      channel_repository.dart
      message_repository.dart
    services/
      websocket_service.dart
      file_watcher_service.dart     # .chat/outbox監視
    screens/
      home_screen.dart
      channel_screen.dart
    widgets/
      message_bubble.dart
      channel_list.dart
      message_input.dart
  server/
    main.dart                       # shelfサーバー
    handlers/
      message_handler.dart
      channel_handler.dart
```

---

## データモデル

### Channel
```dart
class Channel {
  String id;
  String name;           // プロジェクト名
  String? description;
  List<String> agentIds; // 参加エージェント
  String chatDir;        // .chatディレクトリのパス
  DateTime createdAt;
}
```

### Message
```dart
class Message {
  String id;
  String channelId;
  String from;           // エージェント名 or "human"
  String? to;            // メンション先（nullなら全員）
  String content;
  DateTime timestamp;
  String? threadId;      // スレッド返信の場合
}
```

### Agent
```dart
class Agent {
  String id;
  String name;           // pm, impl, reviewer など
  String channelId;
  AgentStatus status;    // active / idle / sleeping
}

enum AgentStatus { active, idle, sleeping }
```

---

## エージェント連携フロー

```
1. 人間またはAIがメッセージを送信
      ↓
2. サーバーがDBに保存 + WebSocketで全クライアントに配信
      ↓
3. メンション対象エージェントのinboxファイルに書き込み
      ↓
4. Claude Codeエージェント（/loopで監視中）がinboxを検知
      ↓
5. エージェントが返信をoutboxファイルに書き込み
      ↓
6. サーバーのFileWatcherがoutboxの変更を検知
      ↓
7. サーバーがDBに保存 + WebSocketで配信
      ↓
8. FlutterUIにリアルタイム表示
```

---

## メッセージファイルのフォーマット

### inbox（エージェントへの入力）
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

### outbox（エージェントからの出力）
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

---

## 各エージェントのCLAUDE.md

### agents/pm/CLAUDE.md
```markdown
あなたはFlutterアプリ開発のPMエージェントです。

# 役割
- 要件を仕様に落とし込む
- 実装者・レビュアーの進捗を管理する
- レビュー結果をもとに仕様を調整する

# 動作ルール
- /loopで動作している。毎ターン以下を実行する：
  1. `../../.chat/inbox/pm.md` を読んでpendingメッセージを確認する
  2. 自分宛のメッセージがあれば返信を作成する
  3. 返信を `../../.chat/outbox/pm.md` に追記する
  4. 処理したメッセージをinboxから削除する

# 注意
- @メンションがなければ返信不要
- メッセージがなければ何もしない
```

### agents/impl/CLAUDE.md
```markdown
あなたはFlutter実装担当エージェントです。

# 役割
- PMの仕様をもとにFlutterコードを実装する
- Riverpodを使った状態管理
- クリーンアーキテクチャに従う

# 動作ルール
- /loopで動作している。毎ターン以下を実行する：
  1. `../../.chat/inbox/impl.md` を読んでpendingメッセージを確認する
  2. 自分宛のメッセージがあれば実装して返信する
  3. 返信を `../../.chat/outbox/impl.md` に追記する
  4. 処理したメッセージをinboxから削除する
```

### agents/reviewer/CLAUDE.md
```markdown
あなたはFlutterコードレビュー担当エージェントです。

# 役割
- コード品質・仕様との整合性・UXを確認する
- 問題があれば実装者に差し戻す
- 問題なければPMに完了報告する

# 動作ルール
- /loopで動作している。毎ターン以下を実行する：
  1. `../../.chat/inbox/reviewer.md` を読んでpendingメッセージを確認する
  2. 自分宛のメッセージがあればレビューして返信する
  3. 返信を `../../.chat/outbox/reviewer.md` に追記する
  4. 処理したメッセージをinboxから削除する
```

---

## 実装フェーズ

### フェーズ1: コア（チャットUI + ログ）
- [ ] Flutterプロジェクト作成
- [ ] SQLiteセットアップ（drift）
- [ ] チャンネル一覧・切り替えUI
- [ ] メッセージ表示UI
- [ ] 人間がメッセージを送れる

### フェーズ2: サーバー + リアルタイム
- [ ] shelfサーバー実装
- [ ] WebSocket接続
- [ ] FlutterからWebSocket経由で送受信

### フェーズ3: エージェント連携
- [ ] ファイル監視サービス（FileWatcher）
- [ ] inbox/outboxファイルの読み書き
- [ ] メンション解析・ルーティング
- [ ] 各エージェントのCLAUDE.md作成

### フェーズ4: 仕上げ
- [ ] スレッド機能
- [ ] エージェントステータス表示（active/idle）
- [ ] Web対応（Flutter Web）

---

## 起動方法（完成後）

```bash
# サーバー起動
cd ~/projects/local-chat && dart run server/main.dart

# Flutterアプリ起動
cd ~/projects/local-chat && flutter run -d macos

# 各エージェント起動
cd ~/projects/my-flutter-app/agents/pm && claude --dangerously-skip-permissions
cd ~/projects/my-flutter-app/agents/impl && claude --dangerously-skip-permissions
cd ~/projects/my-flutter-app/agents/reviewer && claude --dangerously-skip-permissions
# 各ターミナルで /loop を実行
```
