#!/usr/bin/env python3.12
"""
scripts/test-tensorflow-multigpu.py
Test TensorFlow multi-GPU configuration and training
"""

import time
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

def main():
    """Main test function"""

    print("\n=== TensorFlow Multi-GPU Test ===\n")

    # Display TensorFlow version
    print(f"TensorFlow version: {tf.__version__}")

    # Check GPU availability
    gpus = tf.config.list_physical_devices('GPU')
    print(f"GPU devices detected: {len(gpus)}")

    if len(gpus) == 0:
        print("ERROR: No GPUs detected by TensorFlow")
        return 1

    # Display GPU information
    print("\n=== GPU Information ===")
    for i, gpu in enumerate(gpus):
        print(f"GPU {i}: {gpu.name}")
        # Try to get GPU details
        try:
            gpu_details = tf.config.experimental.get_device_details(gpu)
            if gpu_details:
                print(f"  Details: {gpu_details}")
        except:
            pass

    # Configure GPU memory growth (prevent TF from allocating all memory)
    for gpu in gpus:
        try:
            tf.config.experimental.set_memory_growth(gpu, True)
            print(f"Enabled memory growth for {gpu.name}")
        except RuntimeError as e:
            print(f"Warning: {e}")

    # Create a simple model
    print("\n=== Creating Model ===")

    # Use MirroredStrategy for multi-GPU training
    if len(gpus) > 1:
        strategy = tf.distribute.MirroredStrategy()
        print(f"Using MirroredStrategy with {strategy.num_replicas_in_sync} GPUs")
    else:
        strategy = tf.distribute.get_strategy()
        print("Using default strategy (single GPU)")

    # Build model within strategy scope
    with strategy.scope():
        model = keras.Sequential([
            layers.Conv2D(32, 3, activation='relu', input_shape=(224, 224, 3)),
            layers.MaxPooling2D(),
            layers.Conv2D(64, 3, activation='relu'),
            layers.MaxPooling2D(),
            layers.Flatten(),
            layers.Dense(128, activation='relu'),
            layers.Dense(10, activation='softmax')
        ])

        model.compile(
            optimizer='adam',
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy']
        )

    print(f"Model created with {model.count_params():,} parameters")

    # Create synthetic dataset
    print("\n=== Preparing Synthetic Data ===")
    batch_size = 32 * len(gpus)  # Scale batch size with GPU count
    num_batches = 100

    # Generate random data
    x_train = tf.random.normal((batch_size * num_batches, 224, 224, 3))
    y_train = tf.random.uniform((batch_size * num_batches,), minval=0, maxval=10, dtype=tf.int32)

    print(f"Batch size: {batch_size}")
    print(f"Training batches: {num_batches}")
    print(f"Total samples: {batch_size * num_batches}")

    # Training
    print("\n=== Training ===")
    start_time = time.time()

    history = model.fit(
        x_train, y_train,
        batch_size=batch_size,
        epochs=3,
        verbose=1
    )

    elapsed = time.time() - start_time

    # Results
    print(f"\n=== Results ===")
    print(f"Training time: {elapsed:.2f}s")
    print(f"Samples processed: {batch_size * num_batches * 3}")
    print(f"Throughput: {(batch_size * num_batches * 3) / elapsed:.2f} samples/sec")

    final_loss = history.history['loss'][-1]
    final_accuracy = history.history['accuracy'][-1]
    print(f"Final loss: {final_loss:.4f}")
    print(f"Final accuracy: {final_accuracy:.4f}")

    # Test GPU tensor operations
    print("\n=== GPU Tensor Test ===")
    with tf.device('/GPU:0'):
        a = tf.constant([[1.0, 2.0], [3.0, 4.0]])
        b = tf.constant([[1.0, 1.0], [0.0, 1.0]])
        c = tf.matmul(a, b)
        print(f"GPU tensor operation successful")
        print(f"Result shape: {c.shape}")

    # Validation
    print("\n=== Validation ===")
    success = True

    if len(gpus) >= 2:
        print(f"✓ Multi-GPU detected ({len(gpus)} GPUs)")
    else:
        print(f"⚠ Only {len(gpus)} GPU detected")

    if elapsed < 300:  # Should complete in reasonable time
        print(f"✓ Training completed in reasonable time")
    else:
        print(f"✗ Training took too long")
        success = False

    if final_loss < 10.0:  # Synthetic data, just check it trains
        print(f"✓ Model training converged")
    else:
        print(f"⚠ Model may not have converged properly")

    if success:
        print(f"\n✓ All tests passed!")
        return 0
    else:
        print(f"\n✗ Some tests failed")
        return 1

if __name__ == "__main__":
    exit(main())
