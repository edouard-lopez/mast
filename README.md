# MAST

**MAST** is a project to setup a Linux service to mount __Multiple Auto-SSH Tunnels__

[TOC]

## Requirements

* **Debian-based** OS: we are expecting a Debian `6.0+` or Ubuntu-server `12.04+` ;
* **bash** `4.x+`: the shell interpreter used for the service ;
* **autoSSH**: to start and monitor ssh tunnels ;
	* **openssh-client**: this is an obvious dependency ;
* **trickle**: user-space bandwidth shaper ;
* GNU **Make**: task manager used to install client/server, deploy add others stuff.

## Tasks management with `make` and the `makefile`

Makefile define so-called _tasks_, that allow user to easily run a complex sequence of command with a single call (e.g. `make install`).

### Tips and tricks

For administrator unfamiliar with `makefile` syntax, you need to be aware of the following:

* variables can be pass to the makefile script as follow: `make MY_VAR=123 taskname` ;
* the `$` (dollar sign) **must be escaped** if you want to have access to bash variable (e.g. ~~$HOME~~ → `$$HOME`) ;
* multilines commands should end with a `\` (backslash). In a similar fashion than `bash` ;
* the `@` (at sign) is use to prevent a command to be printed prior to execution. If you want to see what commands the task really executed, with variables expanded, simply remote the `@`-sign from the beginning of the line :).

### Installing on Client

Install required packages (`autossh`, `openssh-client`, `ssh-client`).

```bash
make install-client
```

### Installing on Server

Install required packages (`openssh-server`, `ssh-server`, `trickle`).

```bash
make install-server
```

### Creating SSH Key

Create SSH keys pair on client to allow friction-less connection to the server.

```bash
make create-ssh-key
```

### Deploying SSH Key

Once the ssh keys are created we need to copy the public key on the remote server, in order to leverage authentication mechanism.

```bash
make deploy-key
```

If the remote server address differ from the default value (see `REMOTE_SRV` in the _makefile_), the new value must be passed **as an argument**

```bash
make REMOTE_SRV=1.2.3.4 deploy-key
```

**Note:** This task require `create-ssh-key` to be done, this mean you can directly call the `deploy-key` task and it will trigger the `create-ssh-key` if needed

## Service

### Service file[^service-file]

* The `[Unit]` section contains generic information about the service. `systemd` not only manages system services, but also devices, mount points, timer, and other components of the system.
* `[Service]` section encodes information about the service itself. It contains all those settings that apply only to services, and not the other kinds of units `systemd` maintains (mount points, devices, timers, ...)
* [Install]` section encodes information about how the suggested installation should look like, _i.e._ under which circumstances and by which triggers the service shall be started. In this case we simply say that this service shall be started when the multi-user.target unit is activated

### Don't kill me, I have kids!

Check if tunnels are children of the service. If this is the case, that means that killing the service will kill **all** tunnels.
