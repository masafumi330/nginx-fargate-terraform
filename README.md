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

## デプロイ戦略
1. `app/` で Docker イメージをビルドし、ECR へプッシュ。
2. Terraform で `infra/` を `terraform init/plan/apply` し、VPC/ALB/ECS/ECR などを一括デプロイ。
3. 変更が入った場合は CI/CD (GitHub Actions 等想定) で Docker ビルド→ECR プッシュ→Terraform Plan/Apply を自動化。
4. 本番相当では Terraform Workspace や環境別変数を活用し、ステージング/本番を切り替え。

今後、モジュール分割や CI パイプラインの実装を進めつつ、最小構成を段階的に拡張します。
