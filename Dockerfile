FROM ros:jazzy-ros-base AS base

# Build librealsense.
FROM base AS librealsense-builder

# Install dev dependencies.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libssl-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    pkg-config \
    libgtk-3-dev \
    git \
    wget \
    cmake\
    build-essential \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    at \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /deps

# Clone required repositories
RUN git clone --branch v2.56.4 https://github.com/IntelRealSense/librealsense.git

# Build and install librealsense
WORKDIR /deps/librealsense
RUN mkdir build && \
    cd build &&  \
    cmake ../ -DCMAKE_BUILD_TYPE=Release  -DCHECK_FOR_UPDATES=OFF && \
    make uninstall && make clean && make -j$(nproc) && make install

# Build realsense-gstreamer
FROM base AS realsense-gstreamer-builder

# Install dev dependencies.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    meson \
    ninja-build \
    libgstreamer-plugins-base1.0-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build and install realsense-gstreamer. Depends on librealsense.
WORKDIR /deps
COPY --from=librealsense-builder /usr/local /usr/local
COPY . /deps/realsense-gstreamer
WORKDIR /deps/realsense-gstreamer
RUN meson build && \
    ninja -C build install && \
    ldconfig

# Final image
FROM base AS final

# Install runtime dependencies.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-nice \
    && rm -rf /var/lib/apt/lists/*

# Copy librealsense and realsense-gstreamer from builders
COPY --from=librealsense-builder /usr/local /usr/local
COPY --from=realsense-gstreamer-builder /usr/local /usr/local

RUN ldconfig

WORKDIR /

# Set up entrypoint
COPY <<'EOF' /debug-entrypoint.sh
#!/bin/bash
export GST_PLUGIN_PATH=/usr/local/lib/aarch64-linux-gnu
/bin/bash
EOF
RUN chmod +x /debug-entrypoint.sh
ENTRYPOINT ["/debug-entrypoint.sh"]