# Dub Demo — 阿里云云效实施指南

## 架构总览

代码保留在 GitHub（rickmodel/dub-demo），CI/CD 迁移到阿里云云效 Flow 执行。QoderCLI API Key 存储在云效变量管理中（加密），整个流水线在阿里云内网运行，API Key 不经过 GitHub 或其他公网平台。

```
 开发者                           云效 Flow (阿里云内网)
┌─────────────┐    Push/MR    ┌────────────────────────────────────────┐
│ Qoder IDE   │ ───────────→ │  GitHub (代码托管)                      │
│ 本地开发     │              │    ↓ Webhook                           │
└─────────────┘              │  ┌──────────────────────────────────┐  │
                             │  │ 流水线 1: 主线构建部署             │  │
                             │  │  质量检查 → Docker/ACR → ECS部署  │  │
     钉钉通知                │  │  → QoderCLI Release Notes         │  │
┌─────────────┐              │  └──────────────────────────────────┘  │
│ QoderWork   │ ←──── 钉钉 ──│  ┌──────────────────────────────────┐  │
│ 桌面智能体   │    Webhook   │  │ 流水线 2: MR/PR AI Code Review   │  │
└─────────────┘              │  │  质量检查 → QoderCLI Review       │  │
                             │  │  → 自动修复 Lint                  │  │
                             │  └──────────────────────────────────┘  │
                             │  ┌──────────────────────────────────┐  │
                             │  │ 流水线 3: Issue 自动修复           │  │
                             │  │  QoderCLI Fix → 创建 PR          │  │
                             │  └──────────────────────────────────┘  │
                             │                                        │
                             │  🔐 QODER_API_KEY (云效加密变量)       │
                             │     安全边界内，不经过 GitHub           │
                             └────────────────────────────────────────┘
```

## GitHub Actions vs 云效 Flow 等价映射

| 维度 | GitHub Actions | 云效 Flow |
|------|---------------|----------|
| 代码托管 | GitHub Repo | Codeup（或 GitHub 服务连接） |
| CI/CD 引擎 | GitHub Actions | 云效 Flow |
| 流水线配置 | `.github/workflows/*.yml` | 云效 UI / YAML 模式 |
| 密钥管理 | GitHub Secrets（❌公网） | 云效变量管理（✅阿里云内网） |
| 触发方式 | on: push/pull_request/issues | 代码源触发 / Webhook 触发 |
| 构建环境 | `runs-on: ubuntu-latest` | `runsOn: China Aliyun Linux 3` |
| 镜像推送 | docker login + push | `ACRDockerBuild` 内置步骤 |
| 主机部署 | `appleboy/ssh-action` | `AliyunECSCommand` 内置步骤 |
| 人工审批 | Environment protection rules | `ManualApproval` 组件 |
| 通知 | 自定义 Webhook | `DingTalkNotice` 内置步骤 |
| 项目管理 | GitHub Issues | 云效 Projex |
| PR/MR | GitHub Pull Request | Codeup Merge Request |

## 实施步骤

### 第一步：创建云效服务连接

1. 登录 [云效控制台](https://flow.aliyun.com)
2. 进入「设置 → 服务连接 → 新建服务连接」
3. 选择「GitHub」类型
4. 填写 GitHub Personal Access Token（需 repo 权限）
5. 验证连接成功后保存

创建后，所有流水线都可以通过此服务连接拉取 `rickmodel/dub-demo` 代码。

### 第二步：配置流水线变量

在云效 Flow 的「组织设置 → 变量管理」中添加以下变量：

| 变量名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `QODER_API_KEY` | 加密 | QoderCLI API Key | `sk-ant-...` |
| `GITHUB_TOKEN` | 加密 | GitHub PAT（Issue修复流水线用） | `ghp_...` |
| `ACR_NAMESPACE` | 普通 | ACR 命名空间 | `dub-demo` |
| `ACR_USERNAME` | 加密 | ACR 登录用户名 | — |
| `ACR_PASSWORD` | 加密 | ACR 登录密码 | — |
| `STAGING_ECS_ID` | 普通 | Staging ECS 实例 ID | `i-bp1...` |
| `PROD_ECS_ID` | 普通 | Production ECS 实例 ID | `i-bp2...` |
| `STAGING_URL` | 普通 | Staging 环境 URL | `https://staging.dub.example.com` |
| `APP_URL` | 普通 | 应用公网 URL | `https://dub.example.com` |
| `DINGTALK_WEBHOOK` | 加密 | 钉钉群机器人 Webhook | `https://oapi.dingtalk.com/robot/send?access_token=...` |
| `APPROVER_USER` | 普通 | 生产发布审批人 | 云效用户名 |

### 第三步：创建流水线 1 — 主线构建部署

1. 云效 Flow → 「新建流水线」→ 选择「YAML 模式」
2. 将 `yunxiao/flow-main-pipeline.yml` 内容粘贴
3. 配置代码源：选择 GitHub 服务连接 → `rickmodel/dub-demo` → `main` 分支
4. 开启代码源触发：
   - 勾选 **Push** 事件
   - 分支过滤：`main`
5. 保存并运行测试

验证要点：

- 质量检查阶段应正常通过（continue-on-error 兜底遗留问题）
- Docker 构建阶段：首次可用 echo 占位（未配置 ACR 凭证时）
- Release Notes 阶段：需要 QODER_API_KEY 已配置
- 钉钉通知：需要 DINGTALK_WEBHOOK 已配置

### 第四步：创建流水线 2 — MR/PR AI Code Review

1. 云效 Flow → 「新建流水线」→ 选择「YAML 模式」
2. 将 `yunxiao/flow-mr-review.yml` 内容粘贴
3. 配置代码源：同上
4. 开启代码源触发：
   - 勾选 **MR 新建** 和 **MR 更新** 事件
5. 保存

验证方式：

- 在 GitHub 上创建一个测试 PR（例如修改 README）
- GitHub Webhook 会触发云效流水线
- 查看流水线日志中 QoderCLI 的 Review 报告输出
- 审查报告会作为流水线制品（artifact）保存

### 第五步：创建流水线 3 — Issue 自动修复

1. 云效 Flow → 「新建流水线」→ 选择「YAML 模式」
2. 将 `yunxiao/flow-issue-fix.yml` 内容粘贴
3. 配置代码源：同上
4. 触发方式选择：
   - **方式 A（推荐）**：开启 Webhook 触发。复制 Webhook URL，配置到 GitHub Issues 的 Webhook 或云效 Projex 的通知规则
   - **方式 B**：手动运行。在流水线页面点「运行」并填写 ISSUE_NUMBER、ISSUE_TITLE 参数

验证方式：

- 手动运行流水线，填入 Issue #1 的信息
- 观察 QoderCLI 分析 Issue → 定位代码 → 修复 → 创建 PR 的全过程
- 检查自动创建的 PR 内容和质量

### 第六步：配置钉钉群通知（可选）

1. 钉钉群 → 群设置 → 智能群助手 → 添加机器人
2. 选择「自定义（通过 Webhook 接入）」
3. 复制 Webhook URL
4. 粘贴到云效变量管理的 `DINGTALK_WEBHOOK` 中
5. 主线流水线部署成功后会自动发送钉钉通知

### 第七步：（可选）导入代码到云效 Codeup

如果客户要求代码也在阿里云体系内，可以将 GitHub 仓库导入 Codeup：

1. 云效 Codeup → 「导入仓库」→ 选择「从 GitHub 导入」
2. 授权并选择 `rickmodel/dub-demo`
3. 开启「自动同步」保持与 GitHub 双向同步
4. 修改 3 条流水线的 `sources.type` 为 `codeup`，更新 `endpoint`

导入 Codeup 后，MR 触发和代码推送触发会更加原生和稳定，无需依赖 GitHub Webhook。

## 安全对比

| 安全维度 | GitHub Actions 方案 | 云效 Flow 方案 |
|---------|--------------------|--------------| 
| API Key 存储位置 | GitHub Secrets（❌公网平台） | 云效变量管理（✅阿里云内网） |
| 执行环境 | GitHub 云端 Runner / Self-hosted | 阿里云构建集群（China Aliyun Linux） |
| 网络边界 | Key 在 GitHub 基础设施内传递 | Key 仅在阿里云内网传递 |
| 合规性 | 数据出境风险 | 符合中国数据驻留要求 |
| 日志审计 | GitHub Actions logs | 云效流水线日志 + 阿里云 ActionTrail |
| 访问控制 | GitHub Org/Repo 权限 | RAM 权限 + 云效权限体系 |

## 三条流水线文件

| 文件 | 用途 | 触发条件 |
|-----|------|---------|
| `yunxiao/flow-main-pipeline.yml` | 主线构建部署 | Push to main |
| `yunxiao/flow-mr-review.yml` | MR/PR AI Code Review | MR 新建/更新 |
| `yunxiao/flow-issue-fix.yml` | Issue 自动修复 | Webhook / 手动运行 |

## 常见问题

**Q: 云效 Flow 能直接用 GitHub 仓库吗？**

可以。通过「服务连接」绑定 GitHub 账号后，云效 Flow 可以直接拉取 GitHub 代码。代码源触发需要在 GitHub 仓库中配置 Webhook（云效会自动配置）。如果追求更好的体验，建议导入到 Codeup。

**Q: QoderCLI 在云效构建环境中能正常运行吗？**

能。云效 China Aliyun Linux 3 构建环境支持自定义安装命令。通过 fnm 安装 Node.js 20 后，使用 npm 安装 QoderCLI 即可。QODER_API_KEY 通过 envs 注入，安全性由云效变量管理保证。

**Q: Issue 自动修复后如何通知审核人？**

Issue 修复流水线完成后会自动发送钉钉通知。同时 QoderCLI 创建的 PR 会出现在 GitHub 中，审核人会收到 GitHub 的邮件通知。可以进一步配置 QoderWork 通过钉钉 IM 提醒审核人。

**Q: 如何回退到 GitHub Actions？**

两套方案可以并行。GitHub Actions workflow（`.github/workflows/qoder-ci-cd.yml`）仍在仓库中，只是 QoderCLI 步骤用 echo 占位。如果需要切回 GitHub Actions + Self-hosted Runner 方案，取消注释即可。
