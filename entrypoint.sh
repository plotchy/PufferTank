#!/bin/bash

# print CUDA version
echo "PufferTank 3.0"
echo "CUDA: $(nvcc --version | grep "release" | awk '{print $6}')"

# check if NVIDIA driver is loaded
if ! nvidia-smi > /dev/null 2>&1; then
    echo "WARNING: The NVIDIA Driver was not detected. GPU functionality will not be available."
fi

# keep container running - default to bash if no arguments
if [ $# -eq 0 ]; then
    echo "No arguments provided, starting interactive bash shell..."
    exec /bin/bash
else
    echo "Executing provided arguments: $@"
    exec "$@"
fi
