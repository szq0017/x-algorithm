# x-algorithm 変更ウォッチ・ルーティン

`xai-org/x-algorithm`（X「For You」フィードの推薦アルゴリズム）の更新を**定時で監視**し、変更があったら**コード解析**を行い、**X（旧Twitter）でのユーザー行動への影響**を日本語レポートにまとめて蓄積する仕組みです。

---

## なぜこの構成なのか（重要な制約）

このリポジトリ `szq0017/x-algorithm` は `xai-org/x-algorithm` の**公開フォーク**です。Claude の実行セッションは、セッションにひも付いた（＝同一オーナーの）リポジトリしか直接参照できず、公式 `xai-org/x-algorithm` へは直接アクセスできません（`add_repo` はクロスオーナー追加不可）。

そこで **2つのエンジン**に役割を分けています。

| エンジン | 実行場所 | 役割 | アクセス |
|---|---|---|---|
| **① 上流同期** (`.github/workflows/sync-upstream.yml`) | GitHub Actions（GitHub側） | フォークの `main` を上流 `xai-org` から自動同期 | GitHub側なので**公式（公開）を読める** |
| **② 監視ルーティン** (Claude Routine) | Claude 実行環境 | `main` の変更を検知 → コード解析 → 影響レポート生成 → コミット＋プッシュ通知 | フォーク（同一オーナー）を読める |

①が「公式の更新をフォークに取り込む橋渡し」、②が「取り込まれた変更の解析と要約」を担当します。

```
xai-org/x-algorithm (公式)
        │  ① GitHub Actions: gh repo sync（毎日）
        ▼
szq0017/x-algorithm : main（上流のミラー）
        │  ② Claude Routine（毎日）: 差分検知 → 解析 → レポート
        ▼
reports/YYYY-MM-DD.md（コミット）＋ プッシュ通知
```

---

## 構成ファイル

| パス | 役割 |
|---|---|
| `monitoring/sync-upstream.workflow.yml` | ① 上流同期 GitHub Actions の**テンプレート**。`.github/workflows/sync-upstream.yml` として配置して使う（下記セットアップ 0 参照） |
| `monitoring/state.json` | 最後に解析したコミットSHA等の状態。②が差分判定に使い、解析後に更新する |
| `monitoring/check_changes.sh` | `origin/<watched_branch>` を `state.json` の SHA と比較し、変更・差分を出力するヘルパ |
| `monitoring/README.md` | 本ドキュメント |
| `reports/` | 生成されたレポートの蓄積先（`YYYY-MM-DD-baseline.md` が初回基準） |

> **なぜワークフローがテンプレート同梱なのか:** Claude の GitHub App 連携には `workflows` 権限スコープが無く、`.github/workflows/` 配下のファイルを push できません（`refusing to allow a GitHub App to create or update workflow ... without workflows permission`）。そのため YAML はテンプレートとして同梱し、リポジトリオーナー（＝あなた）が配置します。

---

## 有効化に必要な手動セットアップ（一度だけ）

Claude 側で作れない「リポジトリ設定／ワークフロー配置」は次の手順で有効化してください。

### 0. 上流同期ワークフローを配置する — ✅ 対応済み（`.github/workflows/sync-upstream.yml` 配置済み・デフォルトブランチ `monitoring`）
Claude の GitHub App は `workflows` 権限を持たないため、ワークフローはテンプレート（`monitoring/sync-upstream.workflow.yml`）として同梱しています。リポジトリオーナーが `.github/workflows/sync-upstream.yml` に配置します。**本リポジトリでは配置済みです。** 再設置・別リポジトリで使う場合は、いずれかの方法で：

- **GitHub UI:** リポジトリ画面の `Add file → Create new file` でパスを `.github/workflows/sync-upstream.yml` とし、`monitoring/sync-upstream.workflow.yml` の内容を貼り付けてコミット。
- **ローカル（自分の認証情報）:**
  ```bash
  git checkout <自動化ブランチ>
  mkdir -p .github/workflows
  cp monitoring/sync-upstream.workflow.yml .github/workflows/sync-upstream.yml
  git add .github/workflows/sync-upstream.yml && git commit -m "Add upstream sync workflow" && git push
  ```

### 1. GitHub Actions を有効化
フォークでは Actions が既定で無効な場合があります。
`Settings → Actions → General → Allow all actions and reusable workflows` を選択。

### 2. `main` を「純粋な上流ミラー」に保つ（自動同期が壊れないため）
`gh repo sync` は上流HEADへの **fast-forward** で同期します。`main` に独自コミットを載せると分岐して同期が失敗します。したがって：

- **自動化ファイル（この `monitoring/` と `.github/workflows/`、`reports/`）は `main` に置かない。**
- それらを持つ**自動化ブランチ `monitoring`** を**デフォルトブランチ**に設定する（✅ 設定済み。`HEAD branch: monitoring`）。
  - スケジュール実行の GitHub Actions は**デフォルトブランチからのみ**起動するため、この設定が必要です。
- `main` は触らず、①のワークフローに上流ミラーとして同期させ続ける。

> 代替案（デフォルトブランチを変えたくない場合）: `main` に自動化を置いたまま、上流ミラー用に別ブランチ（例 `mirror-main`）を作り、ワークフローと `state.json` の `watched_branch` をそちらに向ける。②はその `mirror-main` を監視します。

### 3. （任意）Routine の稼働確認
②の Routine は Claude 側で作成済み／作成予定です。①が `main` を更新すると、②が次回の定時実行で差分を検知します。①のセットアップ前でも②は安全に動作し、変更が無ければ何もしません（通知も出しません）。

---

## 手動での動作確認

```bash
# 変更検知だけを試す（レポート生成はしない）
monitoring/check_changes.sh

# 上流同期を手動で走らせる（Actions のタブ → "Sync fork main from upstream" → Run workflow）
# もしくは GitHub のリポジトリ画面 "Sync fork" ボタンでも main を上流に追随できる
```

`check_changes.sh` は末尾付近に `CHANGED=true|false` と `diff_range=<old>..<new>` を出力します。Routine はこの出力を起点に解析を行います。

---

## Routine（②）が各回で行う処理

1. 自動化ブランチをチェックアウトし、`monitoring/check_changes.sh` を実行。
2. `CHANGED=false` なら何もせず終了（無通知）。
3. `CHANGED=true` なら差分（`diff_range`）のコード変更を解析し、
   **「Xユーザー行動への影響」**を日本語Markdownで `reports/YYYY-MM-DD.md` に生成。
4. `state.json` の `last_analyzed_sha` / `last_analyzed_at` を更新し、`history` に追記。
5. レポートと状態をコミット＆プッシュし、プッシュ通知を送る。

解析の観点（何が変わるとユーザー行動に効くか）は、初回ベースラインレポート
`reports/*-baseline.md` の「今後の監視観点」を基準にしています。
