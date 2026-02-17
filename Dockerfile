ARG UBUNTU_VERSION=24.04

FROM intel/fortran-essentials:2025.3.1-0-devel-ubuntu${UBUNTU_VERSION} AS builder

ARG UV_VERSION=0.10.0
ARG USERNAME=user
ARG USER_UID=2000
ARG USER_GID=2000
ARG PYTHON_VERSION=3.12

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
  groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
  && apt-get update \
  && apt-get install --no-install-recommends -y libpython3-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s /opt/intel/oneapi/mkl/latest/lib/pkgconfig/mkl-dynamic-lp64-iomp.pc /opt/intel/oneapi/mkl/latest/lib/pkgconfig/mkl.pc

ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

USER ${USERNAME}
WORKDIR /app

RUN \
  curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh

COPY --chown=${USER_UID}:${USER_GID} pyproject.toml ./

RUN \
  uv python install ${PYTHON_VERSION} \
  && PKG_CONFIG_PATH="/opt/intel/oneapi/mkl/latest/lib/pkgconfig:${PKG_CONFIG_PATH}" \
  uv sync --group build --python ${PYTHON_VERSION} --no-install-package scipy \
  && PKG_CONFIG_PATH="/opt/intel/oneapi/mkl/latest/lib/pkgconfig:${PKG_CONFIG_PATH}" \
  uv sync --group build --python ${PYTHON_VERSION} \
  && uv sync --python ${PYTHON_VERSION} \
  && uv cache clean

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG USERNAME=user
ARG USER_UID=2000
ARG USER_GID=2000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
  groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}

COPY --from=builder \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_intel_lp64.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_intel_thread.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_sequential.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_core.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_def.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_avx2.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/libmkl_avx512.so.2 \
  /opt/intel/oneapi/mkl/latest/lib/intel64/

COPY --from=builder \
  /opt/intel/oneapi/compiler/2025.3/lib/libiomp5.so \
  /opt/intel/oneapi/compiler/2025.3/lib/libintlc.so.5 \
  /opt/intel/oneapi/compiler/2025.3/lib/libirc.so \
  /opt/intel/oneapi/compiler/2025.3/lib/libimf.so \
  /opt/intel/oneapi/compiler/2025.3/lib/libsvml.so \
  /opt/intel/oneapi/compiler/2025.3/lib/libirng.so \
  /opt/intel/oneapi/compiler/2025.3/lib/libifcore.so.5 \
  /opt/intel/oneapi/compiler/2025.3/lib/libifcoremt.so.5 \
  /opt/intel/oneapi/compiler/2025.3/lib/libifport.so.5 \
  /opt/intel/oneapi/compiler/2025.3/lib/

ENV LD_LIBRARY_PATH=/opt/intel/oneapi/mkl/latest/lib/intel64:/opt/intel/oneapi/compiler/2025.3/lib

COPY --from=builder --chown=${USER_UID}:${USER_GID} /home/${USERNAME}/.local /home/${USERNAME}/.local
COPY --from=builder --chown=${USER_UID}:${USER_GID} /app /app

ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

USER ${USERNAME}
WORKDIR /app
