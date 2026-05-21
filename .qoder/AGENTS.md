# AGENTS.md — Dub Demo 项目 QoderCLI 工作手册
# 适用于 Qoder Desktop IDE 和 QoderCLI
# 代码托管: 云效 Codeup
# CI/CD: 云效 Flow
# 项目管理: 云效 Projex

# 项目概述

Dub 是一个开源链接管理平台（短链服务），基于 Next.js 14 + TypeScript 全栈构建。
本仓库为 Qoder 产品家族全流程 DevOps 集成演示项目。

## 技术栈

- **框架**: Next.js 14+ (App Router) + Turbo monorepo
- **语言**: TypeScript (严格模式)
- **ORM**: Prisma (MySQL)
- **样式**: Tailwind CSS
- **校验**: Zod
- **测试**: Vitest (单元) + Playwright (E2E)
- **包管理**: pnpm 9+
- **构建**: Turborepo

## 研发平台

- **代码托管**: 云效 Codeup
- **CI/CD**: 云效 Flow
- **项目管理**: 云效 Projex（工作项、迭代、看板）
- **制品管理**: 阿里云 ACR（容器镜像）
- **部署**: 阿里云 ECS + Docker Compose
- **通知**: 钉钉群机器人

## 目录结构

```
dub-demo/
├── apps/web/              # Next.js 主应用
│   ├── app/               # App Router (页面 + API Routes)
│   ├── lib/               # 核心业务逻辑
│   ├── ui/                # UI 组件
│   └── tests/             # Vitest 测试
├── packages/
│   ├── prisma/            # Prisma Schema + Migrations
│   ├── ui/                # 共享 UI 组件库
│   ├── utils/             # 工具函数库
│   ├── cli/               # Dub CLI
│   └── tailwind-config/   # Tailwind 共享配置
├── yunxiao/               # 云效 Flow 流水线配置 (3条)
├── .qoder/                # QoderCLI 配置 (本文件)
├── deploy/                # Docker 部署配置
└── docs/                  # 项目文档
```

# 编码规范

## TypeScript
- 启用 strict mode，**禁止使用 `any` 类型**
- 优先使用 `interface` 定义对象类型
- 函数返回值必须显式标注

## React / Next.js
- 组件使用函数式写法 + Hooks
- Server Components 优先，仅必要时 "use client"
- API Routes 使用 Zod 入参校验
- 样式使用 Tailwind CSS，禁止内联 style

## 数据库
- 所有操作通过 Prisma Client
- **禁止 `$queryRaw` 拼接 SQL**
- 字段变更必须写 migration 描述

## 提交规范
```
type(scope): description

type: feat / fix / docs / style / refactor / test / chore
scope: web / ui / utils / prisma / ci / docker
```

## 分支规范
```
feat/projex-{工作项ID}     # 需求开发
fix/projex-{工作项ID}      # 缺陷修复
chore/projex-{工作项ID}    # 杂项
```

MR 标题格式: `type: 描述 (Projex#{工作项ID})`

# 自治边界

## ✅ 可自主执行（无需人工确认）
- **格式修复**: `pnpm run format` / `pnpm lint --fix`
- **简单 Bug 修复**: 不涉及架构变更
- **测试用例补充**: 为已有功能添加测试
- **文档更新**: README、注释、JSDoc
- **依赖 patch/minor 升级**
- **TypeScript 类型修复**

## ⚠️ 需人工审核
- **Prisma Schema/Migration 修改**
- **API 接口签名变更**
- **删除文件或目录**
- **依赖 major 版本升级**
- **安全/认证/支付相关改动**
- **环境变量改动**

## 🚫 禁止执行
- 直接修改生产数据库
- 提交密钥/密码/Token
- 修改 CI/CD 管线配置（云效 Flow YAML）
- 降低测试覆盖率

# 常用命令

```bash
pnpm install              # 安装依赖
pnpm dev                  # 开发服务器 (port 8888)
pnpm build                # 生产构建 (turbo)
pnpm lint                 # ESLint
pnpm run format           # Prettier 格式化
pnpm run prettier-check   # Prettier 检查
pnpm test                 # Vitest 单元测试
```

# 云效 Flow 流水线

本项目在云效 Flow 中配置 3 条流水线:

| 流水线 | 配置文件 | 触发条件 |
|--------|---------|---------|
| 主线构建部署 | `yunxiao/flow-main-pipeline.yml` | Push to main |
| MR AI Code Review | `yunxiao/flow-mr-review.yml` | MR 新建/更新 |
| 工作项自动修复 | `yunxiao/flow-issue-fix.yml` | Projex Webhook / 手动 |

所有 QoderCLI 操作在云效 Flow 构建集群（China Aliyun Linux 3）内执行，
QODER_API_KEY 存储在云效变量管理（加密），不经过任何公网第三方平台。
