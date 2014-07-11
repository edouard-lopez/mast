#!/usr/bin/env make
# DESCRIPTION
#	Project utility to install client/server, deploy, etc.
#
# USAGE
#	make REMOTE_SRV=255.255.255.255 deploy-key
#
# AUTHOR
#	Édouard Lopez <dev+mast@edouard-lopez.com>

ifneq (,)
This makefile requires GNU Make.
endif

# force use of Bash
SHELL := /bin/bash
# Passphrase MUST be empty to allow automation (no passphrase prompt)
EMPTY:=
# Path to the SSH keys pair (public key is suffixed by .pub). This follow the native d
SSH_KEYFILE:=$$HOME/.ssh/id_rsa.mast.coaxis
# default remote user
REMOTE_USER:=coaxis
# default remote hostname
REMOTE_SRV:=Srv-SSH_RN

default: usage
setup-client: install-client
setup-server: install-server

deploy-service:
	cp mastd.service /etc/systemd/system/
	cp mastd {/usr/sbin/,/etc/init.d/}
	printf "Check deployment with:\n\tsystemctl daemon-reload\n"



# Copy client public key on remote server (defined by REMOTE_SRV)
deploy-key: create-ssh-key
	@printf "Deploying…\tSSH Keys to remote server\n"
	ssh-copy-id -i ${SSH_KEYFILE} ${REMOTE_USER}@${REMOTE_SRV}


# Create keys pair on client
#@alias: create-ssh-key:
${SSH_KEYFILE}:
	@printf "Creating…\tSSH Keys\n"
	@ssh-keygen \
		-t rsa \
		-f ${SSH_KEYFILE}
		-N ${EMPTY} \
		-O permit-port-forwarding \
		-C "Automatically generated by MAST script"


# Install packages required on the CLIENT
install-client:
	@printf "Installing…\tclient\n"
	apt-get install autossh openssh-client ssh-client


# Install packages required on the SERVER
install-server:
	@printf "Installing…\tserver\n"
	# ssh  = virtual-package
	apt-get install openssh-server ssh-server trickle
	add-apt-repository ppa:pitti/systemd
	apt-get update && apt-get dist-upgrade
	printf "You MUST update GRUB config\n"
	printf "\treading: http://linuxg.net/how-to-install-and-test-systemd-on-ubuntu-14-04-trusty-tahr-and-ubuntu-12-04-precise-pangolin/\n"
	printf "\tby editing GRUB_CMDLINE_LINUX_DEFAULT to \"init=/lib/systemd/systemd\"\n"

usage:
	@printf "Usage…\n"
	@printf "On client:\n\tmake setup-client\n"
	@printf "On server:\n\tmake setup-server\n"