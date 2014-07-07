#!/usr/bin/env make
# DESCRIPTION
#	Project utility to install client/server, deploy, etc.
#
# USAGE
#	curl -L http://git.edouard-lopez.com:81/root/mast.git/raw/master/makefile | make -f -
#
# AUTHOR
#	Édouard Lopez <dev+mast@edouard-lopez.com>

ifneq (,)
This makefile requires GNU Make.
endif

# force use of Bash
SHELL := /bin/bash


# Install packages required on the SERVER
install-server:
	@printf "Installing…\n"
	# ssh  = virtual-package
	apt-get install openssh-server ssh-server trickle