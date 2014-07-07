# MAST

**MAST** is a project to setup a Linux service to mount __Multiple Auto-SSH Tunnels__

## Requirements

* **Debian-based** OS: we are expecting a Debian `6.0+` or Ubuntu-server `12.04+` ;
* **bash** `4.x+`: the shell interpreter used for the service ;
* **autoSSH**: to start and monitor ssh tunnels ;
	* **openssh-client**: this is an obvious dependency ;
* **trickle**: user-space bandwidth shaper ;
* GNU **Make**: task manager used to install client/server, deploy add others stuff.

