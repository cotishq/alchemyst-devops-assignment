# Distributed Inference System — DevOps Assignment

A production-grade deployment of a distributed SLM (Small Language Model) inference system across multiple AWS EC2 instances in a private subnet. The system runs **Gemma 3 270M** (GGUF, CPU-quantized) behind a worker mesh orchestrated by the [iii framework](https://iii.dev), exposed as a JSON HTTP API through an nginx reverse proxy — all reproducible via Terraform.

---

## Architecture

![Architecture Diagram](image.png)

### Component Overview

| Component | VM | Subnet | Language | Function |
|---|---|---|---|---|
| **nginx** | vm-gateway | Public | — | Reverse proxy, forwards port 80 → iii HTTP |
| **iii Engine** | vm-gateway | Public | Rust binary | Orchestrates workers, WebSocket RPC bus, HTTP API |
| **Caller Worker** | vm-gateway | Public | TypeScript | Registers `inference::get_response`, triggers inference via RPC |
| **Inference Worker** | vm-inference | Private | Python | Loads Gemma 270M, registers `inference::run_inference` |

### Network Design

All VMs live inside a dedicated VPC (`10.0.0.0/16`) in `ap-south-1` (Mumbai):

- **vm-gateway** (t3.micro, public subnet `10.0.1.0/24`) — the only machine reachable from the internet. Accepts HTTP on port 80 and serves as the RPC engine on port 49134.
- **vm-inference** (t3.small, private subnet `10.0.2.0/24`) — no public IP, not reachable from the internet. Only reachable from within the VPC via the gateway.
- **NAT Gateway** — allows the private subnet to reach the internet outbound (for Docker pulls, model downloads) while blocking all unsolicited inbound traffic.
- **SSH access** — vm-gateway is accessible directly; vm-inference is only accessible by jumping through vm-gateway (bastion pattern).

### RPC Flow

```
curl POST /v1/chat/completions  (internet)
  → nginx :80                   (vm-gateway, public)
  → iii engine :3111            (vm-gateway, internal)
  → caller-worker               (TypeScript, Docker container)
    → iii.trigger("inference::run_inference")
      → WebSocket RPC ws://10.0.1.251:49134
        → inference-worker      (Python, vm-inference, PRIVATE)
          → Gemma 3 270M GGUF   (CPU inference)
      → result bubbles back
  → JSON response to client
```

---

## API

### Run Inference

```bash
curl -X POST http://13.127.179.207/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Explain quantum entanglement in simple terms."}
    ]
  }'
```

**Response:**

```json
{
  "result": {
    "response": "Quantum entanglement is a phenomenon where two particles become linked...",
    "success": "You've connected two workers and they're interoperating seamlessly..."
  }
}
```

### Request Schema

| Field | Type | Required | Description |
|---|---|---|---|
| `messages` | Array | Yes | Chat messages in OpenAI-compatible format |
| `messages[].role` | String | Yes | `"user"`, `"assistant"`, or `"system"` |
| `messages[].content` | String | Yes | Message content |

---

## Repository Structure

```
.
├── architecture.png             # Architecture diagram
├── quickstart/
│   ├── config.yaml              # iii engine configuration
│   └── workers/
│       ├── caller-worker/       # TypeScript — routes HTTP → RPC
│       │   └── src/worker.ts
│       └── inference-worker/    # Python — runs Gemma 3 270M
│           ├── inference_worker.py
│           └── requirements.txt
├── docker/
│   ├── engine/
│   │   └── Dockerfile           # iii engine container
│   ├── caller-worker/
│   │   └── Dockerfile           # Bun + TypeScript container
│   └── inference-worker/
│       └── Dockerfile           # Python 3.11 + CPU torch + Gemma model
├── terraform/
│   ├── main.tf                  # Provider, VPC, subnets, IGW, NAT, route tables
│   ├── variables.tf             # Configurable inputs
│   ├── security_groups.tf       # Firewall rules (gateway public, inference private)
│   ├── ec2.tf                   # 2 EC2 instances with user-data bootstrap
│   ├── outputs.tf               # Public IPs, SSH commands, API endpoint
│   └── terraform.tfvars         # Your values (gitignored)
├── scripts/
│   ├── gateway-init.sh          # Bootstrap: installs Docker, pulls images, starts containers
│   ├── inference-init.sh        # Bootstrap: installs Docker, pulls inference image
│   └── start-inference.sh       # Post-deploy: patches III_URL and starts inference worker
└── nginx/
    └── alchemyst.conf           # nginx reverse proxy config
```

---

## Docker Images

All services are containerized and hosted on Docker Hub under [`cotishq`](https://hub.docker.com/u/cotishq):

| Image | Contents |
|---|---|
| `cotishq/alchemyst-engine` | iii engine binary + config.yaml |
| `cotishq/alchemyst-caller` | Bun + TypeScript caller-worker |
| `cotishq/alchemyst-inference` | Python 3.11 + CPU PyTorch + Gemma 3 270M GGUF |

---

## Deploy from Scratch

### Prerequisites

- AWS CLI configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- Docker (for rebuilding images locally if needed)
- An EC2 key pair in `ap-south-1`

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/cotishq/alchemyst-devops-assignment.git
cd alchemyst-devops-assignment

# 2. Create terraform.tfvars
cat > terraform/terraform.tfvars << EOF
aws_region = "ap-south-1"
key_name   = "your-ec2-keypair"
your_ip    = "$(curl -s https://checkip.amazonaws.com)/32"
EOF

# 3. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 4. Note the outputs
# gateway_public_ip, gateway_private_ip, inference_private_ip

# 5. Wait ~3 minutes for bootstrap scripts to complete
# Then SSH into gateway and start containers
ssh -i ~/.ssh/your-key.pem ec2-user@<GATEWAY_PUBLIC_IP>
sudo -i
cd /opt/alchemyst
docker compose up -d

# 6. SSH into inference VM via gateway and start inference container
ssh -i ~/.ssh/your-key.pem ec2-user@<GATEWAY_PUBLIC_IP>
ssh -i ~/.ssh/your-key.pem ec2-user@<INFERENCE_PRIVATE_IP>
sudo -i
cd /opt/alchemyst
# Edit docker-compose.yml: set III_URL=ws://<GATEWAY_PRIVATE_IP>:49134
docker compose up -d

# 7. Test
curl -X POST http://<GATEWAY_PUBLIC_IP>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"What is 2+2?"}]}'
```

### What Terraform Creates

| Resource | Count | Purpose |
|---|---|---|
| VPC | 1 | Isolated network `10.0.0.0/16` |
| Public Subnet | 1 | Hosts vm-gateway `10.0.1.0/24` |
| Private Subnet | 1 | Hosts vm-inference `10.0.2.0/24` |
| Internet Gateway | 1 | Public subnet → internet |
| NAT Gateway | 1 | Private subnet → internet (outbound only) |
| Security Groups | 2 | Gateway (public 80/22) + Inference (private 49134 only) |
| EC2 Instances | 2 | vm-gateway (t3.micro) + vm-inference (t3.small) |
| Elastic IP | 1 | Static IP for NAT Gateway |

### Tear Down

```bash
cd terraform
terraform destroy
```

---

## Production Hardening

Things I would do before putting this in production:

- **HTTPS** — Put an ACM certificate behind an ALB or use Caddy for automatic Let's Encrypt. All traffic is currently plain HTTP.
- **Authentication** — Add API key or JWT validation on the nginx layer. The endpoint is currently open to anyone.
- **Secrets management** — Move `III_URL` and any API tokens to AWS Secrets Manager or SSM Parameter Store instead of environment variables in docker-compose files.
- **Observability** — Ship container logs to CloudWatch via Fluent Bit; add Prometheus + Grafana dashboards for request latency and error rates (iii already exposes OpenTelemetry traces).
- **SSH hardening** — Replace direct SSH access with AWS SSM Session Manager — no open port 22 at all.
- **Instance resilience** — Wrap EC2 instances in Auto Scaling Groups (min=1) so failed instances are automatically replaced.
- **Input validation** — Add a schema validation layer on nginx/API gateway to reject malformed payloads before they reach workers.

---

## Scaling to 100x Larger Model (~27B parameters)

- **GPU instances** — Move inference-worker to `g4dn.xlarge` (T4, 16GB VRAM) or `g5.xlarge` (A10G, 24GB VRAM). A 27B model in Q4 quantization fits in ~16GB VRAM.
- **Model storage** — Store the GGUF file on EFS or S3 and mount it at runtime instead of baking a 30GB+ Docker image. Boot time drops from minutes to seconds.
- **Inference server** — Replace raw `transformers` with `llama.cpp` HTTP server or `vLLM` for batching, KV-cache reuse, and continuous batching — 10–50x higher throughput.
- **Request queuing** — Add SQS between caller-worker and inference-worker. Inference at this scale takes 5–30 seconds; a queue decouples the API tier and prevents timeouts.
- **Autoscaling** — Auto Scaling Group on inference VMs triggered by SQS queue depth via CloudWatch. Scale in/out based on demand.
- **Multi-AZ** — Spread inference VMs across two availability zones for resilience.
- **Spot Instances** — Use EC2 Spot for inference VMs to cut compute cost by 60–90%.
