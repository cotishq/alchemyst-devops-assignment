import os
from typing import Any, Dict, List
from iii import InitOptions, Logger, register_worker
from transformers import AutoModelForCausalLM, AutoTokenizer

iii = register_worker(
    os.environ.get("III_URL", "ws://localhost:49134"),
    InitOptions(worker_name="inference-worker"),
)
logger = Logger()

model_id = "ggml-org/gemma-3-270m-GGUF"
gguf_file = "gemma-3-270m-Q8_0.gguf"

tokenizer = AutoTokenizer.from_pretrained(model_id, gguf_file=gguf_file)
model = AutoModelForCausalLM.from_pretrained(model_id, gguf_file=gguf_file)

def run_inference_handler(payload: Dict[str, Any]) -> Dict[str, Any]:
    messages = payload.get("messages", [])
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(text, return_tensors="pt").to(model.device)

    output = model.generate(
        **inputs,
        max_new_tokens=100,
        repetition_penalty=1.5,
        do_sample=True,
        temperature=0.7,
    )
    result = tokenizer.decode(output[0][inputs["input_ids"].shape[-1]:], skip_special_tokens=True)
    logger.info(f"Inference result: {result[:100]}...")
    return {"response": result}

iii.register_function("inference::run_inference", run_inference_handler)
logger.info("Inference worker started - listening for calls")
