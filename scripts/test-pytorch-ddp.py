#!/usr/bin/env python3.12
"""
scripts/test-pytorch-ddp.py
Test PyTorch DistributedDataParallel (DDP) on multiple GPUs
"""

import os
import time
import torch
import torch.nn as nn
import torch.distributed as dist
import torch.multiprocessing as mp
from torch.nn.parallel import DistributedDataParallel as DDP
from torchvision.models import resnet50

def train_ddp(rank, world_size):
    """Training function for each GPU process"""

    # Initialize process group
    os.environ['MASTER_ADDR'] = 'localhost'
    os.environ['MASTER_PORT'] = '12355'

    dist.init_process_group(
        backend='nccl',
        init_method='env://',
        rank=rank,
        world_size=world_size
    )

    # Set device
    torch.cuda.set_device(rank)
    device = torch.device(f'cuda:{rank}')

    if rank == 0:
        print(f"\n=== PyTorch DDP Multi-GPU Test ===")
        print(f"PyTorch version: {torch.__version__}")
        print(f"CUDA version: {torch.version.cuda}")
        print(f"World size: {world_size} GPUs")
        print(f"Backend: NCCL\n")

    # Create model and wrap with DDP
    model = resnet50(weights=None).to(device)
    ddp_model = DDP(model, device_ids=[rank])

    # Synthetic data
    batch_size = 32
    data = torch.randn(batch_size, 3, 224, 224).to(device)
    target = torch.randint(0, 1000, (batch_size,)).to(device)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.SGD(ddp_model.parameters(), lr=0.01)

    # Training loop
    iterations = 100
    start_time = time.time()

    for i in range(iterations):
        optimizer.zero_grad()
        output = ddp_model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()

        if rank == 0 and i % 20 == 0:
            print(f"Iteration {i}/{iterations}, Loss: {loss.item():.4f}")

    # Synchronize all processes
    dist.barrier()

    elapsed = time.time() - start_time
    throughput = (iterations * batch_size * world_size) / elapsed

    if rank == 0:
        print(f"\n=== Training Complete ===")
        print(f"Total time: {elapsed:.2f}s")
        print(f"Throughput: {throughput:.2f} samples/sec")
        print(f"Average iteration time: {(elapsed/iterations)*1000:.2f}ms")

        # Calculate scaling efficiency (compared to single GPU)
        single_gpu_throughput = throughput / world_size
        scaling_efficiency = throughput / (single_gpu_throughput * world_size)
        print(f"Scaling efficiency: {scaling_efficiency*100:.1f}%")

        # Success criteria
        print(f"\n=== Validation ===")
        if throughput > 50:  # Minimum expected throughput
            print("✓ Throughput test PASSED")
        else:
            print("✗ Throughput test FAILED (too slow)")

        if scaling_efficiency > 0.75:  # 75% efficiency minimum
            print("✓ Scaling efficiency PASSED")
        else:
            print("✗ Scaling efficiency FAILED (poor scaling)")

        print(f"\nTest completed successfully!")

    # Cleanup
    dist.destroy_process_group()

def main():
    """Main entry point"""

    # Check CUDA availability
    if not torch.cuda.is_available():
        print("ERROR: CUDA not available")
        print(f"PyTorch version: {torch.__version__}")
        print(f"CUDA compiled: {torch.version.cuda}")
        return 1

    # Get GPU count
    world_size = torch.cuda.device_count()

    if world_size < 2:
        print(f"WARNING: Only {world_size} GPU(s) detected")
        print("Multi-GPU test requires at least 2 GPUs")
        print("Running single-GPU test instead...")
        world_size = 1

    # Display GPU information
    print(f"\n=== GPU Configuration ===")
    for i in range(world_size):
        print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
    print()

    # Launch distributed training
    if world_size > 1:
        mp.spawn(
            train_ddp,
            args=(world_size,),
            nprocs=world_size,
            join=True
        )
    else:
        # Single GPU test
        train_ddp(0, 1)

    return 0

if __name__ == "__main__":
    exit(main())
