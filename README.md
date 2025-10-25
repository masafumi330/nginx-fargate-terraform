# nginx-fargate-terraform

## プロジェクト概要
Terraform で AWS インフラをコードとして管理し、nginx を Fargate 上で実行して Application Load Balancer 経由で配信する最小構成のサンプルです。ECR に格納したカスタム Docker イメージを ECS サービスが取得し、プライベートサブネット内で動作させます。

## 目的
- 以下スキルアップのため
  - IaC管理
  - パブリッククラウド設計・構築スキル
  - CI/CD設計・構築スキル

## アーキテクチャ構成
- **VPC**: 2 AZ 構成。Public Subnet に ALB、Private Subnet に Fargate サービスを配置。
- **ECR**: nginx ベースの Docker イメージをプッシュ。
- **ECS Fargate**: 単一サービス/タスク定義。タスクロールと実行ロールは Terraform で管理。
- **ALB**: HTTPS/TCPリスナーで外部からのリクエストを受け、ターゲットグループ経由で Fargate へルーティング。
- **Security Group**: ALB→Fargate 間のみ許可し、Egress/Ingress を最小限に制限。

## フォルダ構成 (ドラフト)
```
nginx-fargate-terraform/
├─ README.md
├─ infra/            # Terraform モジュール・環境別設定
│  ├─ main.tf
│  ├─ vpc.tf
│  ├─ ecs.tf
│  ├─ alb.tf
│  ├─ ecr.tf
│  ├─ variables.tf
│  └─ outputs.tf
├─ app/              # nginx 用 Dockerfile と静的アセット
│  ├─ Dockerfile
│  └─ html/
│     └─ index.html
├─ scripts/          # デプロイ/CI 用スクリプト群
│  ├─ build_and_push.sh
│  └─ deploy.sh
└─ manual/           # 手順書や補足資料
   └─ deployment.md
```

## ネットワーク (infra/vpc.tf)
- VPC は `10.10.0.0/20` を確保し、DNS サービスを有効化。
- AZ は `ap-northeast-1a` / `1c` を使用し、Public/Private 各 `/24` を割り当て。
- Public Subnet は Internet Gateway + Route Table で 0.0.0.0/0 を公開し、ALB を配置予定。
- Private Subnet は Fargate タスク用。ルートはローカルのみ (学習用のため NAT 無しスタート)。
- Security Group は `alb_sg` (80番のみ) と `ecs_sg` (alb_sg からの 80番) に分離。
- `variables.tf` で CIDR や AZ をパラメータ化し、タグは `locals.common_tags` で統一管理。

## コンテナレジストリ (infra/ecr.tf)
- `aws_ecr_repository` で `project_name` ベースのリポジトリを作成。タグは `IMMUTABLE` で誤上書きを防止。
- Push 時の脆弱性スキャンを有効化 (`scan_on_push = true`)。
- ライフサイクルポリシーで最新 5 イメージのみ保持し、ストレージコストを抑制。
- `ecr_force_delete` 変数で削除挙動 (force) を制御し、環境に応じた安全性を確保。
- `outputs.tf` からリポジトリ URL / ARN をエクスポートし、CI/CD や Terraform 他リソースで参照。

## アプリケーション (app/) の基本
- `app/Dockerfile`: 公式 `nginx:alpine` をベースに静的ファイルをデプロイ。`Hello, nginx!` を返すシンプルな HTML を配置。
- `app/html/index.html`: Fargate で配信される静的ページ。ブランド確認用の簡易スタイルを付与。
- `app/.dockerignore`: `.git` や不要ファイルをビルドコンテキストに含めないためのフィルター。

ローカルでのビルド／起動例:
```bash
docker build -t hello-nginx ./app
docker run --rm -p 8080:80 hello-nginx
# http://localhost:8080 → "Hello, nginx!" と表示されれば OK
```

## デプロイ戦略
1. `app/` で Docker イメージをビルドし、ECR へプッシュ。
2. Terraform で `infra/` を `terraform init/plan/apply` し、VPC/ALB/ECS/ECR などを一括デプロイ。
3. 変更が入った場合は CI/CD (GitHub Actions 等想定) で Docker ビルド→ECR プッシュ→Terraform Plan/Apply を自動化。
4. 本番相当では Terraform Workspace や環境別変数を活用し、ステージング/本番を切り替え。

今後、モジュール分割や CI パイプラインの実装を進めつつ、最小構成を段階的に拡張します。
