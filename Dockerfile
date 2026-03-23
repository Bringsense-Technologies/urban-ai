# -----------------------------------------------------------------------------
# ARGUMENTS (Global Scope)
# These must be defined before FROM to be used in the FROM line
# -----------------------------------------------------------------------------
ARG BASE_IMAGE_URL=ubuntu:24.04
FROM ${BASE_IMAGE_URL}

# -----------------------------------------------------------------------------
# ARGUMENTS (Build Scope)
# These are passed from docker-compose
# -----------------------------------------------------------------------------
ARG GCC_VERSION
ARG CMAKE_VERSION
ARG TORCH_URL
ARG EIGEN_VERSION
ARG SKIP_OS_UPGRADE=0
ARG DEBIAN_FRONTEND=noninteractive

# Echo configuration for debugging logs
RUN echo "Building AI Stack with:" && \
    echo "  Base: ${BASE_IMAGE_URL}" && \
    echo "  GCC:  ${GCC_VERSION}" && \
    echo "  CMake:${CMAKE_VERSION}" && \
    echo "  Qbs:  detect after apt install"

# -----------------------------------------------------------------------------
# 1. SYSTEM & COMPILER SETUP
# -----------------------------------------------------------------------------
# Update Ubuntu packages to the latest available versions in the base image
# Set SKIP_OS_UPGRADE=1 to bypass full-upgrade during build
RUN apt-get update \
    && if [ "${SKIP_OS_UPGRADE}" != "1" ]; then apt-get -y full-upgrade; fi \
    && apt-get install -y \
    software-properties-common \
    wget \
    unzip \
    git \
    ninja-build \
    pkg-config \
    clang-format \
    qbs \
    libopencv-dev \
    ccache \
    binutils \
    gdb \
    gdbserver \
    # Install dependencies for adding PPAs
    gpg-agent \
    && rm -rf /var/lib/apt/lists/*

RUN echo "Installed Qbs version: $(qbs --version | head -n 1)"

# Add PPA for newer GCC versions (Ubuntu Toolchain Test)
# This is required because older Ubuntu bases don't have GCC 13/14/15 natively
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y \
    && apt-get update \
    && apt-get install -y gcc-${GCC_VERSION} g++-${GCC_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Configure the system to use the requested GCC version as default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100

# ccache defaults (shared cache dir is mounted from docker-compose)
ENV CCACHE_DIR=/root/.ccache
ENV CCACHE_MAXSIZE=20G
ENV PATH=/usr/lib/ccache:$PATH

# -----------------------------------------------------------------------------
# 2. CMAKE SETUP
# -----------------------------------------------------------------------------
WORKDIR /tmp
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh \
    && chmod +x cmake-${CMAKE_VERSION}-linux-x86_64.sh \
    && ./cmake-${CMAKE_VERSION}-linux-x86_64.sh --skip-license --prefix=/usr/local \
    && rm cmake-${CMAKE_VERSION}-linux-x86_64.sh

# -----------------------------------------------------------------------------
# 3. LIBTORCH (PYTORCH C++) SETUP
# -----------------------------------------------------------------------------
WORKDIR /opt
# We use the full URL passed as an argument because the naming convention changes often
RUN wget ${TORCH_URL} -O libtorch.zip \
    && unzip libtorch.zip \
    && rm libtorch.zip

# Environment variables for C++ to find Torch
ENV Torch_DIR=/opt/libtorch
ENV LD_LIBRARY_PATH=/opt/libtorch/lib:$LD_LIBRARY_PATH

# -----------------------------------------------------------------------------
# 4. EIGEN & EXTRAS
# -----------------------------------------------------------------------------
# Cloning specific tag/version
RUN git clone --branch ${EIGEN_VERSION} --depth 1 https://gitlab.com/libeigen/eigen.git /opt/eigen

# -----------------------------------------------------------------------------
# 5. ENTRYPOINT
# -----------------------------------------------------------------------------
RUN printf '%s\n' \
    'set print demangle on' \
    'set print asm-demangle on' \
    'set demangle-style gnu-v3' \
    > /root/.gdbinit

WORKDIR /root/project
CMD ["/bin/bash"]

