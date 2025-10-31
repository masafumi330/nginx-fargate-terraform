# Terraformで構築するECS Fargate環境の備忘録

## はじめに
TerraformによるAWSリソースの作成、ECS Fargateによるwebサーバーのコンテナ化を実際に行ってみることを目的として、nginx を ECS Fargate 上でホスティングする最小構成を Terraform で組む際の備忘録です。なお、CI/CD や独自ドメインは範囲外とし、ALB のパブリックDNS で動作確認することとします。

## ゴール
TOPページ（<ALBのパブリックDNS>/にアクセス）にてHello Worldと表示されていればOK

### この記事で扱うこと
- Terraform で AWS ネットワークと ECS (Fargate 起動タイプ) を構築する手順
- ECR へのイメージ Push と初回 `terraform apply` の流れ
- Fargate が提供する AZ 冗長性とタスク分散の確認ポイント

### この記事で扱わないこと
- Route 53 やカスタムドメイン設定 (ALB のパブリック DNS でアクセス)
- CI/CD パイプライン構築や自動承認フロー

## 手順の全体像
1. Terraform モジュールを初期化し、VPC/ALB/ECR/ECS をコード化。
2. ECR を先に作成してリポジトリを確保。
3. Docker イメージをビルドして ECR に Push。
4. Terraform で全リソースを適用し、ECS サービスを起動。
5. ALB の DNS 名経由でブラウザから Hello World を確認。

## アーキテクチャ全体像
< ここに図 >

### 構成要素
- VPC：Public/Private の 2 種類のサブネットを各 AZ に 1 つずつ配置し、NAT ゲートウェイは Public 側に設置。
- ALB：Public サブネットに配置し、外部からの HTTP トラフィックを受け付けて ECS タスクへルーティング。
- ECS サービス (Fargate)：Private サブネットでタスクを実行し、タスク定義で ECR 上の nginx イメージを参照。
- ECR：`nginx-fargate-terraform` リポジトリをホストし、コンテナイメージを提供。
- CloudWatch Logs：コンテナログを `/ecs/nginx` ロググループへ集約。

### セキュリティ
- セキュリティグループとしてALB, ECS用にインバウンドを最小限に抑える
  - インターネット -> ALB (:80/TCP) -> ECS (:80/TCP from ALB SG)
- ECSにタスク及びタスク実行ロールのAssume Role(一時的に権限を付与する)
  - タスクロール：タスク自体の権限。S3やDynamoDBなどに接続する場合はこちらが必要。今回は最小構成なので特になし。
  - タスク実行ロール： コンテナ起動時の共通操作 (ECR 認証/ログ出力) 用。

### 可用性
- Fargate は `desired_count = 2` で 2 AZ にタスクを分散
  - [Fargate は、複数サブネットが指定されている場合、AZ を跨いでタスクを配置するようベストエフォートになっている。](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/service-rebalancing.html#service-rebalancing-placement-constraints)



## 初回デプロイ手順
### 1. Terraform モジュールを初期化し、VPC/ALB/ECR/ECS をコード化
```bash
terraform init
```

### 2. ECR を先に作成してリポジトリを確保
アプリのイメージを Push できるよう、ECR だけ先に作成しておく。
```bash
terraform apply -target=aws_ecr_repository.app
```

### 3. Docker イメージをビルドして ECR に Push
```bash
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com
docker build -t nginx-fargate-sample .
docker tag nginx-fargate-sample:latest <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com/nginx-fargate-terraform:latest
docker push <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com/nginx-fargate-terraform:latest
```

### 4. Terraform で全リソースを適用し、ECS サービスを起動
```bash
terraform apply
```

### 5. ALB の DNS 名経由でブラウザから Hello World を確認
1. `terraform output alb_dns_name` で ALB の DNS 名を取得。
2. ブラウザで `http://<alb_dns_name>` を開き、`Hello, nginx!` が表示されるか確認。
3. `aws ecs list-tasks --cluster nginx-fargate-terraform-cluster` でタスク数を確認 (デフォルトは 2)。
4. CloudWatch Logs コンソールで `/ecs/nginx` ロググループへ出力されているかチェック。

## 今後試したいこと
- **ECS ネイティブの Blue/Green デプロイ**: 2025/7 にECSネイティブのBlue/Greenデプロイ機能がリリースされたが、「承認してから本番トラフィックの移行」を行う機能は組み込みでは用意されていないようなので、ここを整えたい。本番運用を想定した場合、テストトラフィックで動作確認してから進めたいというニーズが生まれそうなので。なお、公式では、S3にファイルを配置することで手動承認するサンプルが用意されている。
- 参考
  - https://aws.amazon.com/jp/blogs/news/accelerate-safe-software-releases-with-new-built-in-blue-green-deployments-in-amazon-ecs/
  - https://github.com/aws-samples/sample-amazon-ecs-blue-green-deployment-patterns/blob/main/ecs-bluegreen-lifecycle-hooks/README.md#approval-process
