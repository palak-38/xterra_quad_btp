Svan M2 Robot Simulation
========================

A MuJoCo-based simulation environment for the Svan M2 Metal quadruped robot.
This codebase provides a simulation setup for developing and testing.

Note: This package has been designed to be run on Ubuntu 22.04.

RUNNING THE SIMULATION
======================

The launcher script starts all four processes in a tmux session
automatically. From the m2_sim directory, run:

    chmod +x m2_launch.sh   # only needed once
    ./m2_launch.sh

This launches the following in order inside a tmux session:

    Window 1  Physics Simulator    (simulate_pv)
    Window 2  Joystick Multiplexer (joystick_mux)
    Window 3  Keyboard Interface   (keyboard_interface_dds)
    Window 4  Motion Controller    (motion_controller)
    Window 5  Help screen

You will land on the Keyboard Interface window (Window 3).


Tmux Controls
-------------
All shortcuts use the tmux prefix Ctrl-b, followed by:

    1-5     Switch to a window
    R       Restart the current window's process
    X       Stop the current window's process
    Q       Kill all processes and exit the simulation


Other Commands
--------------
    ./m2_launch.sh --setup     Only add library paths to ~/.bashrc
    ./m2_launch.sh --kill      Kill a running simulation session
    ./m2_launch.sh --status    Check if a simulation session is running
    ./m2_launch.sh --help      Show usage help


KEYBOARD CONTROLS
=================

Use Terminal 3 (keyboard_interface_dds) to control the robot.
Each key press increments / decrements by 0.1 (range -1.0 to 1.0).

  State Buttons
  -------------
  1           Sleep
  2           Fixed Stand
  3           Trot (Move)
  4           Free Stand

  Move / Idle Stand State
  -----------------------
  Up Arrow    Move forward
  Down Arrow  Move backward
  Left Arrow  Strafe left
  Right Arrow Strafe right
  A / D       Yaw / Turn left / right
  W / S       Base height up / down

  Free Stand State
  ----------------
  Up Arrow    Move forward
  Down Arrow  Move backward
  Left Arrow  Yaw left
  Right Arrow Yaw right
  A / D       Roll left / right
  W / S       Pitch forward / back

  Spacebar    Reset all axes to 0


ADDING PAYLOAD
==============

Payloads are rigid bodies attached to the robot base. The system has two parts:

  1. config/payload_config.yaml  -- defines payload properties
  2. inject_payloads.py          -- writes those payloads into the MuJoCo XML model


Step 1 - Define a payload in config/payload_config.yaml
--------------------------------------------------------

payloads:
  - name: "box_payload"       # Unique name for the payload body
    mass: 10.0                # Mass in kg
    pos: [0.0, 0.0, 0.13246] # [x, y, z] position relative to robot base origin (m)
                              # Note: torso top surface is at z ~0.057 m,
                              # so pos.z should be above this value
    inertia: [0.00375, 0.00375, 0.00375]  # Diagonal inertia tensor [Ixx, Iyy, Izz] (kg*m^2)
    size: [0.075, 0.075, 0.075]           # Box half-extents (m); full side = 2 x size
    rgba: [0.8, 0.2, 0.2, 0.8]           # [r, g, b, alpha] visual color

To add multiple payloads, add more list entries under payloads:.
To disable a payload without deleting it, comment it out with #.

config_m2_metal.yaml also has a payload section that must be kept in sync
with payload_config.yaml so the physics model and the controller model agree:

payload:
  enabled: false             # Set to true to activate payload in the controller
  mass: 2.0                  # Should match payload_config.yaml mass
  pos: [0.10, 0.0, 0.08]    # CoM position relative to base (m)
  com: [0.10, 0.0, 0.08]    # Center of mass
  inertia: [0.6256, 0.0, 0.0,
            0.0, 0.7156, 0.0,
            0.0, 0.0, 0.69]  # Full 3x3 inertia tensor (kg*m^2)


Step 2 - Inject the payload into the MuJoCo model
--------------------------------------------------

Run from the m2_sim root directory:

    python3 inject_payloads.py

The script finds the <!-- PAYLOAD_INJECT_HERE --> marker in m2_metal.xml and
replaces whatever was previously injected with fresh body elements from
payload_config.yaml. It is idempotent -- safe to re-run after every edit.

Custom paths (optional):
    python3 inject_payloads.py \
        --xml path/to/m2_metal.xml \
        --config path/to/payload_config.yaml

Requires pyyaml: pip install pyyaml