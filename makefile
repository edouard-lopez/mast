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
setup-customer: install-customer
setup-infra: install-infra

deploy-service:
	cp mastd.service /etc/systemd/system/
	cp mastd {/usr/sbin/,/etc/init.d/}
	printf "Check deployment with:\n\tsystemctl daemon-reload\n"



# Copy infra public key on customer's node (defined by REMOTE_SRV)
deploy-key: create-ssh-key
	@printf "Deploying…\tSSH Keys to customer node\n"
	ssh-copy-id -i ${SSH_KEYFILE} ${REMOTE_USER}@${REMOTE_SRV}


# Create keys pair on infra
#@alias: create-ssh-key:
${SSH_KEYFILE}:
	@printf "Creating…\tSSH Keys\n"
	@ssh-keygen \
		-t rsa \
		-f ${SSH_KEYFILE}
		-N ${EMPTY} \
		-O permit-port-forwarding \
		-C "Automatically generated by MAST script"


# Install packages required on the Coaxis' INFRAstructure
install-infra:
	@printf "Installing…\tinfrastructure's node\n"
	apt-get install autossh openssh-client trickle bmon iftop htop

# Add PPA for Ubuntu 12.04, 14.04 and higher to leverage systemd
install-systemd:
	apt-get install openssh-server useradd
	add-apt-repository ppa:pitti/systemd
	apt-get update && apt-get dist-upgrade
	printf "You MUST update GRUB config\n"
	printf "\treading: http://linuxg.net/how-to-install-and-test-systemd-on-ubuntu-14-04-trusty-tahr-and-ubuntu-12-04-precise-pangolin/\n"
	printf "\tby editing GRUB_CMDLINE_LINUX_DEFAULT to \"init=/lib/systemd/systemd\"\n"

# Install packages required on the CUSTOMER's node
install-customer:
	@printf "Installing…\tcustomer's node\n"
	# ssh  = virtual-package

# Check system status for dependencies
check-system:
	@printf "Checking system…\n"
	@executables=( "autossh" "openssh-client" "openssh-server" "trickle" "useradd"); \
	if ! type dpkg-query &> /dev/null; then \
		printf "You *MUST* $(tput setaf 1)install 'dpkg'$(tput sgr0)\n"; \
		printf "\t→ $(tput setaf 7)apt-get install %s$(tput sgr0)\n" "dpkg"; \
		exit; \
	fi; \
	for e in $${executables[@]}; do \
		if ! $(dpkg-query -s "$$e") &> /dev/null; then \
			printf "\t%s\t$(tput setaf 1)Missing!$(tput sgr0)\n" "$$e"; \
			printf "\t\t→ $(tput setaf 7)apt-get install %s$(tput sgr0)\n" "$$e"; \
		else \
			printf "\t%s\t$(tput setaf 2)Installed$(tput sgr0)\n" "$$e"; \
		fi \
	done

# Display basic help. For further information refer to the docs http://github.com/edouard-lopez/mast/README.md
usage:
	@printf "Usage…\n"
	@printf "On infra:\n\tmake setup-infra\n"
	@printf "On customer:\n\tmake setup-customer\n"