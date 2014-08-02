# MAST

**MAST** is a project to setup a Linux service to mount __Multiple Auto-SSH Tunnels__

[TOC]

## Goals

### Unix Service

* monter les tunnel par `autossh` limité individuellement en bande passante par `trickle` ;
* l'ensemble des tunnels `SSH` présent dans les fichiers de conf doivent tous monter au démarrage de la machine sans intervention humaine. ;
* chaque tunnel sera indépendamment, maintenu et logué par le service ;
* chaque tunnel doit pouvoir être monté ou arrêté manuellement ;
* une liste et l'état des tunnel doit être consultable a la demande (service status) ;
* les logs seront séparé par tunnel ;
* le code sera ouvert et documenté. ;
* l'ensemble devra être packagé pour une mise en place facile.

### Web Interface

Dans un second temps il nous faudrait une interface web en 4 pages web:

* liste des sites (basé sur les fichiers de conf) et leur état (en couleur) ;
* ajout / suppression de site-tunnel ;
* liste des imps par site (basé sur les fichiers de conf) ;
* ajout / suppression d'imprimante par site-tunnel ;
* la mise en forme et le style graphique pour ces pages sera réduite au minimum ;
* le code sera ouvert et documenté. ;
* l'ensemble devra être packagé pour une mise en place facile.

## Requirements

* **Debian-based** OS: we are expecting a Debian `6.0+` or Ubuntu-server `12.04+` ;
* **bash** `4.x+`: the shell interpreter used for the service ;
* **wget**: to download project on repository ;
* **openssh**: this is an obvious dependency ;
* **gunzip**: to uncompress the downloaded package ;
* GNU **Make**: task manager used to install client/server, deploy add others stuff.

## Tasks management with `make` and the `makefile`

Makefile define so-called _tasks_, that allow user to easily run a complex sequence of command with a single call (e.g. `make install`).

### Tips and tricks

For administrator unfamiliar with `makefile` syntax, you need to be aware of the following:

* variables can be pass to the makefile script as follow: `make MY_VAR=123 taskname` ;
* the `$` (dollar sign) **must be escaped** if you want to have access to bash variable (e.g. ~~$HOME~~ → `$$HOME`) ;
* multilines commands should end with a `\` (backslash). In a similar fashion than `bash` ;
* the `@` (at sign) is use to prevent a command to be printed prior to execution. If you want to see what commands the task really executed, with variables expanded, simply remote the `@`-sign from the beginning of the line :).

## Installation

You must get the project on both the customer's node and your infrastructure:

```bash
git clone --depth 1 https://github.com/edouard-lopez/mast.git && cd mast
```
Then you can type:
```bash
make
```

### Checking your system

After getting the project source code, you can check your system status for requirements using :

```bash
make check-system
```
Once the system is ready for the service, you should get the following output:
```text
Checking system…
	autossh Installed
	openssh-client  Installed
	openssh-server  Installed
	trickle Installed
	useradd Installed
```

### Installing on Server

Install required packages (`openssh-client`, `trickle`, ...).

```bash
make setup-infra
```

#### Using `systemd` (experimental)

The use of `systemd` is not widespread yet. However, is planned to become the default service manager on future release of numerous Linux distributions.
In order to support this on current LTS Ubuntu (12.04 and 14.04) we need an [additional PPA repository](https://launchpad.net/~pitti/+archive/systemd) and some [modification to the `GRUB` config](http://linuxg.net/how-to-install-and-test-systemd-on-ubuntu-14-04-trusty-tahr-and-ubuntu-12-04-precise-pangolin/)[^systemd-on-ubuntu].

```bash
make install-systemd
```

#### Deploying service and daemon

This task copy project file to their adequate location (_i.e._ `/etc/init.d/`, `/usr/sbin/`, `/etc/systemd/system/`)
```bash
make deploy-service
```

### Creating SSH Key

Create SSH keys pair on infrastructure to allow friction-less connection to the customer's node.

```bash
make create-ssh-key
```

### Deploying SSH Key

Once the ssh keys are created we need to copy the public key on the (remote) customer's node, in order to leverage authentication mechanism.

```bash
make deploy-key
```

If the customer's node address differ from the default value (see `REMOTE_SRV` in the _makefile_), the new value must be passed **as an argument**

```bash
make REMOTE_SRV=11.22.33.44 deploy-key
```

**Note:** This task require `create-ssh-key` to be done, this mean you can directly call the `deploy-key` task and it will trigger the `create-ssh-key` if needed

## Service

### Service file^[service-file]

* The `[Unit]` section contains generic information about the service. `systemd` not only manages system services, but also devices, mount points, timer, and other components of the system.
* `[Service]` section encodes information about the service itself. It contains all those settings that apply only to services, and not the other kinds of units `systemd` maintains (mount points, devices, timers, ...)
* [Install]` section encodes information about how the suggested installation should look like, _i.e._ under which circumstances and by which triggers the service shall be started. In this case we simply say that this service shall be started when the multi-user.target unit is activated

### Don't kill me, I have kids!
Check if tunnels are children of the service. If this is the case, that means that killing the service will kill **all** tunnels.

## Configuration File

The configuration files used by `mast` are located in the `$CONFIG_DIR` directory as defined in the _makefile_ (default path is `/etc/mast/`). 
Those files are dynamically generated using the `make add-host` and use the _template_ file as skeleton. Each configuration describe parameters for a given host and most configuration should not be tampered with.

Below is a list of available parameters and their roles:

| Parameter  | Default | Description |
| ------------- | ------------- | ------------- |
| `RemoteHost` | _HOST_ | **_string_**.<br> [FQDN](https://en.wikipedia.org/wiki/FQDN) or IP address of the customer's node. |
| `RemoteUser` | _coaxis_ | **_string_**.<br> Unix' username on the customer's node. |
| `RemotePort` | `22` | **_integer_**.<br> SSH port on the customer's node. |
| `ServerAliveInterval` | `10` | **_integer_**.<br> Sets a timeout interval in seconds[^manpage-ssh-config] after which if no data has been received from the server, `ssh` will send a message through the encrypted channel to request a response from the server. |
| `ServerAliveCountMax` | `3` | **_integer_**.<br> Sets the number of server alive messages which may be sent without `ssh` receiving any messages back from the server.[^manpage-ssh-config] |
| `StrictHostKeyChecking` | _no_ | **_string_**.<br> If this flag is set to _no_, `ssh` will automatically add new host keys to the user known hosts files.[^manpage-ssh-config] |
| `LocalUser` | _root_ | **_string_**.<br> The user on the local machine that will be used to create the tunnel.[^js-morisset] |
| `IdentityFile` | _~/.ssh/id_rsa.mast.coaxis_ | **_string_**.<br> Path to local SSH public key, so we can connect automatically to customer's node. |
| `ForwardPort` | `"L *:9100:imp1:9100"`<br>`"L *:9101:imp2:9100"` | **_array_**.<br>`L [bind_address:]port:host:hostport` Specifies that the given port on the local (client) host is to be forwarded to the given host and port on the remote side.<br>`R [bind_address:]port:host:hostport` Specifies that the given port on the remote (server) host is to be forwarded to the given host and port on the local side. |
| `BandwidthLimitation` | `true` | **_boolean_**.<br> Flag to toggle  traffic limitation.<br>`true`: enable limitation or <br>`false`: disable. |
| `UploadLimit` | `1000` | **_integer_**.<br> Upper limit for _upload_ traffic (customer's node is the source of traffic). |
| `DownloadLimit` |`100` | **_integer_**.<br> Upper limit for _download_ traffic. |

### References

* [^service-file]: [How Do I Convert A SysV Init Script Into A systemd Service File?](http://0pointer.de/blog/projects/systemd-for-admins-3.html)
* [^systemd-on-ubuntu]: [How To Install And Test Systemd On Ubuntu 14.04 Trusty Tahr And Ubuntu 12.04 Precise Pangolin.](http://linuxg.net/how-to-install-and-test-systemd-on-ubuntu-14-04-trusty-tahr-and-ubuntu-12-04-precise-pangolin/)
* [^manpage-ssh-config]: [Manual for OpenSSH SSH **client configuration files**.](http://manpages.ubuntu.com/manpages/precise/en/man5/ssh_config.5.html)
* [^js-morisset]: [Autossh Startup Script for Multiple Tunnels.](http://surniaulula.com/2012/12/10/autossh-startup-script-for-multiple-tunnels/)
* [^manpage-ssh-client]: [Manual for OpenSSH SSH **client**.](http://manpages.ubuntu.com/manpages/precise/en/man1/ssh.1.html)
