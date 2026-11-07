# デプロイ手順（Render）

本番環境は [Render](https://render.com/) で動かす。Web サービス（無料プラン）と PostgreSQL（無料プラン）の2つを使う。
構成はリポジトリ直下の `render.yaml`（Blueprint）に書いてある。

## 構成

| 項目 | 内容 |
|---|---|
| Web | `dokoiku`（Docker、無料プラン、シンガポール） |
| DB | `dokoiku-db`（PostgreSQL、無料プラン、シンガポール） |
| ビルド | リポジトリの `Dockerfile` |
| 起動 | `bin/docker-entrypoint` が `bin/rails db:prepare`（マイグレーション）を実行してから、Thruster 経由で Puma を起動する |
| ジョブ | Solid Queue を Puma の中で動かす（`SOLID_QUEUE_IN_PUMA=1`） |
| キャッシュ・ジョブ・Action Cable | Solid Cache / Solid Queue / Solid Cable のテーブルも同じ DB に置く（DB は1つ） |
| ヘルスチェック | `/up` |
| DB への外部接続 | `render.yaml` の `ipAllowList: []` で止めている（Render 内部のプライベートネットワークからのみ接続できる） |
| HTTPS | http から https へのリダイレクトは Render のロードバランサーが行う。Rails は `assume_ssl` で全リクエストを https として扱う |

## 初期セットアップ（最初の1回だけ）

1. Render のアカウントを作り、GitHub と連携する（このリポジトリへのアクセスを許可する）
2. Render のダッシュボードで **New → Blueprint** を選び、このリポジトリを選ぶ
3. `render.yaml` の内容（`dokoiku` と `dokoiku-db`）が表示されるので確認する
4. `RAILS_MASTER_KEY` の入力を求められるので、手元の `config/master.key` の中身（1行の文字列）を貼り付ける
   - `config/master.key` はリポジトリに入っていない（`.gitignore` 済み）。絶対にコミットしないこと
   - 鍵をなくすと `config/credentials.yml.enc` を読めなくなる。パスワードマネージャーなどに控えておく
5. **Apply** を押す。DB の作成 → Docker イメージのビルド → 起動 の順に進む
6. 完了したら、サービスの画面に出る URL（`https://dokoiku.onrender.com` のような形）を開き、ログインと場所の登録ができることを確かめる

あとから `RAILS_MASTER_KEY` を変える場合は、サービスの **Environment** 画面で編集する。

## 自動デプロイの流れ

1. `main` ブランチに push（PR をマージ）する（`render.yaml` の `autoDeployTrigger: commit`）
2. Render が検知して Docker イメージをビルドする
3. 新しいコンテナが起動し、`bin/rails db:prepare` でマイグレーションが走る
4. `/up` のヘルスチェックが通ると新しいバージョンに切り替わる（通らなければ前のバージョンのまま）

手動でデプロイし直したいときは、サービスの画面右上の **Manual Deploy → Deploy latest commit** を使う。

## ログの見方

- ビルドとデプロイのログ：サービスの **Events** 画面で各デプロイを開く
- アプリのログ（Rails / Puma / Solid Queue）：サービスの **Logs** 画面。キーワードで絞り込める
- 無料プランではログの保存期間が短いので、気になるエラーは早めに確認する

## 無料プランの制限

### Web：15分でスリープする

- 15分間アクセスがないとサービスが止まる（スピンダウン）
- 次のアクセスで起動し直すので、最初の表示に1分近くかかることがある。故障ではない
- スリープ中は Solid Queue も止まる

### DB：作成から30日で期限切れになる

- 無料の PostgreSQL は **作成から30日で期限切れ** になる
- 無料の DB は **1アカウントにつき同時に1つまで** しか作れない
- 期限が切れると使えなくなり、さらに **14日の猶予期間** のあとに **データごと削除** される
- 期限日の確認：ダッシュボードで `dokoiku-db` を開くと、期限日（expires）が表示される。Render からメールでも通知が来る
- 続けて使う場合は、**猶予期間（期限切れから14日）が終わるまでに** 有料プランへ上げる（期限切れ前でも猶予期間中でもよい）
  - `dokoiku-db` の画面で **Upgrade**（またはインスタンスタイプの変更）から有料プランを選ぶ
  - プランを上げても **データはそのまま残る**
  - `render.yaml` の `dokoiku-db` の `plan: free` を、選んだ実際のプラン名（例：`basic-256mb`）に書き換えておく
- 料金や制限は変わることがあるので、最新の情報は Render の公式ドキュメント（Free instances のページ）で確認する

## 環境変数

`render.yaml` で設定しているもの。

| 変数 | 値 | 役割 |
|---|---|---|
| `DATABASE_URL` | `dokoiku-db` の接続文字列 | DB の接続先（Render が自動で入れる） |
| `RAILS_MASTER_KEY` | `config/master.key` の中身 | credentials の復号。ダッシュボードで入力する |
| `SOLID_QUEUE_IN_PUMA` | `1` | Solid Queue を Puma の中で起動する |
| `HTTP_PORT` | `10000` | Thruster が待ち受けるポート |
| `PORT` | `10000` | Render が通信を流すポート。Puma は Thruster が `TARGET_PORT`（既定 3000）で起動する |

`RENDER_EXTERNAL_HOSTNAME` は Render が自動で入れる（`dokoiku.onrender.com` のような値）。

## ホスト制限

- `config/environments/production.rb` では、`RENDER_EXTERNAL_HOSTNAME` がある場合だけ、そのホスト名からのアクセスを許可している（ほかのホスト名は拒否。`/up` は除く）
- `RENDER_EXTERNAL_HOSTNAME` が無い環境では `config.hosts` は空のままなので、ホスト制限はかからない
- 独自ドメインを使う場合は、そのドメインを `config.hosts` に追加する必要がある（追加しないと、独自ドメインからのアクセスが拒否される）
