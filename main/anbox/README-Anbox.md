This is a temporary file that should not end up in master!
---

We don't have working service files for everything yet. So below are the full commands required to start Anbox manually:

1. Start the container-manager (this now happens automatically using a service file)

```
# modprobe loop
# anbox container-manager --daemon --privileged --data-path=/var/lib/anbox # (command prints out nothing and waits, open another shell)
```

2. Hack to make the fifo work. For some reason, lxc is trying to access this file, which does not exist: `/run/lxc//var/lib/anbox/containers/monitor-fifo`

```
# mkdir -p /run/lxc
# ln -s /var /run/lxc/var
# mkfifo /var/lib/anbox/containers/monitor-fifo
```

3. modprobe the required modules:

```
# modprobe tun
# modprobe fuse
```

4. Start session manager:

```
$ anbox session-manager
```

5. Run an Android app

```
$ anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity
```

6. Logs
/var/lib/anbox/logs/container.log


Current fatal error in step 4:

```
[Renderer.cpp:141@initialize] Failed to create context: error=0x3005
[client.cpp:49@start] Failed to start container: Failed to start container: Failed to start container
[session_manager.cpp:148@operator()] Lost connection to container manager, terminating.
[daemon.cpp:61@Run] Container is not running
```

NOTE: one way to make LXC print more information is:
- extracting the lxc source
- edit the code to add more debug messages
- pmbootstrap build lxc --src=path/to/lxc
- (the path to the fifo was found that way)


TODO
- make both daemons work
- write openrc init scripts for the daemons
- add bridge (that's only needed to get internet in anbox, right?)
- "anbox version" says that git is missing ;)
- make sure that kernels where we want to use anbox have:
	ashmem, binder, squashfs_xz
	(possibly add to kconfig_check? "kconfig_check --anbox"?)
	(right now, squashfs_xz is only enabled for x86_64)
- clean up

