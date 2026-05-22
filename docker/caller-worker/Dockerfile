FROM oven/bun:1

WORKDIR /app
COPY quickstart/workers/caller-worker/package.json .
COPY quickstart/workers/caller-worker/bun.lock* .
RUN bun install

COPY quickstart/workers/caller-worker/ .

ENV III_URL=ws://engine:49134

CMD ["bun", "run", "src/worker.ts"]
