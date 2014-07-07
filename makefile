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