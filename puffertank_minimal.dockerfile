# Build stage
FROM nvcr.io/nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 as builder
ARG DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /puffertank
WORKDIR /puffertank

# Core system packages (minimal for initial setup)
RUN apt update && apt install -y git curl \
    && rm -rf /var/lib/apt/lists/*

# Workaround for nethack/minihack
ENV READTHEDOCS=True

# PufferLib
RUN git clone https://github.com/pufferai/pufferlib --branch 3.0

# Make CUDA available during build process for kernels
ENV TORCH_CUDA_ARCH_LIST=Turing 

# Install uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Create Python virtual environment
RUN . $HOME/.local/bin/env \
    && uv venv --python 3.12 --prompt 🐡 venv

# Install PyTorch (this is the big one - ~2-3GB download)
RUN . $HOME/.local/bin/env \
    && . venv/bin/activate \
    && uv pip install torch --index-url https://download.pytorch.org/whl/cu128

# Install numpy (needed for PufferLib build)
RUN . $HOME/.local/bin/env \
    && . venv/bin/activate \
    && uv pip install numpy

# Install PufferLib
RUN . $HOME/.local/bin/env \
    && . venv/bin/activate \
    && uv pip install -e pufferlib[train] --no-build-isolation

# Must install after pufferlib (Docker quirk with TORCH_CUDA_ARCH)
RUN apt update && apt install -y \
    build-essential htop clang gdb llvm tmux psmisc software-properties-common sudo libglfw3 \
    && rm -rf /var/lib/apt/lists/* && apt clean

# CARBS hyperparam sweeps
RUN git clone https://github.com/pufferai/carbs \
    && . $HOME/.local/bin/env \
    && . venv/bin/activate \
    && uv pip install -e carbs

# Runtime stage - use runtime image instead of devel
FROM nvcr.io/nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04
ARG DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /puffertank
WORKDIR /puffertank

# Only install runtime packages
RUN apt update && apt install -y \
    curl git htop clang gdb llvm tmux psmisc software-properties-common sudo libglfw3 python3.12 \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean

# Copy built environment from builder stage
COPY --from=builder /puffertank /puffertank
COPY --from=builder /root/.local /root/.local

# Run on container startup
COPY entrypoint.sh /root/entrypoint.sh
RUN chmod +x /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

# Bashrc
RUN echo "export PS1=$''" >> ~/.bashrc \
 && echo "alias diff='diff --color --palette=':ad=36:de=31:ln=33''" >> ~/.bashrc \
 && echo "alias pip='uv pip'" >> ~/.bashrc \
 && echo ". /puffertank/venv/bin/activate" >> ~/.bashrc \
 && echo "cd /puffertank/pufferlib" >> ~/.bashrc

CMD ["/bin/bash"]
