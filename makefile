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
DEPS_CORE_INFRA:=autossh openssh-client trickle apache2 libapache2-mod-php5 sudo unzip aha
DEPS_CORE_CUSTOMER:=openssh-server
DEPS_UTILS:=bmon iftop htop

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Code source repository
WEBAPP_REPO:=https://github.com/edouard-lopez/mast-web.git
WEBAPP_ARCHIVE:=https://github.com/edouard-lopez/mast-web/archive/master.zip
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
add-host \
list-host \
list-logs \
list-channels \
usage \
config-ssh \
install-infra \
setup-customer \
check-system \
check-privileges \
create-ssh-key \
default \
install-systemd \
setup-infra


# List channels for given host. If none is given, iterate over all hosts
# @optional: {string} NAME host's name
list-channels:
	@# if no config names (on the command-line), stop all autossh processes
	@if [[ -e "${CONFIG_DIR}/${NAME}" ]]; then \
		config=(  "${CONFIG_DIR}/${NAME}" ); \
	else \
		config=( "${CONFIG_DIR}"/* ); \
	fi; \
	for cfg in "$${config[@]}"; do \
		fn="$$(basename "$$cfg")"; \
		[[ $$fn == "template" ]] && continue; \
		printf "* %s\n" $$'$(call INFO,'"$$fn"$$')'; \
		source "$${cfg}"; \
		for fp in "$${ForwardPort[@]}"; do \
			! [[ $$fp =~ NEW_FORWARD_PORTS ]] && printf "\t%s\n" $$'$(call VALUE,'"$$fp"$$')' ; \
		done; \
	done


# List all log files, one for each tunnel
list-logs:
	@printf "Listing hosts…\n"
	@for log in "${LOG_DIR}/${APP}"-*.log; do \
		fn="$$(basename "$$log")"; \
		[[ ! -f $$log || -d $$log || $fn == "template" ]] && continue; \
		printf "\t%-50s%s\n" $$'$(call VALUE,'"$$fn"$$')' $$'$(call INFO,'"$$log"$$')'; \
	done


# List all hosts available to the service
list-host:
	@printf "Listing hosts…\n"
	@for fn in ${CONFIG_DIR}/*; do \
		h=$$(basename "$$fn"); \
		[[ $$h == "template" ]] && continue; \
		remoteHost="$$(grep RemoteHost "$$fn" | tr -d ' \"' | cut -d '=' -f 2 )"; \
		printf "\t%-50s (%s)\n" $$'$(call VALUE,'$$h$$')' $$'$(call INFO,'"$$remoteHost"$$')'; \
	done


# Adding a new host config require to provide it's NAME and HOST
# @require: {string} NAME host's name
# @require: {string} HOST  IP address or FQDN
add-host:
	@printf "Adding host…\n"
	@if [[ "${NAME}" == "none" || -z "${NAME}" || "${HOST}" == "none" || -z "${HOST}" ]]; then \
		printf "\t%s or %s.\n" $$'$(call ERROR,missing HOST)' $$'$(call ERROR,NAME)' 1>&2; \
		exit 0; \
	elif [[ "${NAME}" != "none" ]]; then \
		cp ${CONFIG_DIR}/{template,${NAME}}; \
		sed -i 's/{{HOST}}/${HOST}/g' ${CONFIG_DIR}/${NAME}; \
		while true; do \
			read -p "$(shell printf "\tEditing…\t%s? [y/n]\n" $$'$(call VALUE, ${CONFIG_DIR}/${NAME})')" yn; \
			case $$yn in \
				[Yy]* ) \
					editor ${CONFIG_DIR}/${NAME}; \
					printf "\nYou must %s the tunnel with:\n\t%s %s\n" $$'$(call WARNING,start –manually–)' $$'$(call INFO,sudo /etc/init.d/mast start ${NAME})' 1>&2; \
					break;; \
				[Nn]* ) \
					printf "\t%s\n" $$'$(call INFO,Skipping)'; \
					exit;; \
				* ) \
					printf "\t\tAnswer by %s or %s.\n" $$'$(call VALUE,yes)' $$'$(call VALUE,no)';; \
			esac; \
		done; \
	else \
		printf "Missing customer name…\t%s\n" "${NAME}"; \
	fi

remove-host:
	@printf "Removing host…\n\t%s\t\t" $$'$(call VALUE, ${NAME})'
	@if [[ "${NAME}" == "none" || -z "${NAME}" ]]; then \
		printf "%s host\'s NAME.\n" $$'$(call WARNING, invalid)' 1>&2; \
	elif [[ ! -e "${CONFIG_DIR}/${NAME}" ]]; then \
		printf "does %s.\n" $$'$(call WARNING,not exist)' 1>&2; \
	elif [[ ! -f "${CONFIG_DIR}/${NAME}" ]]; then \
		printf "%s host\'s file.\n" $$'$(call WARNING, invalid)' 1>&2; \
	else \
		rm -f "${CONFIG_DIR}/${NAME}" && printf "$(call SUCCESS, done)" || printf "$(call ERROR, error)" 1>&2; \
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
		rm -rf "$$fn" && printf "\t%-50s%s\n" $$'$(call VALUE,'$$fn$$')' $$'$(call SUCCESS, done)'; \
	done
	@update-rc.d -f mast remove > /dev/null
	@printf "\n"

# deploy the webapp, configure apache, /etc/hosts
deploy-webapp:
	@printf "Deploying…\t%s\n" $$'$(call VALUE,webapp)'

	@# cloning repository
	@if [[ ! -f ${WEBAPP}/.git && ! -d ${WEBAPP}/.git ]]; \
		then \
			if type git > /dev/null; then \
				printf "\t%-50s" $$'$(call INFO,cloning repository)'; \
				git clone --depth 1 --quiet ${WEBAPP_REPO} > /dev/null; \
			else \
				printf "\t%-50s" $$'$(call INFO,fetching)'; \
				wget --output-document="${WEBAPP}.zip" ${WEBAPP_ARCHIVE}; \
				unzip "${WEBAPP}.zip"; \
			fi \
		elif [[ -f ${WEBAPP}/.git || -d ${WEBAPP}/.git ]]; then \
			printf "\t%-50s" $$'$(call INFO,updating repository)'; \
			pushd "${WEBAPP}" \
				&& git pull ${WEBAPP_REPO} > /dev/null; \
			popd; \
				git checkout --quiet ${WEBAPP_BRANCH} > /dev/null \
					&& printf "$(call SUCCESS, done)" \
		else \
			printf "%s (already existing)\n" $$'$(call WARNING,skipped)' 1>&2; \
		fi; \
		chmod u=rwx,g=rwx,o= -R "${WEBAPP}/"; \
		chown $${USER}:www-data -R "${WEBAPP}/"
	@printf "\t%s\n" $$'$(call DEBUG,${WEBAPP_REPO})'

	@# deploying webapp: /var/www/mast
	@printf "\t%-50s" $$'$(call INFO,deploying webapp)'
		@cp -R --preserve=all ${WEBAPP} ${WEBAPP_DEST_DIR} \
			&& printf "$(call SUCCESS, done)" \
			|| printf "$(call ERROR, fail)"
	@printf "\t%s\n" $$'$(call DEBUG,${WEBAPP_DEST_DIR}/${WEBAPP})'

	@# configuring Apache: /etc/apache2/sites-enabled/mast-web.conf
	@printf "\t%-50s" $$'$(call INFO,configuring Apache)'
		@a2enmod php5 rewrite vhost_alias > /dev/null  # enable Apache module
		@cp ${APACHE_SRC_CONF} ${APACHE_DEST_CONF} \
			&& printf "$(call SUCCESS, done)" \
			|| printf "$(call ERROR, fail)"
		@printf "\t%s\n" $$'$(call DEBUG,${APACHE_DEST_CONF})'

	@# declaring hostname: /etc/hosts
	@printf "\t%-50s" $$'$(call INFO,declaring hostname)'
		@if ! grep -iq 'mast' /etc/hosts; then \
			printf '%s\n' H 1i "127.0.0.1 ${APACHE_HOSTNAME} www.${APACHE_HOSTNAME}" . w | ed -s /etc/hosts; \
			printf '%s\n' H 1i "# Mast-web" . w | ed -s /etc/hosts; \
			printf "%s" $$'$(call SUCCESS, done)'; \
			printf "\t%s\n" $$'$(call DEBUG,/etc/hosts)'; \
		else \
			printf "%s\t%s" $$'$(call WARNING, skipped)' 1>&2; \
			printf "%s\n" $$'$(call DEBUG,/etc/hosts already existing)'; \
		fi

	@# reloading Apache
	@printf "\t%-50s" $$'$(call INFO,reloading Apache)'
		@if apache2ctl configtest &> /dev/null; then \
				apache2ctl graceful; \
				printf "$(call SUCCESS, done)\n"; \
				printf "\t%-50s%s\n" $$'$(call SUCCESS,test installation using)' $$'$(call VALUE, http://mast.dev/)'; \
			else \
				printf "$(call ERROR, failed)"; \
				printf "\t%s\n" $$'$(call DEBUG,${WEBAPP_DEST_DIR}/${WEBAPP})'; \
				apache2ctl configtest; \
			fi

	@printf "\n"


deploy-service:
	@printf "Deploying… %s\n" $$'$(call VALUE,service)'
	@printf "\t%-50s" $$'$(call INFO, systemd service…)'
		@cp mastd.service /etc/systemd/system/ \
		&& printf "$(call SUCCESS, done)\n" || printf "$(call ERROR, error)\n" 1>&2

	@printf "\t%-50s" $$'$(call INFO, initd service…)'
		@rm -f /etc/init.d/mast \
		&& ln -nfs $$PWD/mast /etc/init.d/ \
		&& printf "$(call SUCCESS, done)\n" || printf "$(call ERROR, error)\n" 1>&2
		@chown www-data /etc/init.d/mast
		@update-rc.d mast defaults > /dev/null

	@printf "\t%-50s" $$'$(call INFO, daemon…)'
		@rm -f /usr/sbin/mastd \
		&& cp mastd /usr/sbin/ \
		&& printf "$(call SUCCESS, done)\n" || printf "$(call ERROR, error)\n" 1>&2

	@printf "\t%-50s" $$'$(call INFO, utils…)'
		@rm -f /usr/sbin/mast-utils \
		&& cp makefile /usr/sbin/mast-utils \
		&& printf "$(call SUCCESS, done)\n" || printf "$(call ERROR, error)\n" 1>&2

	@printf "\t%-50s%s" $$'$(call INFO, config directory…)'
		@if [[ ! -d "${CONFIG_DIR}" ]]; then \
			mkdir "${CONFIG_DIR}" \
				&& printf "%s\t%s\n" "$(call SUCCESS, done)" $$'$(call VALUE, ${CONFIG_DIR}/)' \
				|| printf "$(call ERROR, error)\n" 1>&2; \
		elif [[ -d "${CONFIG_DIR}" ]]; then \
			printf "%s\t%s\n" $$'$(call WARNING, skipped)' $$'$(call VALUE, ${CONFIG_DIR}/)'; \
		fi

	@printf "\t%-50s%s" $$'$(call INFO, template…)'
		@rm -f ${CONFIG_DIR}/template \
			&& cp {.,${CONFIG_DIR}}/template \
			&& chmod u=rw,go= template \
			&& printf "%s\t%s\n" $$'$(call WARNING, skipped)' $$'$(call VALUE, ${CONFIG_DIR}/template)' \
			|| printf "$(call ERROR, error)\n" 1>&2

	@printf "\t%-50s%s" $$'$(call INFO, log directory…)'
		@if [[ ! -d "${LOG_DIR}" ]]; then \
			mkdir "${LOG_DIR}" \
				&& printf "%s\t%s\n" "$(call SUCCESS, done)" $$'$(call VALUE, ${LOG_DIR}/)' \
				|| printf "$(call ERROR, error)\n" 1>&2; \
		elif [[ -d "${LOG_DIR}" ]]; then \
			printf "%s\t%s\n" $$'$(call WARNING, skipped)' $$'$(call VALUE, ${LOG_DIR}/)'; \
		fi
		@chown www-data -R "${LOG_DIR}" && chmod u=rwx,g=rwx "${LOG_DIR}"


deploy: deploy-service deploy-webapp

config-ssh: deploy-key

# Copy infra public key on customer's node (defined by REMOTE_SRV)
deploy-key: create-ssh-key
	@printf "Deploying…\t%s\n" $$'$(call VALUE, public key)'
	@printf "\t%-50s%s\n" $$'$(call INFO, copy public key to)' $$'$(call VALUE, ${REMOTE_USER}@${REMOTE_SRV})'
	@ssh-copy-id -i ${SSH_KEYFILE} ${REMOTE_USER}@${REMOTE_SRV} > /dev/null
	@printf "\n"


# Create keys pair on infra
#@alias: create-ssh-key:
${SSH_KEYFILE}:
	@printf "Creating… %s\n" $$'$(call VALUE,SSH keys)'
	@printf "\t%-50s%s" $$'$(call INFO, removing existing key)'
		@rm -f ${SSH_KEYFILE}{,.pub} \
			&& printf "%s\n" $$'$(call SUCCESS, done)' \
			|| printf "%s\n" $$'$(call ERROR, failed)'
	@printf "\t%-50s%s" $$'$(call INFO, generating key)'
		@ssh-keygen -q \
			-t rsa \
			-b 4096 \
			-f "${SSH_KEYFILE}" \
			-N "${EMPTY}" \
			-O permit-port-forwarding \
			-C "Automatically generated by MAST script" \
			&& printf "%s\n" $$'$(call SUCCESS, done)' \
			|| printf "%s\n" $$'$(call ERROR, failed)'

# Install packages required on the Coaxis' INFRAstructure
install-infra:
	@printf "Installing…\t%s\n" $$'$(call VALUE, infrastructure\'s node)'
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
	@printf "Installing…\t%s\n" $$'$(call VALUE, customer\'s node)'
	apt-get install ${DEPS_CORE_CUSTOMER} ${DEPS_UTILS}


# Check files permission
check-privileges:
	@[[ ! -d ${LOG_DIR} ]] && mkdir "${LOG_DIR}"
	@chown www-data -R "${LOG_DIR}"
	@chmod u=rwx,g=rwx "${LOG_DIR}"
	# open privileges to www-data
	chown www-data "$(_log-file  "$fn")"
	chmod u=rwx,g=rwx "$(_log-file  "$fn")"


# Check system status for dependencies
check-system:
	@printf "Checking system…\n"
	@executables=( ${DEPS_CORE_INFRA} ${DEPS_CORE_CUSTOMER} ${DEPS_UTILS} ); \
	if ! type dpkg-query &> /dev/null; then \
		printf "You *MUST* install 'dpkg'\n"; \
		printf "\t→ %s %s\n" $$'$(call VALUE, apt-get install dpkg)'; \
		exit; \
	fi; \
	for e in $${executables[@]}; do \
		printf "\t%-50s" $$'$(call VALUE, '$$e$$')'; \
		if ! dpkg-query -s "$$e" &> /dev/null; then \
			printf "%12s\t" $$'$(call ERROR, missing)'; \
			printf "→ %s %s\n" $$'$(call INFO, apt-get install '$$e $$')'; \
		else \
			printf "%-12s\n" $$'$(call SUCCESS,installed)'; \
		fi \
	done

# Display basic help. For further information refer to the docs http://github.com/edouard-lopez/mast/README.md
usage:
	@printf "Usage…\n"
	@printf "\t%s: both commands require %s privilieges.\n" $$'$(call WARNING, warning)' $$'$(call VALUE,sudo)' 1>&2
	@printf "\n"
	@printf "\t * %-50s%s\n" $$'$(call INFO,on infrastructure)' $$'$(call VALUE, make setup-infra)'
	@printf "\t * %-50s%s\n" $$'$(call INFO,on customer\'s node)' $$'$(call VALUE, make setup-customer)'


# Coloring constants
NO_COLOR=\x1b[0m
OK_COLOR=\x1b[32;01m
ERROR_COLOR=\x1b[31;01m
WARN_COLOR=\x1b[33;01m

# Reset
_RESET_=\e[0m
# valid/green
_SUCCESS_=\e[0;32m
# blue/information
_INFO_=\e[0;36m
# blue/information
_DEBUG_=\e[0;37m
# red/error
_ERROR_=\e[1;31m
# yellow/warning
_WARNING_=\e[0;33m
# value/purple
_VALUE_=\e[0;35m

# Colours function helpers
SUCCESS=$(_SUCCESS_)$(1)$(_RESET_)
INFO=$(_INFO_)$(1)$(_RESET_)
DEBUG=$(_DEBUG_)$(1)$(_RESET_)
ERROR=$(_ERROR_)$(1)$(_RESET_)
WARNING=$(_WARNING_)$(1)$(_RESET_)
VALUE=$(_VALUE_)$(1)$(_RESET_)
# messages helper
OK=$(call SUCCESS, ok)


