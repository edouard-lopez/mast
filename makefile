#!/usr/bin/env make
# DESCRIPTION
#	Project utility to install client/server, deploy, etc.
#
# USAGE
#	sudo make REMOTE_SRV=255.255.255.255 deploy-key
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

APP:=mast

# force use of Bash
SHELL := /bin/bash

# default remote hostname
REMOTE_SRV:=none
# Current customer's name config and host/ip to work with (add/delete)
NAME:=none
HOST:=none

# SSH tunnel configuration directory (a file per host)
CONFIG_DIR:=/etc/mast
# Log files directory
LOG_DIR:=/var/log/mast

# Passphrase MUST be empty to allow automation (no passphrase prompt)
EMPTY:=
# Path to the SSH keys pair (public key is suffixed by .pub).
SSH_KEYFILE:=$$HOME/.ssh/id_rsa.mast.coaxis

# webapp sources directory, cloned during install (deployed to /var/www/mast-web)
WEBAPP=mast-web
# location of served web app.
WEBAPP_DEST_DIR=/var/www/

# Project dependencies
DEPS_CORE_INFRA:=autossh openssh-client trickle apache2 sudo unzip aha
DEPS_CORE_CUSTOMER:=openssh-server
DEPS_UTILS:=bmon iftop htop
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Code source repository
WEBAPP_REPO:=https://github.com/edouard-lopez/mast-web.git
WEBAPP_ARCHIVE:=https://github.com/edouard-lopez/mast/archive/master.zip
# DEV ONLY
WEBAPP_REPO:=file://$(shell pwd)/../mast-web/.git
# Web app's hostname
APACHE_HOSTNAME:=mast.dev
# Path to apache config file
APACHE_SRC_CONF=${WEBAPP}/resources/server/mast-web.apache.conf
APACHE_DEST_CONF=/etc/apache2/sites-enabled/${WEBAPP}.conf

# Branch to checkout before deploying webapp
WEBAPP_BRANCH=dev

default: usage
setup-customer: install-customer
setup-infra: install-infra
create-ssh-key: ${SSH_KEYFILE}


.PHONY: deploy-key \
install-customer \
remove-host \
usage \
add-host \
list-host \
list-logs \
config-ssh \
install-infra \
setup-customer \
check-system \
check-privileges \
create-ssh-key \
default \
install-systemd \
setup-infra


# List all log files, one for each tunnel
list-logs:
	@printf "Listing hosts…\n"
	@for log in "${LOG_DIR}/${APP}"-*.log; do \
		fn="$$(basename "$$log")"; \
		[[ ! -f $$log || -d $$log || $fn == "template" ]] && continue; \
		printf "\t%-50s%s\n" $$'$(call _VALUE_,'"$$fn"$$')' $$'$(call _INFO_,'"$$log"$$')'; \
	done


# List all hosts available to the service
list-host:
	@printf "Listing hosts…\n"
	@for fn in ${CONFIG_DIR}/*; do \
		h=$$(basename "$$fn"); \
		[[ $$h == "template" ]] && continue; \
		remoteHost="$$(grep RemoteHost "$$fn" | tr -d ' \"' | cut -d '=' -f 2 )"; \
		printf "\t* %s (%s)\n" $$'$(call _VALUE_,'$$h$$')' $$'$(call _INFO_,'"$$remoteHost"$$')'; \
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
		sed -i 's/{{HOST}}/${HOST}/g' ${CONFIG_DIR}/${NAME}; \
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
	@printf "Uninstalling…\n"
	@filesList=( \
		/etc/systemd/system/mastd.service \
		/etc/init.d/mast \
		/usr/sbin/mastd \
		"${CONFIG_DIR}"/* \
		"${CONFIG_DIR}" \
		/etc/apache2/sites-enabled/${WEBAPP}.conf \
		${LOG_DIR} \
		${WEBAPP_DEST_DIR}/mast-web \
		mast-web \
	); for fn in "$${filesList[@]}"; do \
		[[ -f $$fn || -d $$fn ]] || continue; \
		rm -rf "$$fn" && printf "\t%-50s%s\n" $$'$(call _VALUE_,'$$fn$$')' $$'$(call _SUCCESS_, done)'; \
	done
	@update-rc.d -f mast remove > /dev/null
	@printf "\n"

# deploy the webapp, configure apache, /etc/hosts
deploy-webapp:
	@printf "Deploying…\t%s\n" $$'$(call _VALUE_,webapp)'

	@# cloning repository
	@if [[ ! -f ${WEBAPP}/.git && ! -d ${WEBAPP}/.git ]]; \
		then \
			if type git > /dev/null; then \
				printf "\t%-50s" $$'$(call _INFO_,cloning repository)'; \
				git clone --depth 1 --quiet ${WEBAPP_REPO} > /dev/null; \
			else \
				printf "\t%-50s" $$'$(call _INFO_,fetching)'; \
				wget --output-document="${WEBAPP}.zip" ${WEBAPP_ARCHIVE}; \
				unzip "${WEBAPP}.zip"; \
			fi \
		elif [[ -f ${WEBAPP}/.git || -d ${WEBAPP}/.git ]]; then \
			printf "\t%-50s" $$'$(call _INFO_,updating repository)'; \
			pushd "${WEBAPP}" \
				&& git pull ${WEBAPP_REPO} > /dev/null; \
			popd; \
				git checkout --quiet ${WEBAPP_BRANCH} > /dev/null \
					&& printf "$(call _SUCCESS_, done)" \
		else \
			printf "%s (already existing)\n" $$'$(call _WARNING_,skipped)'; \
		fi; \
		chmod u=rwx,g=rwx,o= -R "${WEBAPP}/"; \
		chown $${USER}:www-data -R "${WEBAPP}/"
	@printf "\t%s\n" $$'$(call _DEBUG_,${WEBAPP_REPO})'

	@# deploying webapp: /var/www/mast
	@printf "\t%-50s" $$'$(call _INFO_,deploying webapp)'
		@cp -R --preserve=all ${WEBAPP} ${WEBAPP_DEST_DIR} \
			&& printf "$(call _SUCCESS_, done)" \
			|| printf "$(call _ERROR_, fail)"
	@printf "\t%s\n" $$'$(call _DEBUG_,${WEBAPP_DEST_DIR}/${WEBAPP})'

	@# configuring Apache: /etc/apache2/sites-enabled/mast-web.conf
	@printf "\t%-50s" $$'$(call _INFO_,configuring Apache)'
		@a2enmod php5 rewrite vhost_alias &> /dev/null  # enable Apache module
		@cp ${APACHE_SRC_CONF} ${APACHE_DEST_CONF} \
			&& printf "$(call _SUCCESS_, done)" \
			|| printf "$(call _ERROR_, fail)"
		@printf "\t%s\n" $$'$(call _DEBUG_,${APACHE_DEST_CONF})'

	@# declaring hostname: /etc/hosts
	@printf "\t%-50s" $$'$(call _INFO_,declaring hostname)'
		@if ! grep -iq 'mast' /etc/hosts; then \
			printf '%s\n' H 1i "127.0.0.1 ${APACHE_HOSTNAME} www.${APACHE_HOSTNAME}" . w | ed -s /etc/hosts; \
			printf '%s\n' H 1i "# Mast-web" . w | ed -s /etc/hosts; \
			printf "%s" $$'$(call _SUCCESS_, done)'; \
			printf "\t%s\n" $$'$(call _DEBUG_,/etc/hosts)'; \
		else \
			printf "%s\t%s" $$'$(call _WARNING_, skipped)'; \
			printf "%s\n" $$'$(call _DEBUG_,/etc/hosts already existing)'; \
		fi

	@# reloading Apache
	@printf "\t%-50s" $$'$(call _INFO_,reloading Apache)'
		@if apache2ctl configtest &> /dev/null; then \
				apache2ctl graceful; \
				printf "$(call _SUCCESS_, done)\n"; \
				printf "\t%-50s%s\n" $$'$(call _SUCCESS_,test installation using)' $$'$(call _VALUE_, http://mast.dev/)'; \
			else \
				printf "$(call _ERROR_, failed)"; \
				printf "\t%s\n" $$'$(call _DEBUG_,${WEBAPP_DEST_DIR}/${WEBAPP})'; \
				apache2ctl configtest; \
			fi

	@printf "\n"


deploy-service:
	@printf "Deploying… %s\n" $$'$(call _VALUE_,service)'
	@printf "\t%-50s" $$'$(call _INFO_, systemd service…)'
		@cp mastd.service /etc/systemd/system/ \
		&& printf "$(call _SUCCESS_, done)\n" || printf "$(call _ERROR_, error)\n"

	@printf "\t%-50s" $$'$(call _INFO_, initd service…)'
		@rm -f /etc/init.d/mast \
		&& cp mast /etc/init.d/ \
		&& printf "$(call _SUCCESS_, done)\n" || printf "$(call _ERROR_, error)\n"
		@chown www-data /etc/init.d/mast
		@update-rc.d mast defaults > /dev/null

	@printf "\t%-50s" $$'$(call _INFO_, daemon…)'
		@rm -f /usr/sbin/mastd \
		&& cp mastd /usr/sbin/ \
		&& printf "$(call _SUCCESS_, done)\n" || printf "$(call _ERROR_, error)\n"

	@printf "\t%-50s%s\n" $$'$(call _INFO_, config directory…)' $$'$(call _VALUE_, ${CONFIG_DIR}/)'
		@[[ ! -d "${CONFIG_DIR}" ]] && mkdir "${CONFIG_DIR}" || printf "";

	@printf "\t%-50s%s\n" $$'$(call _INFO_, template…)' $$'$(call _VALUE_, ${CONFIG_DIR}/template)'
		@rm -f ${CONFIG_DIR}/template && cp {.,${CONFIG_DIR}}/template

	@printf "\t%-50s%s\n" $$'$(call _INFO_, log directory…)' $$'$(call _VALUE_, ${LOG_DIR}/)'
		@[[ ! -d "${LOG_DIR}" ]] && mkdir "${LOG_DIR}" || true
		@chown www-data -R "${LOG_DIR}" && chmod u=rwx,g=rwx "${LOG_DIR}"

deploy: deploy-service deploy-webapp

config-ssh: deploy-key

# Copy infra public key on customer's node (defined by REMOTE_SRV)
deploy-key: create-ssh-key
	@printf "Deploying…\t%s\n" $$'$(call _VALUE_, public key)'
	@printf "\t%-50s%s\n" $$'$(call _INFO_, copy public key to)' $$'$(call _VALUE_, ${REMOTE_USER}@${REMOTE_SRV})'
	@ssh-copy-id -i ${SSH_KEYFILE} ${REMOTE_USER}@${REMOTE_SRV} > /dev/null
	@printf "\n"


# Create keys pair on infra
#@alias: create-ssh-key:
${SSH_KEYFILE}:
	@printf "Creating… %s\n" $$'$(call _VALUE_,SSH keys)'
	@printf "\t%-50s%s" $$'$(call _INFO_, removing existing key)'
		@rm -f ${SSH_KEYFILE}{,.pub} \
			&& printf "%s\n" $$'$(call _SUCCESS_, done)' \
			|| printf "%s\n" $$'$(call _ERROR_, failed)'
	@printf "\t%-50s%s" $$'$(call _INFO_, generating key)'
		@ssh-keygen -q \
			-t rsa \
			-b 4096 \
			-f "${SSH_KEYFILE}" \
			-N "${EMPTY}" \
			-O permit-port-forwarding \
			-C "Automatically generated by MAST script" \
			&& printf "%s\n" $$'$(call _SUCCESS_, done)' \
			|| printf "%s\n" $$'$(call _ERROR_, failed)'

# Install packages required on the Coaxis' INFRAstructure
install-infra:
	@printf "Installing…\t%s\n" $$'$(call _VALUE_, infrastructure\'s node)'
	apt-get install ${DEPS_CORE_INFRA} ${DEPS_UTILS}

# Add PPA for Ubuntu 12.04, 14.04 and higher to leverage systemd
install-systemd:
	apt-get install openssh-server
	add-apt-repository ppa:pitti/systemd
	apt-get update && apt-get dist-upgrade
	printf "You MUST update GRUB config\n"
	printf "\treading: http://linuxg.net/how-to-install-and-test-systemd-on-ubuntu-14-04-trusty-tahr-and-ubuntu-12-04-precise-pangolin/\n"
	printf "\tby editing GRUB_CMDLINE_LINUX_DEFAULT to \"init=/lib/systemd/systemd\"\n"

# Install packages required on the CUSTOMER's node
install-customer:
	@printf "Installing…\t%s\n" $$'$(call _VALUE_, customer\'s node)'
	apt-get install -y ${DEPS_CORE_CUSTOMER} ${DEPS_UTILS}


# Check files permission
check-privileges:
	@[[ ! -d ${LOG_DIR} ]] && mkdir "${LOG_DIR}"
	@chown www-data -R "${LOG_DIR}"
	@chmod u=rwx,g=rwx "${LOG_DIR}"


# Check system status for dependencies
check-system:
	@printf "Checking system…\n"
	@executables=( ${DEPS_CORE_INFRA} ${DEPS_CORE_CUSTOMER} ${DEPS_UTILS} ); \
	if ! type dpkg-query &> /dev/null; then \
		printf "You *MUST* install 'dpkg'\n"; \
		printf "\t→ %s %s\n" $$'$(call _VALUE_, apt-get install dpkg)'; \
		exit; \
	fi; \
	for e in $${executables[@]}; do \
		printf "\t%-50s" $$'$(call _VALUE_, '$$e$$')'; \
		if ! dpkg-query -s "$$e" &> /dev/null; then \
			printf "%12s\t" $$'$(call _ERROR_, missing)'; \
			printf "→ %s %s\n" $$'$(call _INFO_, apt-get install '$$e $$')'; \
		else \
			printf "%-12s\n" $$'$(call _SUCCESS_,installed)'; \
		fi \
	done

# Display basic help. For further information refer to the docs http://github.com/edouard-lopez/mast/README.md
usage:
	@printf "Usage…\n"
	@printf "\t%s: both commands require %s privilieges.\n" $$'$(call _WARNING_, warning)' $$'$(call _VALUE_,sudo)'
	@printf "\n"
	@printf "\t * %-50s%s\n" $$'$(call _INFO_,on infrastructure)' $$'$(call _VALUE_, make setup-infra)'
	@printf "\t * %-50s%s\n" $$'$(call _INFO_,on customer\'s node)' $$'$(call _VALUE_, make setup-customer)'


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
# blue/information
__DEBUG__=\e[0;37m
# red/error
__ERROR__=\e[1;31m
# yellow/warning
__WARNING__=\e[0;33m
# value/purple
__VALUE__=\e[0;35m

# Colours function helpers
_SUCCESS_=$(__SUCCESS__)$(1)$(__RESET__)
_INFO_=$(__INFO__)$(1)$(__RESET__)
_DEBUG_=$(__DEBUG__)$(1)$(__RESET__)
_ERROR_=$(__ERROR__)$(1)$(__RESET__)
_WARNING_=$(__WARNING__)$(1)$(__RESET__)
_VALUE_=$(__VALUE__)$(1)$(__RESET__)
# messages helper
_OK_=$(call _SUCCESS_, ok)


