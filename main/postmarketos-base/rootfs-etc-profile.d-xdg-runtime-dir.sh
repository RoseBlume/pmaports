# Ensure that XDG_RUNTIME_DIR is always set to allow e.g. starting graphical apps via SSH
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
