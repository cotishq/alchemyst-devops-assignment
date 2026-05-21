#!/bin/bash
set -euo pipefail

GATEWAY_PUBLIC_IP="$1"
GATEWAY_PRIVATE_IP="$2"
INFERENCE_PRIVATE_IP="$3"
KEY_PATH="$HOME/.ssh/alchemyst-key.pem"

echo "==> Patching III_URL on inference VM to ws://$GATEWAY_PRIVATE_IP:49134"

ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ProxyJump="ec2-user@$GATEWAY_PUBLIC_IP" \
    "ec2-user@$INFERENCE_PRIVATE_IP" \
    "sudo sed -i 's|GATEWAY_PRIVATE_IP_PLACEHOLDER|$GATEWAY_PRIVATE_IP|g' /etc/iii-inference.env && \
     sudo systemctl daemon-reload && \
     sudo systemctl start iii-inference && \
     echo 'Inference worker started'"

echo ""
echo "==> Test with:"
echo "curl -X POST http://$GATEWAY_PUBLIC_IP/inference/get-response \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"messages\": [{\"role\": \"user\", \"content\": \"What is 2+2?\"}]}'"
