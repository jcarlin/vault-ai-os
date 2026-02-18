#!/usr/bin/env python3.12
"""
scripts/test-vllm-inference.py
Test vLLM inference performance
"""

import time
from vllm import LLM, SamplingParams

def main():
    """Main test function"""

    print("\n=== vLLM Inference Test ===\n")

    # Initialize vLLM with a small test model
    print("Loading model (facebook/opt-125m)...")
    print("Note: First run will download the model (~250MB)")

    try:
        llm = LLM(
            model="facebook/opt-125m",  # Small model for testing
            tensor_parallel_size=1,      # Single GPU
            gpu_memory_utilization=0.5,  # Conservative memory usage
            download_dir="/tmp/vllm_cache"
        )
        print("✓ Model loaded successfully\n")
    except Exception as e:
        print(f"ERROR: Failed to load model: {e}")
        return 1

    # Test prompts
    prompts = [
        "Once upon a time",
        "The meaning of life is",
        "Artificial intelligence will",
        "In the future, technology",
        "Machine learning is",
    ] * 6  # 30 prompts total

    # Sampling parameters
    sampling_params = SamplingParams(
        temperature=0.8,
        top_p=0.95,
        max_tokens=50
    )

    print(f"=== Inference Configuration ===")
    print(f"Model: facebook/opt-125m")
    print(f"Prompts: {len(prompts)}")
    print(f"Max tokens per prompt: 50")
    print(f"Temperature: 0.8")
    print(f"Top-p: 0.95\n")

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

    if throughput > 5:  # Minimum 5 tokens/sec for small model
        print(f"✓ Throughput acceptable ({throughput:.2f} tokens/sec)")
    else:
        print(f"✗ Throughput too low ({throughput:.2f} tokens/sec)")
        success = False

    if total_tokens > 500:  # Should generate reasonable amount
        print(f"✓ Generated sufficient tokens ({total_tokens})")
    else:
        print(f"⚠ Low token count ({total_tokens})")

    if elapsed < 60:  # Should complete in reasonable time
        print(f"✓ Inference completed in reasonable time")
    else:
        print(f"✗ Inference took too long")
        success = False

    # Check output quality (basic check)
    sample_output = outputs[0].outputs[0].text
    if len(sample_output.strip()) > 0:
        print(f"✓ Generated text is non-empty")
    else:
        print(f"✗ Generated empty text")
        success = False

    if success:
        print(f"\n✓ All tests passed!")
        return 0
    else:
        print(f"\n✗ Some tests failed")
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
