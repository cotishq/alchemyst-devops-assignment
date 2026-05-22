FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl ca-certificates jq && rm -rf /var/lib/apt/lists/*

# Install iii CLI
RUN curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install iii Python SDK via pip (correct package name is iii-sdk)
RUN pip install --no-cache-dir iii-sdk

# CPU-only torch
RUN pip install --no-cache-dir \
    torch --index-url https://download.pytorch.org/whl/cpu

# Other deps
RUN pip install --no-cache-dir \
    transformers \
    accelerate \
    watchfiles \
    gguf

# Pre-download Gemma model
RUN python3 -c "\
from transformers import AutoModelForCausalLM, AutoTokenizer; \
model_id = 'ggml-org/gemma-3-270m-GGUF'; \
gguf_file = 'gemma-3-270m-Q8_0.gguf'; \
tokenizer = AutoTokenizer.from_pretrained(model_id, gguf_file=gguf_file); \
model = AutoModelForCausalLM.from_pretrained(model_id, gguf_file=gguf_file); \
print('Model ready')"

COPY quickstart/workers/inference-worker/ .

ENV III_URL=ws://10.0.1.251:49134

CMD ["python3", "inference_worker.py"]
