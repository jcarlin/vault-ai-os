#!/usr/bin/env python3.12
"""
scripts/test-vllm-inference.py
Test vLLM inference performance

Usage:
    python3.12 test-vllm-inference.py                           # Default: facebook/opt-125m
    python3.12 test-vllm-inference.py --model /models/qwen2.5-32b-awq
    python3.12 test-vllm-inference.py --model /models/llama-3.3-8b-q4 --max-tokens 100
"""

import argparse
import time
from vllm import LLM, SamplingParams


def main():
    """Main test function"""

    parser = argparse.ArgumentParser(description="Test vLLM inference performance")
    parser.add_argument(
        "--model", "-m",
        default="facebook/opt-125m",
        help="Model name or path (default: facebook/opt-125m)"
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=50,
        help="Max tokens to generate per prompt (default: 50)"
    )
    parser.add_argument(
        "--num-prompts",
        type=int,
        default=30,
        help="Number of prompts to run (default: 30)"
    )
    parser.add_argument(
        "--gpu-memory",
        type=float,
        default=0.9,
        help="GPU memory utilization 0.0-1.0 (default: 0.9)"
    )
    parser.add_argument(
        "--tensor-parallel", "-tp",
        type=int,
        default=1,
        help="Tensor parallel size (default: 1)"
    )
    args = parser.parse_args()

    print(f"\n=== vLLM Inference Test ===\n")

    # Initialize vLLM
    print(f"Loading model ({args.model})...")
    if args.model == "facebook/opt-125m":
        print("Note: First run will download the model (~250MB)")

    try:
        llm = LLM(
            model=args.model,
            tensor_parallel_size=args.tensor_parallel,
            gpu_memory_utilization=args.gpu_memory,
            download_dir="/tmp/vllm_cache",
            trust_remote_code=True,
        )
        print("Model loaded successfully\n")
    except Exception as e:
        print(f"ERROR: Failed to load model: {e}")
        return 1

    # Test prompts
    base_prompts = [
        "Once upon a time",
        "The meaning of life is",
        "Artificial intelligence will",
        "In the future, technology",
        "Machine learning is",
    ]
    # Repeat to reach desired count
    repeats = max(1, args.num_prompts // len(base_prompts))
    prompts = (base_prompts * repeats)[:args.num_prompts]

    # Sampling parameters
    sampling_params = SamplingParams(
        temperature=0.8,
        top_p=0.95,
        max_tokens=args.max_tokens,
    )

    print(f"=== Inference Configuration ===")
    print(f"Model: {args.model}")
    print(f"Prompts: {len(prompts)}")
    print(f"Max tokens per prompt: {args.max_tokens}")
    print(f"Temperature: 0.8")
    print(f"Top-p: 0.95")
    print(f"Tensor parallel: {args.tensor_parallel}\n")

    # Run inference
    print("Running inference...")
    start_time = time.time()

    try:
        outputs = llm.generate(prompts, sampling_params)
    except Exception as e:
        print(f"ERROR: Inference failed: {e}")
        return 1

    elapsed = time.time() - start_time

    # Calculate metrics
    total_tokens = sum(len(output.outputs[0].token_ids) for output in outputs)
    throughput = total_tokens / elapsed

    print(f"\n=== Results ===")
    print(f"Prompts processed: {len(prompts)}")
    print(f"Total tokens generated: {total_tokens}")
    print(f"Time: {elapsed:.2f}s")
    print(f"Throughput: {throughput:.2f} tokens/sec")
    print(f"Average tokens per prompt: {total_tokens / len(prompts):.1f}")
    print(f"Average time per prompt: {(elapsed / len(prompts)) * 1000:.1f}ms")

    # Show sample outputs
    print(f"\n=== Sample Outputs ===")
    for i, output in enumerate(outputs[:3]):  # Show first 3
        generated_text = output.outputs[0].text
        print(f"\n{i+1}. Prompt: \"{output.prompt}\"")
        print(f"   Output: \"{generated_text.strip()}\"")

    # Validation
    print(f"\n=== Validation ===")
    success = True

    if throughput > 5:  # Minimum 5 tokens/sec
        print(f"  Throughput acceptable ({throughput:.2f} tokens/sec)")
    else:
        print(f"  Throughput too low ({throughput:.2f} tokens/sec)")
        success = False

    if total_tokens > 0:
        print(f"  Generated tokens ({total_tokens})")
    else:
        print(f"  No tokens generated")
        success = False

    if elapsed < 300:  # Should complete in reasonable time
        print(f"  Inference completed in reasonable time ({elapsed:.1f}s)")
    else:
        print(f"  Inference took too long ({elapsed:.1f}s)")
        success = False

    # Check output quality (basic check)
    sample_output = outputs[0].outputs[0].text
    if len(sample_output.strip()) > 0:
        print(f"  Generated text is non-empty")
    else:
        print(f"  Generated empty text")
        success = False

    if success:
        print(f"\nAll tests passed!")
        return 0
    else:
        print(f"\nSome tests failed")
        return 1


if __name__ == "__main__":
    try:
        exit(main())
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        exit(1)
    except Exception as e:
        print(f"\n\nERROR: {e}")
        exit(1)
