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


# default remote user
REMOTE_USER:=coaxis

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# DO NOT EDIT.
# Below are CRITICAL SETTINGS for the application.
# Seriously, otherwise you VOID THE SUPPORT AND WARRANTY contract.

# force use of Bash
SHELL := /bin/bash

# default remote hostname
REMOTE_SRV:=none
# Current customer's name config and host/ip to work with (add/delete)
NAME:=none
HOST:=none

# Contains a file-per-host SSH's config.
CONFIG_DIR:=/etc/mast
# Log files directory
LOG_DIR:=/var/log/mast

# Passphrase MUST be empty to allow automation (no passphrase prompt)
EMPTY:=
# Path to the SSH keys pair (public key is suffixed by .pub).
SSH_KEYFILE:=$$HOME/.ssh/id_rsa.mast.coaxis

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


list-host:
	@printf "Listing hosts…\n"
	@for fn in ${CONFIG_DIR}/*; do \
		h=$$(basename "$$fn"); \
		[[ "$$h" == "template" ]] && continue; \
		rhost="$$(grep RemoteHost "$$fn" | tr -d '\"' | cut -d '=' -f 2 )"; \
		printf "\t* $(call _VALUE_,$$h) ($(call _INFO_,$$rhost))\n"; \
	done

# Adding a new host config require to provide it's NAME and HOST
# @require: NAME
# @require: HOST
add-host:
	@printf "Adding host…\n"
	@if [[ "${NAME}" == "none" || -z "${NAME}" || "${HOST}" == "none" || -z "${HOST}" ]]; then \
		printf "\t%s or %s.\n" $$'$(call _ERROR_,missing HOST)' $$'$(call _ERROR_,NAME)'; \
		exit 0; \
	elif [[ "${NAME}" != "none" ]]; then \
		cp ${CONFIG_DIR}/{template,${NAME}}; \
		sed -i 's/HOST/${HOST}/g' ${CONFIG_DIR}/${NAME}; \
		while true; do \
			read -p "$(shell printf "\tEditing…\t%s? [y/n]\n" $$'$(call _VALUE_, ${CONFIG_DIR}/${NAME})')" yn; \
			case $$yn in \
				[Yy]* ) \
					editor ${CONFIG_DIR}/${NAME}; \
					printf "\nYou must %s the tunnel with:\n\t%s %s\n" $$'$(call _WARNING_,start –manually–)' $$'$(call _INFO_,sudo /etc/init.d/mast start ${NAME})'; \
					break;; \
				[Nn]* ) \
					printf "\t%s\n" $$'$(call _INFO_,Skipping)'; \
					exit;; \
				* ) \
					printf "\t\tAnswer by %s or %s.\n" $$'$(call _VALUE_,yes)' $$'$(call _VALUE_,no)';; \
			esac; \
		done; \
	else \
		printf "Missing customer name…\t%s\n" "${NAME}"; \
	fi

remove-host:
	@printf "Removing host…\n\t%s\t\t" $$'$(call _VALUE_, ${NAME})'
	@if [[ "${NAME}" == "none" || -z "${NAME}" ]]; then \
		printf "%s host\'s NAME.\n" $$'$(call _WARNING_, invalid)'; \
	elif [[ ! -e "${CONFIG_DIR}/${NAME}" ]]; then \
		printf "does %s.\n" $$'$(call _WARNING_,not exist)'; \
	elif [[ ! -f "${CONFIG_DIR}/${NAME}" ]]; then \
		printf "%s host\'s file.\n" $$'$(call _WARNING_, invalid)'; \
	else \
		rm -f "${CONFIG_DIR}/${NAME}" && printf "$(call _SUCCESS_, done)" || printf "$(call _ERROR_, error)"; \
	fi


uninstall:
	rm -f \
		/etc/systemd/system/mastd.service \
		/etc/init.d/mast \
		/usr/sbin/mastd \
		"${CONFIG_DIR}"/* \
		"${CONFIG_DIR}"

deploy-service:
	@printf "Deploying… \n"
	@printf "\tSystemd service…\t"
		@cp mastd.service /etc/systemd/system/ \
		&& printf "$(call _SUCCESS_, installed)\n" || printf "$(call _ERROR_, error)\n"
	@printf "\tInitd service…\t\t"
		@rm -f /etc/init.d/mast \
		&& cp mast /etc/init.d/ \
		&& printf "$(call _SUCCESS_, installed)\n" || printf "$(call _ERROR_, error)\n"
	@printf "\tDaemon…\t\t\t"
		@rm -f /usr/sbin/mastd \
		&& cp mastd /usr/sbin/ \
		&& printf "$(call _SUCCESS_, installed)\n" || printf "$(call _ERROR_, error)\n"
	@printf "\tConfig directory… \t%s" $$'$(call _VALUE_, ${CONFIG_DIR})'
		@[[ ! -d "${CONFIG_DIR}" ]] && mkdir "${CONFIG_DIR}" || printf "\n";
	@printf "\tTemplate… \t\t%s\n" $$'$(call _VALUE_, ${CONFIG_DIR}/template)'
		@rm -f ${CONFIG_DIR}/template && cp {.,${CONFIG_DIR}}/template
	@printf "\tLog directory…\t\t%s\n" $$'$(call _VALUE_, ${LOG_DIR}/)'
		@[[ ! -d "${LOG_DIR}" ]] && mkdir "${LOG_DIR}" || printf "\n";

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
		-b 4096 \
		-f "${SSH_KEYFILE}" \
		-N "${EMPTY}" \
		-O permit-port-forwarding \
		-C "Automatically generated by MAST script"


# Install packages required on the Coaxis' INFRAstructure
install-infra:
	@printf "Installing…\t%s\n" $$'$(call _VALUE_, infrastructure\'s node)'
	apt-get install autossh openssh-client trickle bmon iftop htop useradd add-apt-repository

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
	apt-get install openssh-server bmon iftop htop useradd

# Check system status for dependencies
check-system:
	@printf "Checking system…\n"
	@executables=( autossh openssh-client openssh-server trickle useradd add-apt-repository); \
	if ! type dpkg-query &> /dev/null; then \
		printf "You *MUST* install 'dpkg'\n"; \
		printf "\t→ %s %s\n" $$'$(call _VALUE_, apt-get install dpkg)'; \
		exit; \
	fi; \
	for e in $${executables[@]}; do \
		if ! $(dpkg-query -s "$$e") &> /dev/null; then \
			printf "\t%s\t%s\n" "$$e" $$'$(call _ERROR_, Missing!)'; \
			printf "\t\t→ %s %s\n" $$'$(call _VALUE_, apt-get install $$e)'; \
		else \
			printf "\t%s\t\t\t%s\n" "$$e" $$'$(call _SUCCESS_, installed)'; \
		fi \
	done

# Display basic help. For further information refer to the docs http://github.com/edouard-lopez/mast/README.md
usage:
	@printf "Usage…\n"
	@printf "\t* on infra:\n\t\t%s\n" $$'$(call _VALUE_, make setup-infra)'
	@printf "\t* on customer:\n\t\t%s\n" $$'$(call _VALUE_, make setup-customer)'


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
_SUCCESS_=$(__SUCCESS__)$(1)$(__RESET__)
_INFO_=$(__INFO__)$(1)$(__RESET__)
_ERROR_=$(__ERROR__)$(1)$(__RESET__)
_WARNING_=$(__WARNING__)$(1)$(__RESET__)
_VALUE_=$(__VALUE__)$(1)$(__RESET__)
# messages helper
_OK_=$(call _SUCCESS_, ok)


