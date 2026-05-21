# Dub Demo — 阿里云云效全链路实施指南

## 架构总览

整个研发流程完全运行在阿里云生态内，代码托管使用云效 Codeup，CI/CD 使用云效 Flow，项目管理使用云效 Projex，通知使用钉钉。QoderCLI API Key 存储在云效变量管理中（加密），全链路在阿里云内网闭环执行。

```
 开发者                          阿里云 · 云效 (全链路内网)
┌─────────────┐                ┌────────────────────────────────────────┐
│ Qoder IDE   │   git push     │  Codeup (代码托管)                     │
│ 本地开发     │ ────────────→ │    ↓ 代码源触发                        │
└─────────────┘                │                                        │
                               │  ┌──────────────────────────────────┐  │
                               │  │ Flow 流水线 1: 主线构建部署        │  │
     钉钉 IM                   │  │  质量检查 → Docker/ACR → ECS部署  │  │
┌─────────────┐                │  │  → QoderCLI Release Notes → 钉钉 │  │
│ QoderWork   │ ←── 钉钉通知 ──│  └──────────────────────────────────┘  │
│ 桌面智能体   │                │                                        │
└─────────────┘                │  ┌──────────────────────────────────┐  │
                               │  │ Flow 流水线 2: MR AI Code Review  │  │
                               │  │  质量检查 → QoderCLI Review       │  │
┌─────────────┐                │  │  → 自动修复 → 审查通知           │  │
│ Projex      │                │  └──────────────────────────────────┘  │
│ 项目管理     │ ── Webhook ──→│                                        │
│ (工作项)     │                │  ┌──────────────────────────────────┐  │
└─────────────┘                │  │ Flow 流水线 3: 工作项自动修复     │  │
                               │  │  QoderCLI Fix → 创建 MR → 钉钉   │  │
                               │  └──────────────────────────────────┘  │
                               │                                        │
                               │  🔐 QODER_API_KEY (云效加密变量)       │
                               │     全链路阿里云内网，零公网暴露        │
                               └────────────────────────────────────────┘

                               ┌────────────────────────────────────────┐
                               │  阿里云基础设施                         │
                               │  • ACR (容器镜像仓库)                   │
                               │  • ECS × 2 (Staging + Production)      │
                               │  • RDS MySQL                           │
                               │  • Redis                               │
                               └────────────────────────────────────────┘
```

## 云效三件套一体化

| 产品 | 职责 | 本项目用法 |
|------|------|----------|
| **Codeup** | 代码托管 + MR + 代码评审 | Dub 源码仓库，MR 触发 AI Review |
| **Flow** | CI/CD 流水线 | 3 条流水线：构建部署 / MR审查 / 自动修复 |
| **Projex** | 项目管理 + 需求 + 缺陷 | 工作项 → Webhook 触发自动修复流水线 |

## 实施步骤

### 第一步：导入代码到 Codeup

1. 登录 [云效 Codeup](https://codeup.aliyun.com)
2. 创建代码组：「dub」
3. 导入仓库：选择「从 URL 导入」
   - 填入 Dub 源码地址（或直接新建空仓库推送代码）
   - 仓库名: `dub-demo`
4. 导入完成后，确认代码结构正确
5. 在仓库设置中开启「合并请求」和「代码评审」功能

### 第二步：创建 Projex 项目

1. 进入 [云效 Projex](https://projex.aliyun.com)
2. 新建项目：「Dub Link Management」
3. 选择项目模板：敏捷/Scrum
4. 配置工作项类型：需求、缺陷、任务
5. 关联 Codeup 代码库：`dub/dub-demo`
6. 创建自定义标签：`qoder-autofix`（用于标记需要自动修复的工作项）

### 第三步：配置云效变量管理

在云效 Flow 的「组织设置 → 变量管理」中添加以下变量：

| 变量名 | 类型 | 说明 |
|--------|------|------|
| `QODER_API_KEY` | 加密 | QoderCLI API Key |
| `ACR_NAMESPACE` | 普通 | ACR 命名空间 (如 `dub-demo`) |
| `ACR_USERNAME` | 加密 | ACR 登录用户名 |
| `ACR_PASSWORD` | 加密 | ACR 登录密码 |
| `STAGING_ECS_ID` | 普通 | Staging ECS 实例 ID |
| `PROD_ECS_ID` | 普通 | Production ECS 实例 ID |
| `STAGING_URL` | 普通 | Staging 环境 URL |
| `APP_URL` | 普通 | 应用公网 URL |
| `DINGTALK_WEBHOOK` | 加密 | 钉钉群机器人 Webhook |
| `APPROVER_USER` | 普通 | 生产发布审批人（云效用户名） |
| `CODEUP_TOKEN` | 加密 | Codeup Personal Access Token（MR 创建用） |
| `CODEUP_PROJECT_ID` | 普通 | Codeup 项目数字 ID |
| `ORG_ID` | 普通 | 云效组织 ID |

### 第四步：创建流水线 1 — 主线构建部署

1. 云效 Flow → 「新建流水线」→「YAML 模式」
2. 粘贴 `yunxiao/flow-main-pipeline.yml` 内容
3. 关联代码源：选择 Codeup → `dub/dub-demo` → `main` 分支
4. 开启代码源触发：
   - 勾选 **Push** 事件
   - 分支过滤：`main`
5. 保存并手动运行一次验证

验证要点：
- 代码质量检查：应正常通过（continue-on-error 兜底遗留问题）
- Docker 构建：确认 ACR 凭证正确，镜像成功推送
- ECS 部署：确认 ECS 实例可达，健康检查通过
- QoderCLI：确认 API Key 有效，Release Notes 正常生成
- 钉钉通知：确认 Webhook 配置正确

### 第五步：创建流水线 2 — MR AI Code Review

1. 云效 Flow → 「新建流水线」→「YAML 模式」
2. 粘贴 `yunxiao/flow-mr-review.yml` 内容
3. 关联代码源：选择 Codeup → `dub/dub-demo`
4. 开启代码源触发：
   - 勾选 **MR 新建** 和 **MR 更新** 事件
5. 保存

验证方式：
- 在 Codeup 创建一个测试 MR（例如新建 feature 分支修改 README）
- MR 创建后自动触发流水线
- 查看流水线日志中 QoderCLI 的 AI 审查报告
- 审查报告作为流水线制品（artifact）保存
- 开发者通过钉钉收到审查完成通知

### 第六步：创建流水线 3 — 工作项自动修复

1. 云效 Flow → 「新建流水线」→「YAML 模式」
2. 粘贴 `yunxiao/flow-issue-fix.yml` 内容
3. 关联代码源：选择 Codeup → `dub/dub-demo`
4. 获取流水线 Webhook URL（触发设置 → Webhook 触发 → 复制 URL）
5. 在 Projex 中配置自动化规则：
   - 触发条件：工作项标签变更为 `qoder-autofix`
   - 动作：调用 Webhook URL，传递工作项 ID、标题、描述

验证方式：
- 在 Projex 创建一个缺陷工作项，描述一个简单 Bug
- 给工作项添加 `qoder-autofix` 标签
- 观察 Flow 流水线自动触发
- QoderCLI 分析工作项 → 定位代码 → 实现修复 → 创建 MR
- 在 Codeup 中检查自动创建的 MR 质量
- 钉钉群收到修复完成通知

### 第七步：配置钉钉群通知

1. 创建钉钉群（或使用已有研发群）
2. 群设置 → 智能群助手 → 添加机器人
3. 选择「自定义（通过 Webhook 接入）」
4. 安全设置选择「关键字」模式，关键字填 `Dub`
5. 复制 Webhook URL → 粘贴到云效变量管理 `DINGTALK_WEBHOOK`

通知场景：
- 主线部署成功 → 群内推送版本发布消息
- MR Review 完成 → 通知提交者查看审查报告
- 工作项自动修复 → 通知审核人 Review MR

### 第八步：（可选）配置 QoderWork 钉钉 IM 调度

QoderWork 可绑定钉钉 IM，实现远程指令触发：

| IM 指令 | 效果 |
|---------|------|
| `@Qoder 检查 Staging 状态` | QoderWork 执行健康检查并返回结果 |
| `@Qoder 最近有什么 Bug` | 查询 Projex 近期缺陷列表 |
| `@Qoder 生成周报` | QoderCLI 生成本周代码变更汇总 |
| `@Qoder 发布 v1.2.0` | 触发主线流水线 + 打 Tag |

Cron 任务配置：
- 每日 9:00 — 发送日报（昨日提交、MR、流水线状态）
- 每周一 10:00 — 发送周报（本周效率指标）
- 每周三 2:00 — 安全扫描（依赖漏洞检查）

## Qoder 产品家族分工

| 产品 | 角色 | 在本项目中的职责 |
|------|------|----------------|
| **Qoder IDE** | 开发者主力工具 | Quest 独立视窗 + 5大 Expert 角色，处理复杂编码任务 |
| **QoderCLI** | 无人流水线引擎 | 嵌入云效 Flow，执行 Code Review / Issue修复 / Release Notes |
| **QoderWork** | 桌面智能体 | 钉钉 IM 调度 + Cron 战报 + 桌面事务自动化 |
| **QoderWake** | 7×24 数字员工 | 运维值班（监控告警 → 自动修复）+ Issue 处理员 |

## 安全架构

| 维度 | 保障措施 |
|------|---------|
| API Key 存储 | 云效变量管理（加密），仅在 Flow 运行时注入 |
| 执行环境 | China Aliyun Linux 3 构建集群，阿里云内网 |
| 网络边界 | Key 不经过任何公网平台，无数据出境风险 |
| 合规性 | 符合中国数据安全法、网络安全法数据驻留要求 |
| 审计 | 云效操作日志 + 阿里云 ActionTrail |
| 访问控制 | RAM 权限体系 + 云效组织权限 |
| 代码保护 | Codeup 内置代码扫描、敏感信息检测 |

## 配置文件清单

| 文件路径 | 用途 |
|---------|------|
| `yunxiao/flow-main-pipeline.yml` | 主线构建部署流水线 (Push → ACR → ECS → Release Notes → 钉钉) |
| `yunxiao/flow-mr-review.yml` | MR AI Code Review 流水线 (MR → QoderCLI Review → 自动修复) |
| `yunxiao/flow-issue-fix.yml` | 工作项自动修复流水线 (Projex → QoderCLI Fix → 创建 MR) |
| `.qoder/AGENTS.md` | QoderCLI 工作手册（编码规范 + 自治边界） |
| `deploy/Dockerfile` | 多阶段 Docker 构建（4-stage: base→deps→builder→runner） |
| `deploy/docker-compose.yml` | ECS 部署编排（web + nginx + certbot） |
| `.prettierignore` | 格式检查排除规则 |

## 完整研发流程演示

一个 Bug 从发现到修复上线的全自动流程：

```
1. [Projex] 创建缺陷工作项，标记 qoder-autofix    (人工, 30秒)
         ↓ Webhook 触发
2. [Flow]  自动修复流水线启动                       (自动)
3. [CLI]   QoderCLI 分析缺陷 → 定位代码 → 修复     (自动, ~5分钟)
4. [Codeup] 自动创建修复分支 + MR                   (自动)
         ↓ MR 创建触发
5. [Flow]  Code Review 流水线启动                    (自动)
6. [CLI]   QoderCLI AI 审查修复代码                  (自动, ~3分钟)
7. [钉钉]  通知审核人 Review MR                      (自动)
8. [人工]  审核人在 Codeup 上 Review + 合并 MR       (人工, ~5分钟)
         ↓ 合并触发 Push to main
9. [Flow]  主线构建部署流水线启动                    (自动)
10. [ACR]  Docker 镜像构建推送                       (自动, ~3分钟)
11. [ECS]  自动部署 Staging + 冒烟测试               (自动, ~2分钟)
12. [人工] 审批发布到 Production                     (人工, 30秒)
13. [ECS]  Production 滚动部署 + 健康检查            (自动, ~2分钟)
14. [CLI]  QoderCLI 生成 Release Notes               (自动, ~2分钟)
15. [钉钉] 群内推送发布通知                          (自动)
```

总耗时 ~22分钟，其中人工仅参与 3 步（约 6 分钟）。

## 常见问题

**Q: 云效 Flow YAML 和本地文件的关系？**

`yunxiao/` 目录下的 YAML 文件是参考配置。实际使用时，将内容粘贴到云效 Flow 的 YAML 编辑器中。云效目前不支持从仓库文件自动加载流水线配置（不同于 GitHub Actions 的 `.github/workflows/` 机制），流水线定义存储在云效平台侧。

**Q: QoderCLI 在云效构建环境中能正常运行吗？**

能。China Aliyun Linux 3 构建环境支持自定义安装命令。通过 fnm 安装 Node.js 20 后，使用 npm 安装 QoderCLI 即可。QODER_API_KEY 通过 envs 注入，安全性由云效变量管理保证。

**Q: Projex 工作项如何自动触发修复流水线？**

在 Projex「项目设置 → 自动化」中配置规则：当工作项标签变更包含 `qoder-autofix` 时，调用流水线 Webhook URL。Webhook payload 中传递工作项 ID、标题、描述等字段。

**Q: MR 审查结果如何回写到 Codeup？**

当前方案是将审查报告输出到流水线日志和制品中，同时通过钉钉通知开发者。如需回写 MR 评论，可通过 Codeup Open API（使用 CODEUP_TOKEN）将审查内容作为评论发布到对应 MR。

**Q: 如何处理大型代码变更的 Review？**

QoderCLI 的 `--allowedTools` 参数限制了可用工具范围（只读操作），timeout 设置为 600 秒。对于超大 MR（>50 文件），建议拆分为更小的 MR 以获得更精准的审查结果。

**Q: 生产部署回滚机制？**

主线流水线中的 Production 部署步骤内置了回滚逻辑：部署前备份当前镜像为 `:rollback` 标签，60 秒内健康检查不通过则自动回滚到备份版本。
