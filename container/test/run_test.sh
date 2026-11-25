#!/bin/bash
# Functional test of the Super-LIO image: start Super-LIO, feed it synthetic sensor data and check its odometry.
# Run it inside the container:
#   podman run --rm ghcr.io/transmisiones-centauro/super_lio:latest bash /test/run_test.sh

source /opt/ros/${ROS_DISTRO}/setup.bash
source /ros2_ws/install/setup.bash

echo "== Starting Super-LIO"
ros2 run super_lio super_lio_node --ros-args --params-file "$(ros2 pkg prefix super_lio)/share/super_lio/config/hesai.yaml" -p lio.sensor.lidar_type:=3 -p lio.ros.lidar_topic:=/points_raw -p lio.ros.imu_topic:=/imu_raw -p use_sim_time:=true > /tmp/odometry.log 2>&1 &
LAUNCH_PID=$!
sleep 5

echo "== Publishing synthetic sensor data"
python3 /test/synthetic_sensors.py --imu-topic /imu_raw --cloud-topic /points_raw --odom-topic /lio/odom
RESULT=$?

# Stop Super-LIO. Background jobs of a non-interactive shell ignore SIGINT, so send SIGTERM,
# and kill whatever is still running after 10 seconds.
kill -TERM $LAUNCH_PID 2>/dev/null
for _ in $(seq 10); do kill -0 $LAUNCH_PID 2>/dev/null || break; sleep 1; done
pkill -KILL -P $LAUNCH_PID 2>/dev/null
kill -KILL $LAUNCH_PID 2>/dev/null

if [ $RESULT -ne 0 ]; then
    echo "== Super-LIO output"
    tail -n 50 /tmp/odometry.log
fi
exit $RESULT
