# freebuff2api

Codebuff Freebuff 的 OpenAI-compatible API

<img width="480" height="1032" alt="image" src="https://github.com/user-attachments/assets/8a12f1ef-42ea-41eb-b47b-40d86550bbc9" />


## 接口

- `GET /v1/models`
- `POST /v1/chat/completions`
- `GET /healthz`

## 配置

### 获取 Token

无需安装 Freebuff / Codebuff CLI，可以直接打开公开页面自动获取 token：

```text
https://freebuff.071129.xyz/
```

使用方式：

1. 打开上面的地址
2. 选择 Freebuff
3. 点击“开始认证”，在跳转页面完成授权
4. 回到页面复制展示的 token
5. 将复制结果写入本项目 `.env`

示例：

```dotenv
FREEBUFF_TOKEN=你的 Freebuff Bearer token
```

多账号可用英文逗号分隔；并发请求会优先分配到空闲账号，避免单个
Freebuff 账号的全局 active free session 被并发切模型请求互相覆盖：

```dotenv
FREEBUFF_TOKEN=token-a,token-b,token-c
```

复制 `.env.example` 为 `.env`，然后填写上游 token：

```powershell
Copy-Item .env.example .env
```

`.env` 示例：

```dotenv
FREEBUFF_TOKEN=你的 Freebuff Bearer token
FREEBUFF_API_KEY=本地 OpenAI API key，可留空
FREEBUFF_AD_PROVIDERS=gravity,zeroclick
FREEBUFF_PROXY_ENABLED=false
FREEBUFF_PROXY_URL=
FREEBUFF_DEBUG=false
FREEBUFF_LOG_LEVEL=INFO
FREEBUFF_LOG_BODY_CHARS=2000
FREEBUFF_LOG_COLOR=true
FREEBUFF_HOST=0.0.0.0
FREEBUFF_PORT=8000
```

默认不启用代理，所有上游请求直连，且不会读取系统 `HTTP_PROXY` / `HTTPS_PROXY`。

需要让所有上游请求经过代理时，在 `.env` 中开启：

```dotenv
FREEBUFF_PROXY_ENABLED=true
FREEBUFF_PROXY_URL=http://127.0.0.1:7890
```

支持 HTTP 和 SOCKS 代理，例如：

```dotenv
FREEBUFF_PROXY_URL=http://127.0.0.1:7890
FREEBUFF_PROXY_URL=socks5://127.0.0.1:1080
FREEBUFF_PROXY_URL=socks5h://127.0.0.1:1080
```

当前内置 Freebuff 模型：

- `deepseek/deepseek-v4-flash`
- `deepseek/deepseek-v4-pro`
- `moonshotai/kimi-k2.6`
- `minimax/minimax-m2.7`

当前内置 Gemini free agent 组合：

- `google/gemini-2.5-flash-lite` -> `base2-free-deepseek-flash` 父 agent + `file-picker` 子 agent
- `google/gemini-3.1-flash-lite-preview` -> `base2-free-deepseek-flash` 父 agent + `file-picker-max` 子 agent
- `google/gemini-3.1-pro-preview` -> `base2-free-kimi` 父 agent + `thinker-with-files-gemini` 子 agent

调用 Gemini 时无需手动传 agent。项目会把 OpenAI 请求中的 `model`
解析为上游允许的 `agentId + model` 组合，并继续在
`codebuff_metadata.cost_mode=free` 下请求。Gemini free agents 会自动作为
active Freebuff session root 的子 agent 运行；未知模型不会自动兜底到 Gemini。

调试空返回或上游异常时：

```dotenv
FREEBUFF_DEBUG=true
FREEBUFF_LOG_LEVEL=DEBUG
FREEBUFF_LOG_BODY_CHARS=0
```

## 运行

```powershell
uv sync
uv run freebuff2api
```

或：

```powershell
python -m pip install -e .
python main.py
```

## Docker

镜像为多架构（`linux/amd64` + `linux/arm64`），由仓库内的 GitHub Actions
（`.github/workflows/docker-publish.yml`）在推送到 `main` 或打 `v*` tag 时自动
构建并发布到 GitHub Container Registry：

```text
ghcr.io/denniszlei/freebuff2api:latest
```

> 配置全部通过环境变量传入（变量含义见 `.env.example`），容器内**不需要** `.env` 文件。
> 若包是 private，`docker pull` / `docker compose up` 前需先 `docker login ghcr.io`；
> 也可在 GitHub 的 Package 设置里将其改为 public。

### docker run

先准备好 `.env`（至少填 `FREEBUFF_TOKEN`），用 `--env-file` 直接复用：

```bash
docker run -d \
  --name freebuff2api \
  -p 8000:8000 \
  --env-file .env \
  --restart unless-stopped \
  ghcr.io/denniszlei/freebuff2api:latest
```

或不用 `.env`，直接用 `-e` 传关键变量：

```bash
docker run -d \
  --name freebuff2api \
  -p 8000:8000 \
  -e FREEBUFF_TOKEN=你的-token \
  -e FREEBUFF_API_KEY=sk-local \
  --restart unless-stopped \
  ghcr.io/denniszlei/freebuff2api:latest
```

### docker compose

仓库根目录已提供 `docker-compose.yml`：

```bash
cp .env.example .env   # 编辑 .env，至少填 FREEBUFF_TOKEN
docker compose up -d
docker compose logs -f
```

### 自行构建

不想用 GHCR 镜像时，可本地构建（compose 里把 `image:` 注释掉、`build: .` 打开亦可）：

```bash
docker build -t freebuff2api .
docker run -d --name freebuff2api -p 8000:8000 --env-file .env freebuff2api
```

> 自定义端口：改 `.env` 里的 `FREEBUFF_PORT`，compose 会自动跟随；用 `docker run`
> 时记得把 `-p` 映射改成同一个端口。

启动后接口同样在 `http://127.0.0.1:8000`，调用方式见下文。

## 调用示例

```powershell
curl http://127.0.0.1:8000/v1/chat/completions `
  -H "Authorization: Bearer $env:FREEBUFF_API_KEY" `
  -H "Content-Type: application/json" `
  -d '{
    "model": "deepseek/deepseek-v4-flash",
    "messages": [{"role": "user", "content": "你好"}],
    "stream": false
  }'
```

流式：

```powershell
curl -N http://127.0.0.1:8000/v1/chat/completions `
  -H "Authorization: Bearer $env:FREEBUFF_API_KEY" `
  -H "Content-Type: application/json" `
  -d '{
    "model": "deepseek/deepseek-v4-flash",
    "messages": [{"role": "user", "content": "写一个 Python 快排"}],
    "stream": true
  }'
```

## 感谢

> [FreeBuff](https://freebuff.com)
