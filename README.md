# mkl-starter-kit

A Docker-based starter template for Python projects that need **NumPy and SciPy compiled from source against Intel MKL** (Math Kernel Library). This gives you optimized BLAS/LAPACK performance out of the box.

## For Users

### What This Provides

A ready-to-use Docker environment where NumPy and SciPy are linked to Intel MKL instead of the default OpenBLAS. This can significantly improve performance for linear algebra operations, matrix computations, and scientific workloads.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)

### Quick Start

Build the Docker image:

```bash
docker build -t mkl-starter-kit .
```

Run a container:

```bash
docker run -it mkl-starter-kit uv run python
```

Mount your project files into the container:

```bash
docker run -it -v $(pwd):/app mkl-starter-kit uv run python your_script.py
```

### Verifying MKL Linkage

Inside the container, confirm that NumPy and SciPy are using MKL:

```python
import numpy as np
np.show_config()
```

You should see `mkl` referenced in the BLAS/LAPACK configuration output.

For SciPy:

```python
import scipy
scipy.show_config()
```

## For Developers

### Project Structure

```
mkl-starter-kit/
├── .github/
│   └── workflows/
│       └── ci.yml        # CI pipeline (lint + build + MKL verification)
├── .dockerignore         # Docker build context exclusions
├── .hadolint.yaml        # Dockerfile linter config
├── Dockerfile            # Multi-stage Docker build (builder + runtime)
├── pyproject.toml        # Python project config with MKL build settings
├── LICENSE               # MIT License
└── .gitignore
```

### How MKL Linkage Works

The MKL integration relies on two coordinated configurations:

**1. `pyproject.toml` — Build settings**

```toml
[project]
dependencies = [
    "numpy~=2.4.1",
    "scipy~=1.17.0",
]

[dependency-groups]
build = [                                       # Build-only deps (removed from final image)
    "mkl~=2025.3.1",
    "mkl-devel~=2025.3.1",
    "mkl-include~=2025.3.1",
    "meson-python~=0.19.0",
    "ninja~=1.13.0",
    "Cython~=3.2.4",
    "pythran~=0.18.1",
    "pybind11~=3.0.1",
]

[tool.uv]
no-binary-package = ["numpy", "scipy"]          # Force source builds (no pre-built wheels)
no-build-isolation-package = ["numpy", "scipy"]

[tool.uv.config-settings-package.numpy]
setup-args = ["-Dblas=mkl", "-Dlapack=mkl"]     # Tell Meson to use MKL

[tool.uv.config-settings-package.scipy]
setup-args = ["-Dblas=mkl", "-Dlapack=mkl"]
```

- `no-binary-package` ensures NumPy and SciPy are compiled from source rather than using pre-built wheels (which bundle OpenBLAS).
- `setup-args` passes `-Dblas=mkl -Dlapack=mkl` to the Meson build system so it links against MKL.
- `[dependency-groups] build` contains packages needed only at compile time (MKL headers, build tools). These are installed during the builder stage and removed from the final image.

**2. `Dockerfile` — Multi-stage build**

The Dockerfile uses a two-stage build to keep the final image lightweight:

**Builder stage** (`intel/fortran-essentials:2025.3.1-0-devel-ubuntu24.04`):
- Provides Intel compilers and MKL libraries for compiling NumPy/SciPy from source.
- A symlink is created so `pkg-config` can find MKL:
  ```
  mkl-dynamic-lp64-iomp.pc → mkl.pc
  ```
- `PKG_CONFIG_PATH` is set to the MKL pkgconfig directory during `uv sync` so that Meson can locate MKL at build time.
- SciPy is installed in a separate `uv sync` step because it depends on NumPy being already built and available.
- After compilation, `uv sync` (without `--group build`) removes build-only packages from the virtual environment.

**Runtime stage** (`ubuntu:24.04`):
- Only the MKL and Intel compiler runtime shared libraries are copied from the builder stage.
- The compiled Python environment (uv + venv with NumPy/SciPy) is copied over.
- No compilers, static libraries, or headers are included in the final image.

### Build Toolchain

| Tool | Role |
|------|------|
| [uv](https://docs.astral.sh/uv/) | Fast Python package manager; manages builds and virtual environments |
| [Meson](https://mesonbuild.com/) (via meson-python) | Build system used by NumPy and SciPy |
| [Ninja](https://ninja-build.org/) | Build executor used by Meson |
| [Cython](https://cython.org/) | C-extensions compiler required by NumPy/SciPy builds |
| [Pythran](https://pythran.readthedocs.io/) | Ahead-of-time compiler for numerical kernels in SciPy |
| [pybind11](https://pybind11.readthedocs.io/) | C++/Python bindings used by SciPy |

### Customization

**Change Python version:**

```bash
docker build --build-arg PYTHON_VERSION=3.13 -t mkl-starter-kit .
```

**Change Ubuntu version:**

```bash
docker build --build-arg UBUNTU_VERSION=22.04 -t mkl-starter-kit .
```

**Add your own dependencies:**

Edit `pyproject.toml` and add packages to the `dependencies` list. Standard packages (that don't need MKL) will install normally without any extra configuration.

### Key Versions

| Component | Version |
|-----------|---------|
| Python | >= 3.12 |
| NumPy | ~2.4.1 |
| SciPy | ~1.17.0 |
| MKL | ~2025.3.1 |
| uv | 0.10.0 |

## License

This project is licensed under the [MIT License](LICENSE).
