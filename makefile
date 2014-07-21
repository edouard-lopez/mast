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

# Contains a file-per-host SSH's config.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Do NOT edit this section
CONFIG_DIR:=/etc/mast
# Current customer's name config and host/ip to work with (add/delete)
CUSTOMER_NAME:=none
CUSTOMER_HOST:=none
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

default: usage
setup-customer: install-customer
setup-infra: install-infra
create-ssh-key: ${SSH_KEYFILE}


.PHONY: deploy-key \
install-customer \
remove-host \
usage \
add-host \
config-ssh \
install-infra \
setup-customer \
check-system \
create-ssh-key \
default \
install-systemd \
setup-infra


# Adding a new host/customer require a
add-host:
	if [[ ${CUSTOMER_NAME} != "none" ]]; then \
		cp ${CONFIG_DIR}/{template,${CUSTOMER_NAME}}; \
		sed -i 's/CUSTOMER_HOST/${CUSTOMER_HOST}/g' ${CONFIG_DIR}/${CUSTOMER_NAME}; \
	fi
	@printf "Editing…\t%s\n" "$(call _VALUE_, ${CONFIG_DIR}/${CUSTOMER_NAME})"
	sleep 3s;
	editor ${CONFIG_DIR}/${CUSTOMER_NAME}
	@printf "You *must* start the tunnel manually:\n\tsudo /etc/init.d/mast start %s\n" "${CUSTOMER_NAME}"



deploy-service:
	@printf "Deploying… \n"
	@printf "\tSystemd service…\t"
		@cp mastd.service /etc/systemd/system/ \
		&& printf "$(call _SUCCESS_, installed)" || printf "$(call _ERROR_, error)"
	@printf "\tInitd service…\t\t"
		@rm -f /etc/init.d/mast \
		&& cp mast /etc/init.d/ \
		&& printf "$(call _SUCCESS_, installed)" || printf "$(call _ERROR_, error)"
	@printf "\tDaemon…\t\t\t"
		@rm -f /usr/sbin/mastd \
		&& cp mastd /usr/sbin/ \
		&& printf "$(call _SUCCESS_, installed)" || printf "$(call _ERROR_, error)"
	@printf "\tConfig directory… \t%s" $$'$(call _VALUE_, ${CONFIG_DIR})'
		@[[ ! -d ${CONFIG_DIR} ]] && mkdir ${CONFIG_DIR} || printf "";
	@printf "\tTemplate… \t\t%s" $$'$(call _VALUE_, ${CONFIG_DIR}/template)'
		@rm -f ${CONFIG_DIR}/template && cp {.,${CONFIG_DIR}}/template

config-ssh: create-ssh-key deploy-key
	@printf "Configuring…\t%s\n" $$'$(call _SUCCESS_, installed)'

# Copy infra public key on customer's node (defined by REMOTE_SRV)
deploy-key: create-ssh-key
	@printf "Deploying…\t%s\n" $$'$(call _SUCCESS_, SSH Keys to customer node)'
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
	@printf "Installing…\t%s\n" $$'$(call _VALUE_, infrastructure\'s node)'
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
	@printf "Installing…\t%s\n" $$'$(call _VALUE_, customer\'s node)'

# Check system status for dependencies
check-system:
	@printf "Checking system…\n"
	@executables=( autossh openssh-client openssh-server trickle useradd add-apt-repository); \
	if ! type dpkg-query &> /dev/null; then \
		printf "You *MUST* install 'dpkg'\n"; \
		printf "\t→ %s %s\n" $$'$(call _VALUE_, apt-get install dpkg)"; '
		exit; \
	fi; \
	for e in $${executables[@]}; do \
		if ! $(dpkg-query -s "$$e") &> /dev/null; then \
			printf "\t%s\t%s\n" "$$e" $$'$(call _ERROR_, Missing!)"; '
			printf "\t\t→ %s %s\n" $$'$(call _VALUE_, apt-get install $$e)"; '
		else \
			printf "\t%s\t%s\n" "$$e" $$'$(call _SUCCESS_, installed)"; '
		fi \
	done

# Display basic help. For further information refer to the docs http://github.com/edouard-lopez/mast/README.md
usage:
	@printf "Usage…\n"
	@printf "On infra:\n\t%s\n" $$'$(call _VALUE_, make setup-infra)'
	@printf "On customer:\n\t%s\n" $$'$(call _VALUE_, make setup-customer)'


# Coloring constants
NO_COLOR=\x1b[0m
OK_COLOR=\x1b[32;01m
ERROR_COLOR=\x1b[31;01m
WARN_COLOR=\x1b[33;01m

# Reset
__RESET__=\e[0m
# valid/green
__SUCCESS__=\e[0;32m
# blue/information
__INFO__=\e[0;36m
# red/error
__ERROR__=\e[1;31m
# yellow/warning
__WARNING__=\e[0;33m
# value/purple
__VALUE__=\e[0;35m

# Colours function helpers
_SUCCESS_=$(__SUCCESS__)$(1)$(__RESET__)\n
_INFO_=$(__INFO__)$(1)$(__RESET__)\n
_ERROR_=$(__ERROR__)$(1)$(__RESET__)\n
_WARNING_=$(__WARNING__)$(1)$(__RESET__)\n
_VALUE_=$(__VALUE__)$(1)$(__RESET__)\n
# messages helper
_OK_=$(call _SUCCESS_, ok)


