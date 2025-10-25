variable "aws_region" {
  description = "デプロイ対象の AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "タグやリソース命名に利用するプレフィックス"
  type        = string
  default     = "nginx-fargate-terraform"
}

variable "vpc_cidr" {
  description = "VPC 全体の CIDR ブロック"
  type        = string
  default     = "10.10.0.0/20"
}

variable "azs" {
  description = "利用するアベイラビリティゾーン一覧"
  type        = list(string)
  default = [
    "ap-northeast-1a",
    "ap-northeast-1c"
  ]
}

variable "public_subnet_cidrs" {
  description = "Public Subnet の CIDR リスト (azs と同じ順に指定)"
  type        = list(string)
  default = [
    "10.10.0.0/24",
    "10.10.1.0/24"
  ]

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs と azs の数を合わせてください。"
  }
}

variable "private_subnet_cidrs" {
  description = "Private Subnet の CIDR リスト (azs と同じ順に指定)"
  type        = list(string)
  default = [
    "10.10.10.0/24",
    "10.10.11.0/24"
  ]

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs と azs の数を合わせてください。"
  }
}

variable "tags" {
  description = "任意で追加する共通タグ"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_name" {
  description = "ECR リポジトリ名。未指定の場合は project_name を使用"
  type        = string
  default     = null
}

variable "ecr_image_tag_mutability" {
  description = "ECR イメージタグの変更可否 (MUTABLE / IMMUTABLE)"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability は MUTABLE か IMMUTABLE を指定してください。"
  }
}

variable "ecr_scan_on_push" {
  description = "ECR へ push されたイメージのスキャンを有効化するか"
  type        = bool
  default     = true
}

variable "ecr_force_delete" {
  description = "ECR リポジトリ削除時に未削除イメージがあっても削除するか"
  type        = bool
  default     = false
}

variable "ecr_lifecycle_keep_count" {
  description = "ライフサイクルポリシーで保持する最新イメージ数"
  type        = number
  default     = 5

  validation {
    condition     = var.ecr_lifecycle_keep_count > 0
    error_message = "ecr_lifecycle_keep_count は 1 以上を指定してください。"
  }
}
