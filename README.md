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

## ECS & ALB (infra/ecs.tf)
- `aws_ecs_cluster` で Container Insights 有効なクラスターを作成。
- Fargate タスク定義は `cpu=256 / memory=512` の軽量設定、CloudWatch Logs `/ecs/<project>` に吐き出す。
- IAM の execution/task role を Terraform で管理し、ECR Pull + Logs 出力に最小権限を付与。
- Application Load Balancer + Target Group を作成し、Private Subnet の Fargate タスクを IP ターゲットとして登録。
- `aws_ecs_service` は Private Subnet で `desired_count>=AZ 数` を維持し、`spread` placement で AZ ごとにタスクを分散。変数でポート/ヘルスチェックパス/タスク数を調整可能。

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
### 初回
1. Docker image push先となるECR repositoryを作成 `$ terraform apply -target=aws_ecr_repository.app`
2. Login ECR, Build/tagged/Push Docker image

```bash
$ aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <accountID>.dkr.ecr.<region>.amazonaws.com
$ docker build -t app .
$ docker tag app:latest <accountID>.dkr.ecr.<region>.amazonaws.com/todo:latest
$ docker push <accountID>.dkr.ecr.<region>.amazonaws.com/todo:latest
```

3. Create all resources `$ terraform apply`

### 以降
1. Update source code
2. Push to "main" branch
3. Trigger GitHub Actions and action below
  - Login ECR
  - Build/tagged/Push to ECR
  - Update task definition for new image ID
  - Rolling Update Deploy ECS task definition

発展: Rolling Update -> Blue/Green Deploy
参考
- [GitHub Actionsを使用したECSへのBlue/Greenデプロイ](https://dev.classmethod.jp/articles/github-actions-ecs-blue-green/)
