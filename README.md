# MAST

**MAST** is a project to setup a Linux service to mount __Multiple Auto-SSH Tunnels__

<!-- MarkdownTOC depth=3 -->

- Requirements
- Tasks management with `make` and the `makefile`
- Service
	- Don't kill me, I have kids!

<!-- /MarkdownTOC -->

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

## Service

### Don't kill I have kids!

Check if tunnels are children of the service. If this is the case, that means that killing the service will kill **all** tunnels.
