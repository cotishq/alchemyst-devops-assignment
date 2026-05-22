FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y curl ca-certificates jq && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app
COPY quickstart/config.yaml .
COPY quickstart/workers/caller-worker ./workers/caller-worker

RUN mkdir -p data

EXPOSE 49134 3111

CMD ["iii", "--config", "config.yaml"]
