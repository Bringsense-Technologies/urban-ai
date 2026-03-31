# =============================================================================
# ARGUMENTS (Global Scope – available in FROM lines)
# =============================================================================
ARG BASE_IMAGE_URL=ubuntu:24.04
ARG ZED_SDK_MAJOR=5
ARG ZED_SDK_MINOR=2
ARG ZED_CUDA_MAJOR=12

# =============================================================================
# STAGE 1: Downloader
# Downloads and verifies binary artifacts in a minimal layer, keeping wget/git
# out of the final runtime image.
# =============================================================================
FROM ubuntu:24.04 AS downloader
ARG CMAKE_VERSION
ARG TARGETARCH
ARG TORCH_URL
# Optional SHA256 for LibTorch; if set, the download is verified.
ARG TORCH_SHA256=""
ARG REQUIRE_TORCH_SHA256=0
ARG EIGEN_VERSION
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# --- CMake: download and verify checksum from Kitware's release manifest ---
WORKDIR /downloads
RUN BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${BUILD_ARCH}" in \
      amd64|x86_64) CMAKE_ARCH="x86_64" ;; \
      arm64|aarch64) CMAKE_ARCH="aarch64" ;; \
      *) echo "Unsupported architecture: ${BUILD_ARCH} (TARGETARCH='${TARGETARCH}')" >&2; exit 1 ;; \
    esac \
    && CMAKE_INSTALLER="cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.sh" \
    && wget -q "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_INSTALLER}" \
    && wget -q "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-SHA-256.txt" \
    && grep "  ${CMAKE_INSTALLER}$" "cmake-${CMAKE_VERSION}-SHA-256.txt" | sha256sum -c - \
    && mkdir -p /opt/cmake \
    && bash "${CMAKE_INSTALLER}" --skip-license --prefix=/opt/cmake \
    && rm "${CMAKE_INSTALLER}" "cmake-${CMAKE_VERSION}-SHA-256.txt"

# --- LibTorch: download, verify if TORCH_SHA256 provided ---
RUN wget -q "${TORCH_URL}" -O libtorch.zip \
    && if [ -n "${TORCH_SHA256}" ]; then \
         echo "${TORCH_SHA256}  libtorch.zip" | sha256sum -c -; \
             elif [ "${REQUIRE_TORCH_SHA256}" = "1" ]; then \
                 echo "Error: TORCH_SHA256 is required but was not provided." >&2; \
                 exit 1; \
       else \
         echo "Warning: TORCH_SHA256 not set; skipping LibTorch checksum verification."; \
       fi \
    && unzip -q libtorch.zip -d /opt \
    && rm libtorch.zip

# --- Eigen: clone specific tag ---
RUN git clone --branch "${EIGEN_VERSION}" --depth 1 \
    https://gitlab.com/libeigen/eigen.git /opt/eigen \
    && rm -rf /opt/eigen/.git

# =============================================================================
# STAGE 2: Runtime image
# =============================================================================
FROM ${BASE_IMAGE_URL}
# Re-declare global ARG so it is visible in RUN commands of this stage.
ARG BASE_IMAGE_URL
ARG GCC_VERSION
ARG CMAKE_VERSION
ARG TORCH_URL
ARG TORCH_SHA256=""
ARG REQUIRE_TORCH_SHA256=0
ARG EIGEN_VERSION
ARG CCACHE_MAXSIZE="20G"
ARG SKIP_OS_UPGRADE=0
ARG INSTALL_ZED_SDK=0
ARG ZED_SDK_MAJOR=5
ARG ZED_SDK_MINOR=2
ARG ZED_CUDA_MAJOR=12
ARG ZED_GL=0
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="AI DevBox" \
    org.opencontainers.image.description="GPU-enabled C++ development stack based on NVIDIA DeepStream" \
    ai.devbox.base_image="${BASE_IMAGE_URL}" \
    ai.devbox.gcc_version="${GCC_VERSION}" \
    ai.devbox.cmake_version="${CMAKE_VERSION}" \
    ai.devbox.torch_url="${TORCH_URL}" \
    ai.devbox.torch_sha256="${TORCH_SHA256}" \
    ai.devbox.require_torch_sha256="${REQUIRE_TORCH_SHA256}" \
    ai.devbox.eigen_version="${EIGEN_VERSION}" \
    ai.devbox.ccache_maxsize="${CCACHE_MAXSIZE}" \
    ai.devbox.zed_sdk_major="${ZED_SDK_MAJOR}" \
    ai.devbox.zed_sdk_minor="${ZED_SDK_MINOR}" \
    ai.devbox.zed_cuda_major="${ZED_CUDA_MAJOR}" \
    ai.devbox.install_zed_sdk="${INSTALL_ZED_SDK}"

RUN echo "Building AI Stack with:" && \
    echo "  Base: ${BASE_IMAGE_URL}" && \
    echo "  GCC:  ${GCC_VERSION}"

# -----------------------------------------------------------------------------
# 1. STABLE SYSTEM PACKAGES
# This layer rarely changes; it is cached across GCC/CMake/Torch bumps.
# Set SKIP_OS_UPGRADE=1 to bypass full-upgrade during build.
# -----------------------------------------------------------------------------
RUN apt-get update \
    && if [ "${SKIP_OS_UPGRADE}" != "1" ]; then apt-get -y full-upgrade; fi \
    && apt-get install -y --no-install-recommends \
    binutils \
    ccache \
    clang-format \
    gdb \
    gdbserver \
    gpg-agent \
    libopencv-dev \
    ninja-build \
    pkg-config \
    qbs \
    software-properties-common \
    wget \
    curl \
    ca-certificates \
    git \
    unzip \
    tar \
    && rm -rf /var/lib/apt/lists/*

RUN echo "Installed Qbs version: $(qbs --version | head -n 1)"

# -----------------------------------------------------------------------------
# 2. GCC (volatile layer – invalidates only when GCC_VERSION changes)
# -----------------------------------------------------------------------------
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    gcc-${GCC_VERSION} \
    g++-${GCC_VERSION} \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100

# ccache defaults (shared cache dir is mounted from docker-compose)
ENV CCACHE_DIR=/root/.ccache
ENV CCACHE_MAXSIZE=${CCACHE_MAXSIZE}
ENV PATH=/usr/lib/ccache:$PATH

# -----------------------------------------------------------------------------
# 3. COPY PRE-BUILT ARTIFACTS FROM DOWNLOADER STAGE
# Invalidates only when the corresponding ARG (CMAKE_VERSION / TORCH_URL /
# EIGEN_VERSION) changes, not on every image rebuild.
# -----------------------------------------------------------------------------
COPY --from=downloader /opt/cmake /opt/cmake
COPY --from=downloader /opt/libtorch /opt/libtorch
COPY --from=downloader /opt/eigen /opt/eigen

# Environment variables for C++ tooling
ENV PATH=/opt/cmake/bin:/usr/lib/ccache:$PATH
ENV Torch_DIR=/opt/libtorch/share/cmake/Torch
ENV LD_LIBRARY_PATH=/opt/libtorch/lib:$LD_LIBRARY_PATH

# -----------------------------------------------------------------------------
# 4. ZED SDK (optional – set INSTALL_ZED_SDK=1 to enable)
# Ubuntu version is auto-detected from the base image so the correct installer
# is fetched regardless of which DeepStream release is used as the base.
# skip_cuda preserves the CUDA stack already provided by the DeepStream base.
# skip_tools keeps the image smaller; GUI tools are in the zed-gl service.
# -----------------------------------------------------------------------------
RUN if [ "${INSTALL_ZED_SDK}" = "1" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            lsb-release \
            less \
            udev \
            zstd \
            sudo \
            libpng-dev \
            libgomp1 \
            python3-numpy \
        && rm -rf /var/lib/apt/lists/* \
        && UBUNTU_YEAR=$(. /etc/os-release && echo "${VERSION_ID%.*}") \
        && wget -q -O ZED_SDK.run \
            "https://download.stereolabs.com/zedsdk/${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}/cu${ZED_CUDA_MAJOR}/ubuntu${UBUNTU_YEAR}" \
        && chmod +x ZED_SDK.run \
        && ./ZED_SDK.run -- silent skip_tools skip_cuda \
        && ln -sf /usr/lib/x86_64-linux-gnu/libusb-1.0.so.0 \
                  /usr/lib/x86_64-linux-gnu/libusb-1.0.so \
        && rm ZED_SDK.run; \
    fi

# -----------------------------------------------------------------------------
# 5. ZED GL support (optional – requires INSTALL_ZED_SDK=1 and ZED_GL=1)
# Adds OpenGL libraries and ZED GUI tool prerequisites (ZED Explorer, etc.).
# On the host run: xhost +si:localuser:root before launching the zed-gl service.
# -----------------------------------------------------------------------------
RUN if [ "${ZED_GL}" = "1" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            libegl1 \
            libgles2 \
            libgl1 \
            mesa-utils \
            python3-pyopengl \
        && rm -rf /var/lib/apt/lists/* \
        && mkdir -p /root/Documents/ZED/; \
    fi

# ZED SDK paths – exported unconditionally; harmless when SDK is not installed.
ENV ZED_SDK_DIR=/usr/local/zed
ENV LD_LIBRARY_PATH=/usr/local/zed/lib:$LD_LIBRARY_PATH

RUN torch_ver="$(tr -d '[:space:]' < /opt/libtorch/version.txt 2>/dev/null || echo 'unknown')" \
    && opencv_ver="$(pkg-config --modversion opencv4 2>/dev/null \
         || dpkg -l libopencv-dev 2>/dev/null | awk '/^ii/{print $3}' | head -1 \
         || echo 'unknown')" \
    && if [ "${INSTALL_ZED_SDK}" = "1" ]; then zed_ver="${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}"; else zed_ver="not_installed"; fi \
    && printf '%s\n' \
       "AI_DEVBOX_BASE_IMAGE=${BASE_IMAGE_URL}" \
       "AI_DEVBOX_GCC_VERSION=${GCC_VERSION}" \
       "AI_DEVBOX_CMAKE_VERSION=${CMAKE_VERSION}" \
       "AI_DEVBOX_TORCH_URL=${TORCH_URL}" \
       "AI_DEVBOX_TORCH_SHA256=${TORCH_SHA256}" \
       "AI_DEVBOX_REQUIRE_TORCH_SHA256=${REQUIRE_TORCH_SHA256}" \
       "AI_DEVBOX_EIGEN_VERSION=${EIGEN_VERSION}" \
       "AI_DEVBOX_CCACHE_MAXSIZE=${CCACHE_MAXSIZE}" \
       "AI_DEVBOX_TORCH_VERSION=${torch_ver}" \
       "AI_DEVBOX_OPENCV_VERSION=${opencv_ver}" \
       "AI_DEVBOX_ZED_SDK_MAJOR=${ZED_SDK_MAJOR}" \
       "AI_DEVBOX_ZED_SDK_MINOR=${ZED_SDK_MINOR}" \
       "AI_DEVBOX_ZED_CUDA_MAJOR=${ZED_CUDA_MAJOR}" \
       "AI_DEVBOX_ZED_VERSION=${zed_ver}" \
       "AI_DEVBOX_ZED_GL=${ZED_GL}" \
       > /etc/ai-devbox-release

# -----------------------------------------------------------------------------
# 6. ENTRYPOINT
# -----------------------------------------------------------------------------
RUN printf '%s\n' \
    'set print demangle on' \
    'set print asm-demangle on' \
    'set demangle-style gnu-v3' \
    > /root/.gdbinit

WORKDIR /root/project
# sleep infinity is more robust than tail -f /dev/null; it ignores signals
# that would otherwise terminate the container.
CMD ["sleep", "infinity"]

