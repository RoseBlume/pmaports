#!/usr/bin/env python3
# Copyright 2020 Oliver Smith
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Find packages that enable openrc services in their post-install scripts,
# but do not depend on -openrc subpackages:
# https://wiki.postmarketos.org/wiki/Packaging#OpenRC_subpackages
#
# run_test() gets called from build_changed_aports.py in CI. For debugging,
# start this script like a command-line program.
import argparse
import os
import glob
import sys

# Same dir
import common

# pmbootstrap
import testcases.add_pmbootstrap_to_import_path
import pmb.parse.arch
import pmb.helpers.package

# Subset of runlevels we use in postmarketOS
runlevels_valid = ["boot", "default", "shutdown", "sysinit"]


def post_install_parse_services(path):
    """ Get services as listed with 'rc-update add <service> <runlevel>' lines
        in post-install scripts.
        :param path: full path to post-install file
        :returns: (errors, services):
                  * errors: list of error strings
                  * list of services
    """
    errors_all = []
    services = []
    with open(path, encoding="utf-8") as handle:
        errors = []
        for i, line in enumerate(handle.readlines()):
            # Remove comments
            line = line.split("#", 2)[0].rstrip()
            if "rc-update add" not in line \
                    and "rc-update -q add" not in line:
                continue

            # Have nothing before the line
            if not line.startswith("rc-update"):
                errors.append(f"{i}: line does not start with 'rc-update'")

            # Have no shell magic
            for char in ["$", "'", "\"", "\\"]:
                if char in line:
                    errors.append(f"{i}: line contains illegal character:"
                                  f" {char}")

            # Parse format 'rc-update add <service> <runlevel>'
            service = None
            runlevel = None
            try:
                _, _, service, runlevel = line.split(" ")
            except:
                errors.append(f"{i}: line does not follow format 'rc-update"
                              " add <service> <runlevel>'")

            # Validate runlevel
            if runlevel and runlevel not in runlevels_valid:
                errors.append(f"{i}: invalid runlevel '{runlevel}', expected"
                              f" one of: {', '.join(runlevels_valid)}")

            errors_all += errors
            if not errors:
                services.append(service)
    return (errors_all, services)


def run_lint():
    print("linting *.post-install regarding 'rc-update add'")
    pmaports = common.get_pmaports_dir()
    pattern = f"{pmaports}/**/*.post-install"
    count = 0
    for path in glob.glob(pattern, recursive=True):
        errors, _ = post_install_parse_services(path)

        if not errors:
            continue

        count += len(errors)
        print(f"{os.path.relpath(path, pmaports)}:")
        for error in errors:
            print(f"  {error}")

    if count == 0:
        print("success!")
        return

    print("")
    print(f"{count} errors found.")
    print("")
    print("pmaports.git has strict rules for 'rc-update add' lines in")
    print("post-install files. Please fix the errors above.")
    print("Related: https://wiki.postmarketos.org/wiki/Packaging")
    print("")
    sys.exit(1)


def get_relevant_post_install_files(packages):
    """ Get all post-install files from the given packages and their
        subpackages, which have 'rc-update add' lines. """
    ret = []
    for pkgname in packages:
        pattern = f"{common.get_pmaports_dir()}/**/{pkgname}/*.post-install"
        for path in glob.glob(pattern, recursive=True):
            errors, services = post_install_parse_services(path)
            if services:
                ret.append(path)

    return ret


def get_service_owner(chroot_arg, service):
    """ Use apk to figure out which package provides a service file.
        :param chroot_arg: chroot action + suffix argument that will be passed
                           to pmbootstrap
        :param service: name of the service to check, e.g. "bluetooth"
    """
    path = f"/etc/init.d/{service}"
    apk_output = common.run_pmbootstrap(["-q"] + chroot_arg + ["--", "apk",
                                        "info", "-W", path],
                                        output_return=True)

    # example: '/etc/init.d/tinydm is owned by tinydm-openrc-1.0.2-r0'
    prefix = f"{path} is owned by "
    try:
        assert apk_output.startswith(prefix)
        split = apk_output[len(prefix):].rstrip().split("-")
        assert split[-1].startswith("r")
        ret = "-".join(split[:-2])
    except:
        raise RuntimeError(f"Failed to parse 'apk info -W {path}' output:"
                           f" '{apk_output}'")
    return ret


def get_package_depends(chroot_arg, pkgname):
    """ Use apk to figure out the depends of a specific package or subpackage.

        Example output from 'apk info -R':
            postmarketos-ui-phosh-6-r3 depends on:
            bluez
            gnome-keyring
            iio-sensor-proxy
            phosh
            polkit-elogind

            postmarketos-ui-phosh-6-r2 depends on:
            ... (we only care about the top most, newest package)

        :param chroot_arg: chroot action + suffix argument that will be passed
                           to pmbootstrap
        :param pkgname: package or subpackage name
        :returns: list of depends, e.g. ["bluez", "gnome-keyring", ...] """
    apk_output = common.run_pmbootstrap(["-q"] + chroot_arg + ["--", "apk",
                                        "info", "-R", pkgname],
                                        output_return=True)
    ret = []
    try:
        lines = apk_output.split("\n")
        assert lines[0].startswith(f"{pkgname}-")
        assert lines[0].endswith(" depends on:")
        for line in lines[1:]:
            assert not line.endswith(" depends on:")

            # Only parse the top package from the list
            if not line:
                break
            ret.append(line)
    except:
        raise RuntimeError(f"Failed to parse 'apk info -R {pkgname}' output:"
                           f" '{apk_output}'")
    return ret


def run_test_package(zap, work, arch, pkgname, path):
    """ Run the test for a single package.
        :param zap: bool: run 'pmbootstrap zap' before testing the next pkg
        :param work: path to pmbootstrap work dir
        :param arch: architecture to test
        :param pkgname: package name
        :param path: full path to the .post-install file
        :returns: (warnings, errors):
                  * warnings: list of non-fatal warning strings
                  * errors: list of fatal error strings
    """
    errors = []
    warnings = []

    # Set proper chroot suffix for arch
    chroot_arg = ["chroot"]
    suffix = "native"
    if arch != pmb.parse.arch.alpine_native():
        chroot_arg += f"-b{arch}"
        suffix = "buildroot_{arch}"

    # Install package with depends
    if zap:
        common.run_pmbootstrap(["-y", "zap"])
    common.run_pmbootstrap(chroot_arg + ["--", "apk", "add", pkgname])

    # Parse depends
    depends = get_package_depends(chroot_arg, pkgname)
    print(f"{pkgname}: depends: {depends}")

    # Verify each service
    _, services = post_install_parse_services(path)
    etc_initd = f"{work}/chroot_{suffix}/etc/init.d"
    for service in services:
        # init.d file must exist
        if not os.path.exists(f"{etc_initd}/{service}"):
            errors.append("service mentioned in post-install was not"
                          f" installed: '{service}' (missing depend or typo?)")
            continue

        owner = get_service_owner(chroot_arg, service)
        print(f"{service}: owned by: {owner}")

        # No need to explicitly add openrc to every package
        if owner == "openrc":
            continue

        expected_depends = [owner]
        if owner.endswith("-openrc"):
            # Must depend on the same package without '-openrc' too, otherwise
            # only the service file gets installed but not the daemon itself
            expected_depends += ["-".join(owner.split("-")[:-1])]
        else:
            warnings += [f"service '{service}' is owned by package '{owner}',"
                         f" which does not end in '-openrc'"]

        for depend in expected_depends:
            if depend == pkgname:
                continue
            if depend not in depends:
                errors += [f"{pkgname} must depend on '{depend}', because it"
                           f" has 'rc-update add {service}' in post-install"]

    return warnings, errors


def print_summary(category, pkgname_strings):
    """ Print a summary of errors or warnings.
        :param category: "error" or "warning"
        :param pkgname_strings: dict like: {"pkgname1": ["first", ...] """
    print()
    count = sum([len(pkgname_strings[p]) for p in pkgname_strings])
    print(f"=== {count} {category}(s) ===")
    for pkgname in pkgname_strings:
        print(f"{pkgname}:")
        for string in pkgname_strings[pkgname]:
            print(f"* {string}")


def run_test(arch, packages, zap=True):
    """ Run the test on multiple packages
        :param arch: architecture to test
        :param packages: list of pkgnames to test
        :param zap: bool: run 'pmbootstrap zap' before testing the next pkg
    """
    print(f"running missing -openrc subpackages check for {arch}:"
          f" {', '.join(packages)}")

    # Get pmbootstrap's args for args.work
    sys.argv = ["pmbootstrap", "chroot"]
    args = pmb.parse.arguments()

    paths = get_relevant_post_install_files(packages)
    count = len(paths)

    if not count:
        print("no post-install with 'rc-update add' found, nothing to do!")
        return

    errors_all = {}
    warnings_all = {}
    for i, path in enumerate(paths):
        # Parse pkgname from .post-install filename (main or subpackage)
        pkgname, _ = os.path.splitext(os.path.basename(path))
        print(f"=== ({i+1}/{count}) {pkgname} ===")
        warnings, errors = run_test_package(zap, args.work, arch, pkgname,
                                            path)

        if errors:
            errors_all[pkgname] = errors
        if warnings:
            warnings_all[pkgname] = warnings

    # Print summaries
    if warnings_all:
        print_summary("warning", warnings_all)
        print("NOTE: if you add -openrc subpackages to Alpine's aports, add"
              " the -openrc dependency to the postmarketOS packages which"
              " enable the package's service in post-install right"
              " afterwards.")
    if errors_all:
        print_summary("error", errors_all)
        sys.exit(1)

    print("=== check passed ===")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run all *.post-install files"
                                     " from pmaports through run_lint()")
    parser.add_argument("--test-pkgs", nargs="*", metavar="PKGNAME",
                        help="additionally, do run_test() for these packages,"
                             " or all packages if no PKGNAME is specified")
    parser.add_argument("--test-arch", default="x86_64", metavar="ARCH",
                        help="architecture for run_test() (default: x86_64)")
    parser.add_argument("--test-no-zap", dest="zap", action="store_false",
                        help="disable 'pmbootstrap zap' before installing"
                             " the next package to test")
    args = parser.parse_args()

    run_lint()

    if getattr(args, "test_pkgs", None) is None:
        sys.exit(0)

    print("---")
    pkgs = args.test_pkgs

    # Default to all packages for given arch
    if not pkgs:
        sys.argv = ["pmbootstrap", "chroot"]
        pmb_args = pmb.parse.arguments()
        pmaports = common.get_pmaports_dir()

        for path in glob.glob(f"{pmaports}/**/*.post-install", recursive=True):
            pkgname = os.path.basename(os.path.dirname(path))
            if pmb.helpers.package.check_arch(pmb_args, pkgname,
                                              args.test_arch, binary=False):
                pkgs += [pkgname]

    run_test(args.test_arch, pkgs, args.zap)
