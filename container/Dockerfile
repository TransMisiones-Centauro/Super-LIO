# ROS 2 Jazzy image with Super-LIO and the Livox drivers, built from this repository.
#
# Build from the root of the repository:
#   podman build -f container/Dockerfile -t ghcr.io/transmisiones-centauro/super_lio:latest .
#   docker build -f container/Dockerfile -t ghcr.io/transmisiones-centauro/super_lio:latest .

FROM docker.io/osrf/ros:jazzy-desktop-full

RUN apt-get update \
    && apt-get install -y --no-install-recommends git libgoogle-glog-dev libtbb-dev \
    && rm -rf /var/lib/apt/lists/*

# Livox SDK 2
WORKDIR /
RUN git clone --depth 1 https://github.com/qza36/Livox-SDK2.git \
    && cmake -S Livox-SDK2 -B Livox-SDK2/build \
    && cmake --build Livox-SDK2/build -j"$(nproc)" \
    && cmake --install Livox-SDK2/build

# Livox ROS 2 driver and Livox -> PointCloud2 converter
WORKDIR /ros2_ws/src
RUN git clone --depth 1 https://github.com/Ericsii/livox_ros_driver2.git ws_livox/src/livox_ros_driver2 \
    && git clone --depth 1 https://github.com/ecervera/livox_to_pointcloud2.git

# The source code of this repository
COPY . /ros2_ws/src/Super-LIO

WORKDIR /ros2_ws
RUN . /opt/ros/${ROS_DISTRO}/setup.sh \
    && colcon build --symlink-install \
    && echo "source /ros2_ws/install/setup.bash" >> /root/.bashrc

# Functional test, used by the GitHub workflow (see container/test/).
COPY container/test /test

CMD ["bash"]
