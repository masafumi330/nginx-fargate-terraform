FROM nginx:1.27-alpine

# 非 root 実行のためユーザーを維持 (nginx公式は既に nginx ユーザーあり)
WORKDIR /usr/share/nginx/html

COPY html/ ./

# 簡易ヘルスチェック (HTTP 200 を期待)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1 || exit 1

EXPOSE 80

