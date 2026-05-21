# ═══════════════════════════════════════════════════════════════
# Dockerfile — Dub Demo 多阶段构建
# 用于阿里云 ECS 容器化部署
# ═══════════════════════════════════════════════════════════════

# Stage 1: 基础镜像
FROM node:20-alpine AS base
RUN corepack enable && corepack prepare pnpm@9 --activate
WORKDIR /app

# Stage 2: 安装依赖
FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/web/package.json ./apps/web/
COPY packages/prisma/package.json ./packages/prisma/
COPY packages/ui/package.json ./packages/ui/
COPY packages/utils/package.json ./packages/utils/
COPY packages/tailwind-config/package.json ./packages/tailwind-config/
COPY packages/tsconfig/package.json ./packages/tsconfig/
COPY packages/embeds/package.json ./packages/embeds/ 2>/dev/null || true
RUN pnpm install --frozen-lockfile

# Stage 3: 构建
FROM base AS builder
COPY --from=deps /app/ ./
COPY . .
RUN pnpm prisma generate --filter=@dub/prisma 2>/dev/null || true
ARG NEXT_PUBLIC_APP_URL=http://localhost:3000
ENV NEXT_PUBLIC_APP_URL=${NEXT_PUBLIC_APP_URL}
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build --filter=web

# Stage 4: 运行时（最小镜像）
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/apps/web/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget --spider http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]
