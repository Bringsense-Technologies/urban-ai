# AI DevBox (Docker + NVIDIA + VS Code)

This repository provides a GPU-enabled C++ development stack based on NVIDIA DeepStream, with:

- Two build targets: `stable` and `advanced`
- Project mapped from host `./project` to container `/root/project`
- VS Code Dev Container support (`.devcontainer/devcontainer.json`)
- Build system support for both CMake and Qbs projects
- C++ debugging support (`gdb`, `gdbserver`, `SYS_PTRACE`, `seccomp:unconfined`)
- C++ symbol demangling enabled by default in GDB
- Shared `ccache` volume across containers

---

## 1. Prerequisites

- Linux host with NVIDIA GPU
- Docker Engine + Docker Compose plugin
- NVIDIA driver installed on host
- NVIDIA Container Toolkit installed and configured for Docker

### Optional helper scripts

You can run the scripts in `setup/`:

- `setup/01_nvidia_drivers.sh`
- `setup/02_nvidia_container_toolkit.sh`
- `setup/03_docker.sh`
- `setup/04_vscode_extensions.sh`

Or run them in order via the root helper:

- `./setup/run.sh`

Example:

```bash
chmod +x setup/run.sh setup/*.sh
./setup/run.sh

# or run steps manually
chmod +x setup/*.sh
./setup/01_nvidia_drivers.sh
# reboot if you installed/updated drivers
./setup/02_nvidia_container_toolkit.sh
./setup/03_docker.sh
./setup/04_vscode_extensions.sh
```

Verify GPU inside Docker:

```bash
docker run --rm --runtime=nvidia --gpus all ubuntu:22.04 nvidia-smi
```

---

## 2. Project layout expectation

Your host source code should live in:

```text
./project
```

It is mounted into the container at:

```text
/root/project
```

---

## 3. Build images

Build `advanced` (default dev target):

```bash
docker compose build advanced
```

Build `stable`:

```bash
docker compose build stable
```

---

## 4. Launch container

### 4.1 Compose (recommended)

Launch the advanced service in background:

```bash
docker compose up -d advanced
```

Open shell in running container:

```bash
docker exec -it c1 /bin/bash
```

Stop it:

```bash
docker compose stop advanced
```

Remove it:

```bash
docker compose rm -f advanced
```

### 4.2 Equivalent `docker run`

If you prefer direct `docker run`, equivalent behavior is:

```bash
docker run -d \
  --name c1 \
  --restart unless-stopped \
  --runtime=nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -v ~/<project>:/root/project \
  -v ai-devbox-ccache:/root/.ccache \
  ai-devbox:advanced
```

### 4.3 Numbered project launcher script

Use `container/start.sh` when you want multiple parallel checkouts of the same repo
like `~/Development/MyProject1`, `~/Development/MyProject2`, etc.

Make it executable:

```bash
chmod +x ./container/start.sh
```

Run it with `PROJECT_PREFIX` and a numeric suffix:

```bash
PROJECT_PREFIX=~/Development/MyProject ./container/start.sh 10
```

This starts container `MyProject10` and maps:

- host: `~/Development/MyProject10`
- container: `/root/project`

---

## 5. Use from VS Code

1. Open this repository in VS Code.
2. Run: **Dev Containers: Rebuild and Reopen in Container**.
3. VS Code attaches to service `advanced` with workspace folder `/root/project`.

Recommended extensions are configured automatically:

- `ms-vscode.cpptools`
- `ms-vscode.cmake-tools`

---

## 6. Debugging notes

This stack is preconfigured for container debugging:

- `gdb` and `gdbserver` installed in image
- `SYS_PTRACE` capability enabled
- `seccomp:unconfined` enabled
- GDB demangling defaults configured in `/root/.gdbinit`

So C++ symbols appear demangled during debugging sessions.

---

## 7. Qbs support (C++ projects)

Qbs is installed in the image, so Qbs-based projects can be built directly in the container.

Check version:

```bash
qbs --version
clang-format --version
```

Create/update a profile (example using GCC):

```bash
qbs setup-toolchains --type gcc /usr/bin/g++ gcc
```

Configure and build a project:

```bash
cd /root/project
qbs config defaultProfile gcc
qbs build -f your-project.qbs profile:gcc config:debug
```

Release build:

```bash
qbs build -f your-project.qbs profile:gcc config:release
```

---

## 8. ccache (shared across containers)

A named Docker volume is used:

- Volume name: `ai-devbox-ccache`
- Mounted at `/root/.ccache`

This means cache survives container recreation and is shared by services using the same volume.

Check cache stats:

```bash
ccache -s
```

Clear cache if needed:

```bash
ccache -C
```

---

## 9. Common commands

Bring up advanced service:

```bash
docker compose up -d advanced
```

Rebuild advanced image:

```bash
docker compose build --no-cache advanced
```

View logs:

```bash
docker compose logs -f advanced
```

Stop all services:

```bash
docker compose down
```

Stop services and remove shared cache volume:

```bash
docker compose down -v
```

---

## 10. Container runtime info helper

A helper script is available to detect container runtime and print container/image metadata:

```bash
./container/info.sh
```

Output includes:

- container name
- image name
- image SHA

By default, SHA is `unknown`. To provide it for compose launches:

```bash
export AI_DEVBOX_ADVANCED_SHA="$(docker image inspect ai-devbox:advanced --format '{{.Id}}')"
docker compose up -d advanced
```

You can do the same for `stable` using `AI_DEVBOX_STABLE_SHA`.

---

## 11. Notes

- Container working directory is `/root/project`.
- If NVIDIA runtime fails, recheck driver/toolkit installation and restart Docker.
- If image tags (DeepStream/LibTorch) change upstream, update build args in `docker-compose.yml`.
