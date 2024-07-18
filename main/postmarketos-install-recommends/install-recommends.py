#!/usr/bin/python3

# SPDX-License-Identifier: ISC

# Copyright © Scott Stevenson <scott@stevenson.io>
#
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted, provided that the
# above copyright notice and this permission notice appear in all
# copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
# PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

"""XDG Base Directory Specification variables.

xdg_cache_home(), xdg_config_home(), xdg_data_home(), and xdg_state_home()
return pathlib.Path objects containing the value of the environment variable
named XDG_CACHE_HOME, XDG_CONFIG_HOME, XDG_DATA_HOME, and XDG_STATE_HOME
respectively, or the default defined in the specification if the environment
variable is unset, empty, or contains a relative path rather than absolute
path.

xdg_config_dirs() and xdg_data_dirs() return a list of pathlib.Path
objects containing the value, split on colons, of the environment
variable named XDG_CONFIG_DIRS and XDG_DATA_DIRS respectively, or the
default defined in the specification if the environment variable is
unset or empty. Relative paths are ignored, as per the specification.

xdg_runtime_dir() returns a pathlib.Path object containing the value of
the XDG_RUNTIME_DIR environment variable, or None if the environment
variable is not set, or contains a relative path rather than absolute path.

"""

# source taken from: https://github.com/srstevenson/xdg-base-dirs
# spec: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html

import argparse
import configparser
import csv
import glob
import math
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import List


g_verbose = False
g_apkbuilds = {}


def _path_from_env(variable: str, default: Path) -> Path:
    """Read an environment variable as a path.

    The environment variable with the specified name is read, and its
    value returned as a path. If the environment variable is not set, is
    set to the empty string, or is set to a relative rather than
    absolute path, the default value is returned.

    Parameters
    ----------
    variable : str
        Name of the environment variable.
    default : Path
        Default value.

    Returns
    -------
    Path
        Value from environment or default.

    """
    if (value := os.environ.get(variable)) and (path := Path(value)).is_absolute():
        return path
    return default


def _paths_from_env(variable: str, default: list[Path]) -> list[Path]:
    """Read an environment variable as a list of paths.

    The environment variable with the specified name is read, and its
    value split on colons and returned as a list of paths. If the
    environment variable is not set, or set to the empty string, the
    default value is returned. Relative paths are ignored, as per the
    specification.

    Parameters
    ----------
    variable : str
        Name of the environment variable.
    default : list[Path]
        Default value.

    Returns
    -------
    list[Path]
        Value from environment or default.

    """
    if value := os.environ.get(variable):
        paths = [Path(path) for path in value.split(":") if Path(path).is_absolute()]
        if paths:
            return paths
    return default


def xdg_cache_home() -> Path:
    """Return a Path corresponding to XDG_CACHE_HOME."""
    return _path_from_env("XDG_CACHE_HOME", Path.home() / ".cache")


def xdg_config_dirs() -> list[Path]:
    """Return a list of Paths corresponding to XDG_CONFIG_DIRS."""
    return _paths_from_env("XDG_CONFIG_DIRS", [Path("/etc/xdg")])


def xdg_config_home() -> Path:
    """Return a Path corresponding to XDG_CONFIG_HOME."""
    return _path_from_env("XDG_CONFIG_HOME", Path.home() / ".config")


def xdg_data_dirs() -> list[Path]:
    """Return a list of Paths corresponding to XDG_DATA_DIRS."""
    return _paths_from_env(
        "XDG_DATA_DIRS",
        [Path(path) for path in "/usr/local/share/:/usr/share/".split(":")],
    )


def xdg_data_home() -> Path:
    """Return a Path corresponding to XDG_DATA_HOME."""
    return _path_from_env("XDG_DATA_HOME", Path.home() / ".local" / "share")


def xdg_runtime_dir() -> Path | None:
    """Return a Path corresponding to XDG_RUNTIME_DIR.

    If the XDG_RUNTIME_DIR environment variable is not set, None will be
    returned as per the specification.

    """
    if (value := os.getenv("XDG_RUNTIME_DIR")) and (path := Path(value)).is_absolute():
        return path
    return None


def xdg_state_home() -> Path:
    """Return a Path corresponding to XDG_STATE_HOME."""
    return _path_from_env("XDG_STATE_HOME", Path.home() / ".local" / "state")


PMAPORTS_CLONE_URL = 'https://gitlab.com/postmarketOS/pmaports.git'


def check_git_installed() -> bool:
    try:
        res = subprocess.run(['git', '--version'], capture_output=True)
        if (res.returncode != 0) or (b'git version' not in res.stdout):
            return False
    except FileNotFoundError:
        return False
    return True


# == for edge:
# PRETTY_NAME="postmarketOS edge"
# VERSION_ID="edge"
# VERSION="edge"
# == for 24.06
# PRETTY_NAME="postmarketOS v24.06"
# VERSION_ID="v24.06"
# VERSION="v24.06"
def get_pmos_version() -> str:
    os_release = {'VERSION': 'edge'}
    try:
        with open('/etc/os-release', 'rt') as f:
            csv_reader = csv.reader(f, delimiter='=')
            os_release = dict(csv_reader)
    except OSError:
        pass
    return os_release['VERSION']


def store_last_fetch_timestamp() -> None:
    ts_path = xdg_cache_home() / 'install-recommends' / 'last_fetch_time'
    cur_time = math.floor(time.clock_gettime(time.CLOCK_MONOTONIC))
    try:
        with ts_path.open('wt') as f:
            f.write(str(cur_time))
    except OSError:
        pass


def get_last_fetch_time() -> int:
    ts_path = xdg_cache_home() / 'install-recommends' / 'last_fetch_time'
    last_fetch_time = 0
    try:
        with ts_path.open('rt') as f:
            last_fetch_time = int(f.readline())
    except OSError:
        pass
    return last_fetch_time


def prepare_pmaports_git_repo() -> None:
    global g_verbose
    cache_home = xdg_cache_home() / 'install-recommends'
    cache_home = cache_home.resolve()
    pmaports_dir = cache_home / 'pmaports'
    if not cache_home.exists():
        os.makedirs(str(cache_home))
    if not pmaports_dir.exists():
        # do initial clone
        if g_verbose:
            print("Will run 'git clone {}' in {}".format(PMAPORTS_CLONE_URL, cache_home))
        subprocess.run(['git', '-C', str(cache_home), 'clone', PMAPORTS_CLONE_URL], check=True)
        store_last_fetch_timestamp()

    # switch pmaports branch depending on postmarketOS version
    pmos_ver = get_pmos_version()
    branch = 'master'

    command = ['git', '-C', str(pmaports_dir), 'show', 'origin/master:channels.cfg']
    run_res = subprocess.run(command, check=True, capture_output=True)
    channels_cfg = run_res.stdout.decode('utf-8')

    cfg = configparser.ConfigParser()
    cfg.read_string(channels_cfg)
    branch = cfg.get(pmos_ver, 'branch_pmaports')

    if g_verbose:
        print('You are on OS version: {}, using branch: {}'.format(pmos_ver, branch))
    command = ['git', '-C', str(pmaports_dir), 'switch', branch]
    subprocess.run(command, check=True)

    # update repo (if needed)
    cur_time = time.clock_gettime(time.CLOCK_MONOTONIC)
    last_fetch_time = get_last_fetch_time()
    if cur_time - last_fetch_time > 1800:  # 30 minutes
        if g_verbose:
            print("Running 'git pull' in {}".format(pmaports_dir))
        subprocess.run(['git', '-C', str(pmaports_dir), 'pull', PMAPORTS_CLONE_URL], check=True)
        store_last_fetch_timestamp()


def parse_apkbuild(apkbuild_file: str) -> dict:
    recs = []
    deps = []
    try:
        # output "_pmb_recommends" and "depends" using a single shell call
        command = ['sh', '-c', f"source {apkbuild_file} && echo $_pmb_recommends && echo $depends"]
        run_res = subprocess.run(command, check=True, capture_output=True)
        output_lines = run_res.stdout.decode('utf-8').split('\n')
        recs = output_lines[0].split()
        deps_r = output_lines[1].split()

        # filter deps, come of packages have them listed as "conflicts", e.g. "!gnome-shell-mobile"
        deps = []
        for d in deps_r:
            if not d.startswith('!'):
                deps.append(d)
    except subprocess.CalledProcessError as ex:
        print(f"Failed to parse {apkbuild_file}!")
        print(ex.stderr.decode('utf-8'), file=sys.stderr)
    return {'_pmb_recommends': recs, 'depends': deps}


def get_recommends_for_package(package_name: str, quiet: bool = False) -> List[str] | None:
    global g_apkbuilds
    pmaports_dir = xdg_cache_home() / 'install-recommends' / 'pmaports'

    # find all APKBUILDs ?
    if len(g_apkbuilds.keys()) == 0:
        for apkbuild in glob.iglob('{}/**/*/APKBUILD'.format(str(pmaports_dir)), recursive=True):
            package = os.path.basename(os.path.dirname(apkbuild))
            if package in g_apkbuilds:
                # should not happen in pmaports, ignore
                continue
            g_apkbuilds[package] = apkbuild

    if package_name not in g_apkbuilds:
        if not quiet:
            print('Cannot find APKBUILD for {} in pmaports!'.format(package_name))
        return None

    apkbuild_file = g_apkbuilds[package_name]
    apkbuild = parse_apkbuild(apkbuild_file)
    recommends = apkbuild['_pmb_recommends']
    depends = apkbuild['depends']

    # recursively get recommends for each recommended & dependency package
    add_recommends = []
    for pkg in recommends:
        recs = get_recommends_for_package(pkg, quiet=True)
        if recs is not None:
            add_recommends.extend(recs)
    for pkg in depends:
        recs = get_recommends_for_package(pkg, quiet=True)
        if recs is not None:
            add_recommends.extend(recs)
    recommends.extend(add_recommends)

    return recommends


def main():
    global g_verbose

    parser = argparse.ArgumentParser(prog=sys.argv[0],
                                     description='Install packages from _pmb_recommends')

    parser.add_argument('package',
                        help='package name to take recommends from')
    parser.add_argument('-u', '--uninstall', action='store_true',
                        help='uninstall recommends instead of installing them')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='print more logs')

    args = parser.parse_args()

    if args.verbose:
        g_verbose = True

    if not check_git_installed():
        print("Program 'git' seems to be not installed. Please install it first!", file=sys.stderr)
        return 1

    os.environ['LANG'] = 'en_US'
    os.environ['LC_ALL'] = 'en_US.UTF-8'

    prepare_pmaports_git_repo()

    package: str = str(args.package)
    recommended_pkgs = get_recommends_for_package(package)

    if recommended_pkgs is None:
        return 1

    if len(recommended_pkgs) == 0:
        print(f'There seems to be no recommends for {package}.')
        return 0

    cmd = 'add'
    if args.uninstall:
        cmd = 'del'

    command = ['sudo', 'apk', cmd, '-i']
    command.extend(recommended_pkgs)

    if g_verbose:
        print('Will run: {}'.format(' '.join(command)))

    run_res = subprocess.run(command)
    return run_res.returncode


if __name__ == "__main__":
    sys.exit(main())
