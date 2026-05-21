# Qoder 产品家族 × Dub 项目 — 最小可执行 Demo

## Demo 目标

通过 Dub（开源链接管理平台）的 **3 个真实研发迭代场景**，现场演示 Qoder 产品家族如何协同工作：

| 场景 | 核心产品 | 一句话效果 |
|------|---------|-----------|
| 场景 1: Bug 自动修复 | **QoderCLI** + 云效Flow | 给缺陷打个标签，22分钟后修复自动上线 |
| 场景 2: 钉钉远程调度 | **QoderWork** + 钉钉 | 在群里@一句话，AI自动执行研发操作 |
| 场景 3: 7×24运维值班 | **QoderWake** + QoderWork | 凌晨3点服务挂了，AI员工5分钟自动恢复 |

当 CLI 遇到处理不了的问题（Prisma Schema变更/安全相关/架构决策），会**主动提醒开发者**通过 Qoder IDE 人工处理。

---

## 前置准备 (一次性, 约30分钟)

### 1. 代码导入 Codeup
```bash
# 本地仓库添加 Codeup 远程
cd dub-demo
git remote add codeup https://codeup.aliyun.com/{ORG_ID}/dub/dub-demo.git
git push codeup main --all
```

### 2. 云效变量配置
在云效 Flow「组织设置 → 变量管理」中添加:
```
QODER_API_KEY    (加密)  → QoderCLI API Key
DINGTALK_WEBHOOK (加密)  → 钉钉群 Webhook
ACR_NAMESPACE    (普通)  → dub-demo
CODEUP_TOKEN     (加密)  → Codeup Personal Access Token
CODEUP_PROJECT_ID(普通)  → Codeup 项目ID
```
> 最小 Demo 只需前2个变量就能跑通场景1和场景2

### 3. 创建3条云效Flow流水线
将 `yunxiao/` 目录下3个YAML粘贴到云效 Flow YAML 编辑器:
- `flow-main-pipeline.yml` → 主线构建部署
- `flow-mr-review.yml` → MR AI Code Review
- `flow-issue-fix.yml` → 工作项自动修复

### 4. Projex 项目配置
- 创建项目，关联 Codeup 代码库
- 添加标签: `qoder-autofix`
- 配置自动化: 标签含 `qoder-autofix` → 调用 Flow Webhook

### 5. QoderWork 绑定钉钉
- QoderWork 设置 → 连接器 → 钉钉 → 扫码

---

## 场景 1: Bug 自动修复

### 故事线

> PM 在 Projex 中报了一个 Bug："短链创建接口缺少 URL 格式校验，用户传入无效 URL 时返回 500 而非友好提示"。打上 `qoder-autofix` 标签后，全程无人值守……

### 触发方式
在云效 Projex 创建缺陷工作项:
```
标题: 短链创建接口缺少URL格式校验
类型: 缺陷
描述: 
  POST /api/links 接口的 url 参数未做格式校验。
  当传入 "not-a-url" 时，Prisma 报错返回 500 Internal Server Error。
  期望: 返回 422 + 错误提示 "无效的URL格式"
  
  复现步骤:
  curl -X POST /api/links -d '{"url": "not-a-url", "domain": "dub.sh"}'
  
  相关文件: apps/web/app/api/links/route.ts
标签: qoder-autofix, bug
```

### 自动执行流程 (约22分钟, 人工仅1步)

```
[00:00] Projex 标签触发 → Flow 流水线 3 启动
        ↓
[00:30] QoderCLI 分析缺陷描述 → 定位 apps/web/app/api/links/route.ts
        ↓
[03:00] QoderCLI 修复:
        - 在 createLinkBodySchema (Zod) 中添加 url: z.string().url() 校验
        - 补充错误处理: 返回 422 { error: "无效的URL格式" }
        - 添加测试: apps/web/tests/links-validation.test.ts
        ↓
[04:00] QoderCLI 运行 pnpm lint + pnpm test 验证通过
        ↓
[04:30] 自动创建分支 fix/projex-{ID} → 推送 → 创建 MR
        ↓  MR创建触发 Flow 流水线 2
[05:00] QoderCLI AI Code Review 审查修复代码
        → 输出: "修复合理，Zod 校验位置正确，测试覆盖充分"
        ↓
[08:00] 钉钉群通知: "MR Review 完成，请审核"
        ↓
[08:30] 👨‍💻 开发者在 Codeup 点击合并 (唯一人工步骤)
        ↓  合并触发 Flow 流水线 1
[09:00] 质量检查 → Docker 构建推送 ACR
        ↓
[15:00] 自动部署 Staging + 健康检查
        ↓
[18:00] QoderCLI 生成 Release Notes
        ↓
[20:00] 钉钉通知: "v42 已发布，修复: 短链创建接口URL格式校验"
```

### 当 CLI 搞不定时 → 提醒开发者用 IDE

如果缺陷涉及以下情况，CLI 会**停下来通知人工处理**:
```
[场景] 工作项描述: "用户链接数据丢失，需要修改 Prisma Schema 添加软删除字段"

[CLI判断] ⚠️ 涉及 Prisma Schema 变更 → 自治边界外
[CLI动作] 钉钉通知:
  "⚠️ Projex#456 无法自动修复
   原因: 涉及数据库 Schema 变更 (添加 deletedAt 字段)
   建议: 请开发者使用 Qoder IDE 处理
   相关文件: packages/prisma/schema.prisma
   操作指引: 
   1. 在 IDE 中打开 Quest → 输入工作项描述
   2. Expert(Schema) 会生成 migration 方案
   3. 人工确认后执行 prisma migrate"
```

### Demo 中的关键观察点 (给客户讲)
- **自动定位**: CLI 通过 AGENTS.md 了解项目结构，精准找到对应文件
- **规范遵守**: 修复代码自动遵循 Zod 校验规范、TypeScript strict 模式
- **自治边界**: 遇到 Schema 变更自动停下来，不会乱改数据库
- **22分钟闭环**: 从报 Bug 到修复上线，人工只需1次点击合并

---

## 场景 2: 钉钉远程调度 (QoderWork)

### 故事线

> 周五下午开会，TL 在手机上打开钉钉，@QoderWork 快速了解项目状态、触发操作。不用打开电脑，全程钉钉群内完成。

### 可演示的真实指令

#### 指令 1: 查项目状态
```
@QoderWork Dub 项目最近一周状态怎么样？
```
QoderWork 响应:
```
📊 Dub 项目周状态 (05/14 - 05/21)

代码活动:
• 新增提交: 23 次 (较上周 +15%)
• MR 合并: 8 个 (平均 Review 时长 4.2h)
• 活跃贡献者: 5 人

工作项进展:
• 新增: 12 个 (需求 5 / 缺陷 6 / 任务 1)
• 关闭: 9 个 (QoderCLI 自动修复 4 个, 占比 44%)
• 待处理积压: 18 个 (高优 3 个)

流水线健康:
• 本周运行: 31 次 (成功率 94%)
• 部署: 5 次 (全部成功)
• 最近一次: 今天 14:30, v41 → Production ✅

高优关注项:
• ⚠️ Projex#301: 批量导入链接性能退化 (P1, 3天未处理)
• ⚠️ Projex#298: OAuth Token 过期未刷新 (P1, 5天)
```

#### 指令 2: 让 CLI 修一个 Bug
```
@QoderWork 把 Projex#301 标记为 qoder-autofix，让 CLI 试试
```
QoderWork 响应:
```
✅ 已给 Projex#301 添加 qoder-autofix 标签
📋 Flow 流水线已触发，预计 5 分钟后开始自动修复
🔔 修复完成后我会通知你 Review
```

#### 指令 3: 查看 CLI 修复结果
```
@QoderWork Projex#301 修好了吗？
```
QoderWork 响应:
```
✅ QoderCLI 已完成修复

修复内容:
• 文件: apps/web/app/api/links/bulk/route.ts
• 原因: 批量导入使用 for 循环逐条 INSERT，改为 Prisma createMany 批量操作
• 测试: 新增 bulk-import-perf.test.ts，验证 1000 条在 3s 内完成

MR 状态: 待审核
👉 点击查看: https://codeup.aliyun.com/.../merge_requests/42

需要我自动合并还是等你 Review？
```

#### 指令 4: 手动触发部署
```
@QoderWork 合并吧，然后部署到 Staging
```

### Cron 自动化任务 (每天自动执行)

| 时间 | 任务 | 输出 |
|------|------|------|
| 每天 9:00 | 研发日报 | 昨日提交/MR/流水线/健康检查 → 钉钉群 |
| 每周一 10:00 | 效能周报 | Issue统计/AI贡献占比/部署频率 → 钉钉群 |
| 每天 2:00 | 安全扫描 | 依赖漏洞/敏感信息检测 → 如有问题推钉钉 |

### Demo 中的关键观察点
- **自然语言操作**: 不需要记命令，说人话就能触发研发操作
- **上下文感知**: QoderWork 知道项目结构、工作项状态、流水线历史
- **IM即工作台**: TL/PM 不需要登录云效控制台，钉钉群内闭环
- **人机协作**: AI 执行 + 人做决策（合并/审核）的最佳配合

---

## 场景 3: 7×24 运维值班 (QoderWake)

### 故事线

> 凌晨 3:17，Dub 的短链跳转服务出现 5xx 错误率飙升。没有人值班，但 QoderWake "运维值班员" 24小时在线……

### 自动响应流程

```
[03:17] 阿里云 SLS 告警: dub-production 5xx_rate > 5% (当前 12%)
        ↓ 告警 Webhook → QoderWake
[03:17] QoderWake 接收告警，开始自诊断:
        • 检查 ECS CPU/内存 → 正常
        • 检查 RDS 连接数 → 正常
        • 检查 Redis → ❌ 连接超时!
        ↓
[03:18] QoderWake 判断: Redis 连接问题
        自动执行修复:
        • SSH 登录 ECS
        • 重启 Redis 服务: docker-compose restart redis
        • 等待 15 秒
        • 验证: curl /api/health → 200 ✅
        ↓
[03:19] 5xx 率回落到 0.3% → 告警自动恢复
        ↓
[03:20] QoderWake → 钉钉群通知:
        "🔧 [自动恢复] 03:17 检测到 5xx 告警
         根因: Redis 连接超时
         处理: 自动重启 Redis 容器
         当前: 服务已恢复正常 (5xx=0.3%)
         建议: 明天排查 Redis 内存是否接近上限"
        ↓
[03:20] QoderWake → 创建 Projex 工作项:
        "Redis 连接超时导致服务中断 (自动恢复)
         优先级: P2 | 标签: ops-followup
         详情: [时间线 + 处理记录 + 根因分析]"
```

### 复杂场景升级 → 通知人工 + IDE

```
[场景] SLS 告警: OOM Killed — apps/web 进程内存超限

[QoderWake 判断] 
  • 重启可临时恢复 → 先重启
  • 但 OOM 是代码级问题 → 需要修复根因
  
[QoderWake 动作]
  1. 重启服务 (立即恢复)
  2. 钉钉通知值班人:
     "⚠️ OOM 已自动重启恢复，但需排查根因
      可能原因: 
      • 批量查询未分页 (apps/web/lib/api/links/get-links.ts:L47)
      • 大结果集全量加载到内存
      建议: 使用 Qoder IDE Quest 分析内存泄漏路径"
  3. 创建 P1 工作项 → 不标记 qoder-autofix (需人工判断)
```

### QoderWake 值班能力矩阵

| 告警类型 | 自动处理 | 升级策略 |
|---------|---------|---------|
| Redis 连接超时 | 重启容器 | 恢复后创建跟踪工作项 |
| 磁盘空间不足 | 清理日志/临时文件 | >90%通知人工扩容 |
| 5xx 率飙升 | 回滚到上一版本 | 回滚后标记最近部署为问题版本 |
| SSL 证书到期 | certbot 自动续期 | 续期失败通知运维 |
| OOM / 进程崩溃 | 重启恢复 | 创建P1工作项+通知人工排查 |
| Prisma 连接池耗尽 | 重启应用 | 建议优化连接池配置 |

### Demo 中的关键观察点
- **即时响应**: 不需要人值班，秒级响应告警
- **智能判断**: 区分"能自动修"和"需要人修"
- **SOP 沉淀**: 每次处理自动形成知识库，越用越聪明
- **人机边界**: 简单问题自己修，复杂问题给出分析+建议后上报

---

## 三场景协作全景图

```
                    Qoder 产品家族研发闭环
                    
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │   ┌─────────┐      ┌──────────┐      ┌─────────────┐   │
  │   │ Projex  │─────→│ QoderCLI │─────→│  Codeup MR  │   │
  │   │ 工作项   │ 触发  │ 自动修复  │ 创建  │  代码审查    │   │
  │   └────┬────┘      └──────────┘      └──────┬──────┘   │
  │        │                                      │          │
  │        │ 打标签                         合并触发│          │
  │        │                                      ▼          │
  │   ┌────┴────┐                         ┌─────────────┐   │
  │   │QoderWork│◄─── 钉钉通知 ───────────│  云效 Flow   │   │
  │   │ 调度中心 │                         │  构建部署    │   │
  │   └────┬────┘                         └──────┬──────┘   │
  │        │                                      │          │
  │   IM指令│ Cron报告                      部署到 │ECS       │
  │        │                                      ▼          │
  │   ┌────┴────┐      ┌──────────┐      ┌─────────────┐   │
  │   │  钉钉   │◄─────│QoderWake │◄─────│ 生产环境    │   │
  │   │  群组   │ 告警  │ 运维值班  │ 监控  │ ECS/ACR     │   │
  │   └─────────┘      └──────────┘      └─────────────┘   │
  │                                                          │
  │   ┌─────────────────────────────────────────────────┐   │
  │   │ 🏗️ Qoder IDE (人工兜底)                         │   │
  │   │ CLI/Wake 处理不了时 → 通知开发者打开 IDE 处理     │   │
  │   │ • Schema 变更  • 架构决策  • 安全相关改动        │   │
  │   └─────────────────────────────────────────────────┘   │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

---

## 效果数据 (Demo 讲解用)

| 指标 | 传统方式 | Qoder 全家桶 | 提升 |
|------|---------|-------------|------|
| Bug 修复周期 | 2-3天 (排期→开发→Review→部署) | 22分钟 (1人1步) | **>100x** |
| 值班响应时间 | 5-15分钟 (人收到告警→登录→排查) | <60秒 (Wake自动) | **>10x** |
| 代码Review等待 | 4-8小时 (等人空闲) | 3分钟 (CLI即时) | **>80x** |
| 运维人力 | 7×24轮值 (3-4人) | QoderWake + 升级通知 | **-75%** |
| TL了解项目状态 | 登录多系统查看 (10-15分钟) | 钉钉@一句话 (10秒) | **>60x** |

---

## 快速搭建清单

### 最小 Demo (30分钟, 只演示场景1)
- [ ] 代码推到 Codeup
- [ ] 云效变量: QODER_API_KEY + DINGTALK_WEBHOOK
- [ ] 粘贴 `flow-issue-fix.yml` + `flow-mr-review.yml` 到 Flow
- [ ] Projex 创建缺陷 + 打 `qoder-autofix` → 看结果

### 标准 Demo (1小时, 场景1+2)
- [ ] 上述全部
- [ ] 粘贴 `flow-main-pipeline.yml` 补齐部署链路
- [ ] QoderWork 绑定钉钉
- [ ] 配置 Cron 日报/周报
- [ ] 演示 IM 指令

### 完整 Demo (半天, 3个场景全部)
- [ ] 上述全部
- [ ] ECS 部署应用 (Docker Compose)
- [ ] 配置 SLS 告警规则 → Webhook
- [ ] QoderWake 部署 + 告警接入
- [ ] 模拟 Redis 故障演示自动恢复
