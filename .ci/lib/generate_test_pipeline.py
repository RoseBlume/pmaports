#!/usr/bin/env python3
# Generate a gitlab CI yaml file for the integration tests pipeline
# Configures the parallel:matrix variables for the install/upgrade jobs
# based on the union of all the "test-upgrade" configs in the affected APKBUILDs.
# And the boot matrix based on the "test-boot" config.

# use the matrix variables in the needs: section to sequence the 3 jobs, otherwise
# spawn a pipeline for each device (yikes).

import os
import sys
import glob
import json

import common

# Get modified packages
common.add_upstream_git_remote()
pkgs = common.get_changed_packages_paths()

devices = {}


# We support using "main" as a shortcut for main devices
def get_device_variants(devices):
    _devices = []
    for d in devices:
        if d == "main":
            _devices += list(map(lambda x: os.path.basename(x).split("-", 1)[-1],
                             glob.iglob(os.path.join(common.get_pmaports_dir(),
                                                     "device", "main", "device-*"))))
        else:
            _devices.append(d)

    return _devices


# YIKES
def get_device_arch(device):
    return common.run_cmd(["sh", "-c",
                           f"""source {glob.glob(os.path.join(common.get_pmaports_dir(),
                               'device', '*', f'device-{device}'))[0]}/deviceinfo; echo $deviceinfo_arch"""]).strip()


# Add a device that we should test upgrading pkg on
def add_devices(pkg, devices_upgrade, devices_boot):
    devices_upgrade = get_device_variants(devices_upgrade)
    devices_boot = get_device_variants(devices_boot)
    print(f"Devices for {pkg}: {devices_upgrade} {devices_boot}")
    for d in set(devices_upgrade + devices_boot):
        if d not in devices.keys():
            devices[d] = {"upgrade": False, "boot": False, "arch": get_device_arch(d)}

        if d in devices_boot:
            devices[d]["boot"] = True
        if d in devices_upgrade:
            devices[d]["upgrade"] = True


def parse_device_list(key):
    cfg = line.split(":")[-1]
    if cfg == f"# {key}:":
        print(f"Invalid test-upgrade config in {apkbuild}")
        sys.exit(1)
    return cfg.strip().split()


# Get the union of all the test-upgrade configs
for pkg in pkgs:
    apkbuild = os.path.join(pkg, "APKBUILD")
    with open(apkbuild) as f:
        # ALWAYS test on qemu
        upgrade_devices = ["qemu-aarch64", "qemu-amd64"]
        boot_devices = []
        for line in f:
            if line != "\n" and line[0] != "#":
                break
            if line.startswith("# test-upgrade"):
                upgrade_devices += parse_device_list("test-upgrade")
            if line.startswith("# test-boot"):
                boot_devices += parse_device_list("test-boot")
        add_devices(os.path.basename(pkg), upgrade_devices, boot_devices)

print(json.dumps(devices, indent=4))

# Generate the yaml
template = open(os.path.join(os.path.dirname(__file__), "test-pipeline.template.yml")).read()
matrix = ""
for (device, cfg) in devices.items():
    # FIXME: riscv64 is not well supported..
    if cfg["arch"] == "riscv64":
        continue
    boot = "true" if cfg["boot"] and "qemu" in device else "false"
    upgrade = "true" if cfg["upgrade"] else "false"
    print(f"Adding {device} to matrix, upgrade test: {upgrade}, boot test: {boot}")
    matrix += f"""      - DEVICE: {device}
        UPGRADE_TEST: \"{upgrade}\"
        BOOT_TEST: \"{boot}\"
        BUILD_ARCH_JOB: build-{cfg["arch"]}
"""

variables = f"  PACKAGES: {' '.join(map(lambda x: os.path.basename(x), pkgs))}\n"

f = open("test-pipeline.yml", "w")
f.write(template.replace("{{ matrix }}", matrix)
                .replace("{{ variables }}", variables))
f.close()
