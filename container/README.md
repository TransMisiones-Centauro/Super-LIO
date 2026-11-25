# Running Super-LIO in a container (Podman or Docker)

These instructions build and run a ROS 2 Jazzy container image with Super-LIO and the Livox drivers.
They work with both [Podman](https://podman.io/) and [Docker](https://docs.docker.com/), because the two tools
take the same command-line syntax for everything used here. Pick one and set a shell variable so the commands
below can be copied as they are:

```bash
ENGINE=podman   # or: ENGINE=docker
```

Differences between the two:

| | Podman | Docker |
|---|---|---|
| Daemon | None. Containers are child processes of the user | Run by the `dockerd` daemon, usually as root |
| Run as normal user | Yes (rootless by default) | Only if the user is in the `docker` group, or with `sudo` |
| X11 access (`xhost`) | `xhost +local:$USER` | `xhost +local:root` (the container runs as root) |
| Image names | Use fully qualified names (`docker.io/...`, `ghcr.io/...`) | `docker.io/` can be left out |

Podman can also replace Docker transparently: `alias docker=podman`, or install the `podman-docker` package.

## Get the image

### Option 1: download the published image

The image is built, tested and published automatically (see [Automatic builds](#automatic-builds)):

```bash
$ENGINE pull ghcr.io/transmisiones-centauro/super_lio:latest
```

### Option 2: build it with the Dockerfile

From the root of this repository:

```bash
$ENGINE build -f container/Dockerfile -t ghcr.io/transmisiones-centauro/super_lio:latest .
```

The [Dockerfile](Dockerfile) starts from `docker.io/osrf/ros:jazzy-desktop-full`, installs the dependencies, builds the Livox SDK, clones the Livox driver and the Livox/PointCloud2
converter, copies this repository into `/ros2_ws/src/Super-LIO`, and builds everything in `/ros2_ws`.

Check that the image works by running the functional test (see [Automatic builds](#automatic-builds)):

```bash
$ENGINE run --rm ghcr.io/transmisiones-centauro/super_lio:latest bash /test/run_test.sh
```

### Option 3: build it by hand

Start a container from the official ROS 2 Jazzy image:

```bash
$ENGINE pull docker.io/osrf/ros:jazzy-desktop-full
$ENGINE run -it --name super_lio docker.io/osrf/ros:jazzy-desktop-full
```

Inside the container, install the dependencies, build the Livox SDK and drivers, and then build Super-LIO:

```bash
apt update && apt -y upgrade
apt install libgoogle-glog-dev libtbb-dev

# Livox SDK 2
git clone https://github.com/qza36/Livox-SDK2.git
cd Livox-SDK2/
mkdir build && cd build
cmake .. && make -j && make install

# Livox ROS 2 driver and Livox-to-PointCloud2 converter
mkdir -p /ros2_ws/src
cd /ros2_ws/src/
git clone https://github.com/Ericsii/livox_ros_driver2.git ws_livox/src/livox_ros_driver2
git clone https://github.com/ecervera/livox_to_pointcloud2.git
cd .. && colcon build --symlink-install

# Super-LIO
cd /ros2_ws/src/
git clone -b ros2 https://github.com/TransMisiones-Centauro/Super-LIO.git
cd ..
colcon build --symlink-install
exit
```

Save the container as a new image and, optionally, publish it to the GitHub Container Registry.
To push, you must log in first with a GitHub personal access token that has the `write:packages` scope:

```bash
$ENGINE commit super_lio ghcr.io/transmisiones-centauro/super_lio:latest
$ENGINE rm super_lio

$ENGINE login ghcr.io
$ENGINE push ghcr.io/transmisiones-centauro/super_lio:latest
```

Replace `ghcr.io/transmisiones-centauro/super_lio` with your own registry and namespace if needed.

## Run the container

Allow the container to open windows on the host X server (needed for RViz):

```bash
xhost +local:$USER   # Podman (rootless)
xhost +local:root    # Docker
```

Then start the container:

```bash
$ENGINE run -it --rm --name super_lio \
    --env="DISPLAY=$DISPLAY" \
    --env="QT_X11_NO_MITSHM=1" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --device /dev/dri \
    ghcr.io/transmisiones-centauro/super_lio:latest
```

Useful additional options:

- `--net=host --ipc=host`: share the host network and IPC, so that ROS 2 nodes inside the container can discover
  nodes on the host or on the robot. A Livox LiDAR connected over Ethernet also needs the host network.
- `--volume="$HOME/bags:/bags:rw"`: make a host directory with rosbags available inside the container.
- `--volume="$HOME/maps:/maps:rw"`: keep the maps saved by Super-LIO after the container is removed
  (needed for relocalization mode). Set `lio.map.save_map_dir` to `/maps` in the YAML file in `src/super_lio/config/`.
- `--security-opt label=disable`: on SELinux hosts (Fedora, RHEL), allows the container to access the X11 socket.

Inside the container, source the workspace and launch Super-LIO as described in the [main README](../README.md#build--run):

```bash
source /ros2_ws/install/setup.bash
ros2 launch super_lio Livox_mid360.py
```

Launch files for other sensors and datasets are in `src/super_lio/launch/`.

## Automatic builds

The workflow [`.github/workflows/container.yml`](../.github/workflows/container.yml) runs on every push to this
repository, and can also be started by hand from the *Actions* tab. It:

1. Builds the image with `container/Dockerfile`.
2. Runs the functional test, [`container/test/run_test.sh`](test/run_test.sh). The test starts
   the Super-LIO node with `config/hesai.yaml`, changed to read a Velodyne-style point cloud (`lidar_type: 3`), and [publishes synthetic data](test/synthetic_sensors.py) for 25 seconds: a static sensor in
   a box-shaped room, with an IMU at 200 Hz and a point cloud at 10 Hz. It passes if at least 50 odometry messages
   are published and the estimated position stays within 0.5 m of the origin.
3. Publishes the image to `ghcr.io/transmisiones-centauro/super_lio`, only if the test passed, with these tags:
   - the branch name (for example `ros2`), always pointing to the latest build of that branch;
   - `sha-<commit>`, one per build;
   - `latest`, only for builds of the default branch.

For the workflow to publish, the `super_lio` package must give this repository write access: in the package
settings, under *Manage Actions access*, add this repository with the *Write* role.
