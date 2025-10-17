# KOL競馬データ処理・変換パイプライン on GCP

このリポジトリは、Google Cloud Platform (GCP) 上に、競馬データ（KOL形式）を処理・変換するためのデータパイプラインを構築するものです。

主な機能は以下の2つです。
1.  **データ取り込み**: GCSへのファイルアップロードをトリガーに、Cloud Functionsがデータをパースし、BigQueryの生データテーブルに格納します。
2.  **データ変換**: Dataformを使い、BigQuery上の生データを分析しやすい形式（データマート）に変換します。

インフラの構築からデータ変換のロジックまで、すべてがコードとして管理されています。

## アーキテクチャ

このパイプラインは以下の流れで動作します。

```mermaid
graph TD
    subgraph データ取り込み (Ingestion)
        A[1. ユーザーがZIPファイルをGCSにアップロード] --> B(GCS Bucket);
        B -- Eventarcトリガー --> C{Cloud Functions};
        C -- データをパースしUpsert --> D[BigQuery Raw Tables<br>(kol_keiba.kol_den1, etc.)];
    end

    subgraph データ変換 (Transformation)
        D -- ソースとして参照 --> E{Dataform};
        E -- 変換クエリ(race.sqlx)を実行 --> F[BigQuery Mart Tables<br>(dataform_mart.race, etc.)];
    end

    style A fill:#D5E8D4,stroke:#82B366
    style F fill:#DAE8FC,stroke:#6C8EBF
```

1.  **データ取り込み**: ユーザーがKOLデータを含むZIPファイルをGCSにアップロードすると、Eventarcがそれを検知し、Cloud Functionを起動します。Functionはアーカイブを展開・パースし、BigQueryの`kol_keiba`データセット内の各テーブルにデータを書き込みます。
2.  **データ変換**: Dataformは`kol_keiba`データセットのテーブルをソースとして参照します。開発者がDataformワークスペースから実行をトリガーすると、`race.sqlx`などの変換ロジックが実行され、分析用途に整形された新しいテーブルが`dataform_mart`データセットに作成されます。

## 技術スタック

- **クラウド**: Google Cloud Platform
  - **コンピューティング**: Cloud Functions (第2世代)
  - **ストレージ**: Cloud Storage (GCS)
  - **DWH**: BigQuery
  - **データ変換**: Dataform
  - **イベント**: Eventarc
  - **ID管理**: IAM
- **IaC**: Terraform
- **言語**: Python (Cloud Functions), SQL (Dataform)

## ディレクトリ構成

```
.
├── terraform/      # GCPインフラを定義するTerraformコード
│   ├── dataform.tf
│   ├── variables.tf
│   └── ... (Cloud Functions, GCS等の定義ファイル)
└── dataform/       # データ変換ロジックを定義するDataformプロジェクト
    ├── dataform.json
    └── definitions/
        ├── sources/
        │   └── sources.sqlx
        └── race.sqlx
```

- **`terraform/`**: GCSバケット、Cloud Function、BigQueryデータセット、Dataformリポジトリなど、GCP上のすべてのリソースを定義します。
- **`dataform/`**: BigQuery上のデータをどのように変換するかを定義するSQLXファイル群を格納します。

## セットアップとデプロイ手順

### 1. 前提条件

- Google Cloud SDK (gcloud CLI) がインストール済みであること。
- Terraform がインストール済みであること。
- GCPプロジェクトで課金が有効になっていること。

### 2. 環境設定

```bash
# GCPにログイン
gcloud auth login

# 使用するプロジェクトIDを設定
gcloud config set project smartkeiba

# アプリケーションのデフォルト認証情報を設定
gcloud auth application-default login
```

### 3. インフラのデプロイ

```bash
# Terraformディレクトリに移動
cd terraform

# Terraformを初期化
terraform init

# (任意) どのようなリソースが作成されるか確認
terraform plan

# リソースをGCP上に作成
terraform apply
```
`apply`が完了すると、GCSバケット、Cloud Function、Dataformリポジトリなどのインフラが構築されます。

### 4. Dataformリポジトリの設定

TerraformはDataformリポジトリの「器」を作成するだけです。ローカルの`dataform/`ディレクトリ内のコードをリポジトリに反映させるために、Gitリポジトリと連携させる必要があります。

1.  GitHubやCloud Source Repositoriesに、このプロジェクト用の新しいリモートリポジトリを作成します。
2.  `terraform apply`の出力に表示される`dataform_repository_url`にアクセスします。
3.  Dataformの画面の指示に従い、作成したリモートリポジトリをDataformリポジトリに接続します。
4.  ローカルのこのプロジェクト全体を、作成したリモートリポジトリにプッシュします。

## パイプラインの実行方法

1.  **データ取り込み**: KOLデータを含む`.zip`ファイルを、Terraformが作成したGCSバケット (`kol-keiba-bucket`) にアップロードします。Cloud Functionが自動で起動し、BigQueryの`kol_keiba`データセットにデータが格納されます。
2.  **データ変換**: `terraform apply`の出力に表示される`dataform_workspace_url`にアクセスします。ワークスペース上で「実行を開始」ボタンを押し、`race`テーブルなどのデータマートを生成・更新します。

## クリーンアップ

作成したすべてのGCPリソースを削除するには、以下のコマンドを実行します。

```bash
cd terraform
terraform destroy
```