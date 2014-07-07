#!/usr/bin/env make
# DESCRIPTION
#	Project utility to install client/server, deploy, etc.
#
# USAGE
#	make SRV_REMOTE=255.255.255.255 deploy-key
#
# AUTHOR
#	Édouard Lopez <dev+mast@edouard-lopez.com>

ifneq (,)
This makefile requires GNU Make.
endif

# force use of Bash
SHELL := /bin/bash
# Path to the SSH keys pair (public key is suffixed by .pub). This follow the native d
SSH_KEYFILE:=$$HOME/.ssh/id_rsa.mast.coaxis
# default remote user
REMOTE_USER:=coaxis
# default remote hostname
REMOTE_SRV:=Srv-SSH_RN



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
	@printf "Installing…\n"
	apt-get install autossh openssh-client ssh-client

# Install packages required on the SERVER
install-server:
	@printf "Installing…\n"
	# ssh  = virtual-package
	apt-get install openssh-server ssh-server trickle

usage:
	@printf "Usage…\n"
	@printf "On client:\n\tmake setup-client\n"
	@printf "On server:\n\tmake setup-server\n"