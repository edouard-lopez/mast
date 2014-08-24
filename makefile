#!/usr/bin/make -sf
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
REMOTE_INIT_PWD:=C1i3ntRmSid3
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
PRINTER:=none
# channel description (default: empty).
DESC:=
# channel's id, used for removal
ID:=-1

# SSH tunnel configuration directory (a file per host)
CONFIG_DIR:=/etc/mast
# Log files directory
LOG_DIR:=/var/log/mast

# Passphrase MUST be empty to allow automation (no passphrase prompt)
EMPTY:=
# Path to the SSH keys pair (public key is suffixed by .pub).
SSH_DIR:=$$HOME/.ssh
SSH_KEYFILE:=${SSH_DIR}/id_rsa.mast.coaxis

# webapp sources directory, cloned during install (deployed to /var/www/mast-web)
WEBAPP=mast-web
# location of served web app.
WEBAPP_DEST_DIR=/var/www/

# Project dependencies
DEPS_CORE_INFRA:=autossh openssh-client trickle apache2 libapache2-mod-php5 sudo aha sshpass
DEPS_UTILS:=bmon iftop htop

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Code source repository
BRANCH=dev
WEBAPP_REPO:=https://github.com/edouard-lopez/mast-web.git
WEBAPP_ARCHIVE:=https://github.com/edouard-lopez/mast-web/archive/${BRANCH}.tar.gz
# DEV ONLY
WEBAPP_REPO:=file://$(shell pwd)/../mast-web/.git
# Web app's hostname
APACHE_HOSTNAME:=mast.dev
# Path to apache config file
APACHE_SRC_CONF=${WEBAPP}/resources/server/mast-web.apache.conf
APACHE_DEST_CONF=/etc/apache2/sites-enabled/${WEBAPP}.conf

# Branch to checkout before deploying webapp
WEBAPP_BRANCH=dev

.PHONY:  default \
	add-channel \
	add-host  \
	check-privileges  \
	check-system  \
	config-ssh  \
	create-ssh-key  \
	deploy  \
	deploy-key  \
	deploy-service  \
	deploy-webapp  \
	install  \
	install-infra  \
	list-channels  \
	list-hosts  \
	list-logs  \
	remove-channel \
	remove-host  \
	setup-infra  \
	uninstall  \
	usage


default: usage
setup-infra: install-infra
create-ssh-key: ${SSH_KEYFILE}


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
		(( "$${#config[@]}" > 1 )) && printf "%-50s\n" $$'$(call INFO,'"$$fn"$$')'; \
		source "$${cfg}"; \
		for i in "$${!ForwardPort[@]}"; do \
			rule="$$(echo $${ForwardPort[i]} | awk -F '#' '{print $$1}' | sed -e 's/^ *//' -e 's/ *$$//')"; \
			comment="$$(echo $${ForwardPort[i]} | awk -F '#' '{ $$1=""; print $$0}' | sed -e 's/^ *//' -e 's/ *$$//')"; \
			printf "\t%-45s%-15s\t%s\n" $$'$(call VALUE,'"$$rule"$$')' $$'$(call INFO,'"$$i"$$')' $$'$(call DEBUG,'"# $$comment"$$')'; \
		done; \
	done


# List all log files, one for each tunnel
list-logs:
	@for log in "${LOG_DIR}/${APP}"-*.log; do \
		fn="$$(basename "$$log")"; \
		[[ ! -f $$log || -d $$log || $fn == "template" ]] && continue; \
		printf "\t%-50s%s\n" $$'$(call VALUE,'"$$fn"$$')' $$'$(call INFO,'"$$log"$$')'; \
	done


# List all hosts available to the service
list-hosts:
	@for fn in ${CONFIG_DIR}/*; do \
		h=$$(basename "$$fn"); \
		[[ $$h == "template" ]] && continue; \
		remoteHost="$$(grep RemoteHost "$$fn" | tr -d ' \"' | cut -d '=' -f 2 )"; \
		printf "\t%-50s%s\n" $$'$(call VALUE,'$$h$$')' $$'$(call INFO,'"$$remoteHost"$$')'; \
	done


# Add a new channel for the given printer to the given host
# @require: {string} 	NAME 		configuration name as given to 'add-host'
# @require: {string} 	PRINTER 	printer's hostname or ip
# @option: {string} 	DESC 		description/comment of the channel
add-channel:
	@printf "Adding channel…\n"
	@if [[ ${NAME} == "none" || -z "${NAME}" ]]; then \
		printf "\t%-50s%s\t%s\n" $$'$(call VALUE,NAME)' $$'$(call ERROR,missing)' \
									$$'$(call INFO,(see \'mast-utils list-host\'))'  1>&2; \
		exit 1; \
	fi
	@if [[ "${PRINTER}" == "none" || -z "${PRINTER}" ]]; then \
		printf "\t%-50s%s\t%s\n" $$'$(call VALUE,PRINTER)' $$'$(call ERROR,missing)' \
									$$'$(call INFO,(IP address or hostname))'  1>&2; \
		exit 1; \
	fi

	@grep --no-filename --only-matching --perl-regexp 'L[\s]+\*:([\d]+):' ${CONFIG_DIR}/* \
		| cut --delimiter=':' -f 2 \
		| sort --unique --numeric-sort \
	> /tmp/ports; \
	prevPort=$$(head -n 1 /tmp/ports); \
	nextPort=$$prevPort;\
	while read -r port; do \
		(( port == nextPort )) && PORT=$$nextPort || break; \
		prevPort=$$port; \
		nextPort=$$(( $$prevPort+1 )); \
	done < <(cat /tmp/ports); rm /tmp/ports; \
	source "${CONFIG_DIR}/${NAME}"; \
	newRule="L *:$$nextPort:${PRINTER}:9100 # ${DESC}"; \
	ForwardPort+=( "$$newRule" ); \
	printf "%s\n%s\n%s\n"	"# - - - - - - - - - - - - - - - - - - - - - - - - - - " \
								"# See /etc/mast/template for more informations" \
								"# - - - - - - - - - - - - - - - - - - - - - - - - - - " \
		> "${CONFIG_DIR}/.${NAME}"; \
	declare -p RemoteHost RemoteUser RemotePort ServerAliveInterval ServerAliveCountMax StrictHostKeyChecking LocalUser IdentityFile ForwardPort BandwidthLimitation UploadLimit DownloadLimit >> "${CONFIG_DIR}/.${NAME}" \
		&& mv "${CONFIG_DIR}"/{.,}"${NAME}" \
		&& printf "\t%-50s\t%s\n" $$'$(call VALUE,'"$$newRule$$"')' $$'$(call SUCCESS,added)' \
		|| printf "\t%-50s\t%s\n" $$'$(call VALUE,'"$$newRule"$$')' $$'$(call ERROR,failed)'

# Remove channel using its index
# @require: 	{string} 	NAME 		configuration name
# @require 	{integer}	ID 		channel index as given by 'list-channels'
remove-channel:
	@printf "Removing channel…\n"
	@if [[ ${ID} == -1 || -z ${ID} ]]; then \
		printf "\t%s.\n" $$'$(call ERROR,missing ID)' 1>&2; \
		exit 0; \
	else \
		source "${CONFIG_DIR}/${NAME}"; \
		removedRule="$${ForwardPort[${ID}]}"; \
		if [[ -z $$removedRule ]]; then \
			printf "\t%-50s\t%s\t%s\n" "rule "$$'$(call VALUE,#${ID})' $$'$(call WARNING,skipped)' $$'$(call INFO,(doesn\'t exists))' ; \
		else \
			unset 'ForwardPort[${ID}]'; \
			declare -p RemoteHost RemoteUser RemotePort ServerAliveInterval ServerAliveCountMax StrictHostKeyChecking LocalUser IdentityFile ForwardPort BandwidthLimitation UploadLimit DownloadLimit \
			>> "${CONFIG_DIR}/.${NAME}" \
			&& mv "${CONFIG_DIR}"/{.,}"${NAME}" \
			&& printf "\t%-50s\t%s\n" $$'$(call VALUE,'"$$removedRule"$$')' $$'$(call SUCCESS,removed)' \
			|| printf "\t%-50s\t%s\n" $$'$(call VALUE,'"$$removedRule"$$')' $$'$(call ERROR,failed)'; \
		fi;\
	fi

# Adding a new host configuration require to provide it's NAME and HOST
# @require: {string} NAME configuration name
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
	@chmod g=rwx "${CONFIG_DIR}/${NAME}"
	@chgrp www-data "${CONFIG_DIR}/${NAME}"


# Remove host using its configuration name
# @require: 	{string} 	NAME 		configuration name
remove-host:
	@printf "Removing host…\n\t%s\t\t" $$'$(call VALUE, ${NAME})'
	@if [[ "${NAME}" == "none" || -z "${NAME}" ]]; then \
		printf "%s host\'s NAME.\n" $$'$(call WARNING,invalid)' 1>&2; \
	elif [[ ! -e "${CONFIG_DIR}/${NAME}" ]]; then \
		printf "does %s.\n" $$'$(call WARNING,not exist)' 1>&2; \
	elif [[ ! -f "${CONFIG_DIR}/${NAME}" ]]; then \
		printf "%s host\'s file.\n" $$'$(call WARNING,invalid)' 1>&2; \
	else \
		rm -f "${CONFIG_DIR}/${NAME}" && printf "%s\n" $$'$(call SUCCESS,done)' || printf "%s\n" $$'$(call ERROR,error)' 1>&2; \
	fi

# Install application network may not be setup, so don't deploy (ssh's key) on remote devices
install: install-infra check-system check-privileges deploy-service create-ssh-key deploy-webapp

uninstall:
	@printf "Uninstalling…\n"
	@filesList=( \
		/etc/systemd/system/mastd.service \
		/etc/init.d/mast \
		/usr/sbin/mastd \
		/usr/sbin/mast-utils \
		"${CONFIG_DIR}"/* \
		"${CONFIG_DIR}" \
		/etc/apache2/sites-enabled/${WEBAPP}.conf \
		${LOG_DIR} \
		${WEBAPP_DEST_DIR}/mast-web \
		mast-web \
	); for fn in "$${filesList[@]}"; do \
		[[ -f $$fn || -d $$fn ]] || continue; \
		rm -rf "$$fn" && printf "\t%-50s%s\n" $$'$(call VALUE,'$$fn$$')' $$'$(call SUCCESS,done)'; \
	done
	@update-rc.d -f mast remove > /dev/null

# deploy the webapp, configure apache, /etc/hosts
deploy-webapp:
	@printf "Deploying…\t%s\n" $$'$(call VALUE,webapp)'

	@# cloning repository
	@if [[ ! -f ${WEBAPP}/.git && ! -d ${WEBAPP}/.git ]]; \
		then \
			if type git &> /dev/null; then \
				printf "\t%-50s" $$'$(call INFO,cloning repository)'; \
				git clone --depth 1 --quiet ${WEBAPP_REPO} > /dev/null; \
			else \
				printf "\t%-50s" $$'$(call INFO,fetching)'; \
				[[ ! -d "${WEBAPP}" ]] && rm -rf ${WEBAPP} || true; \
				wget --quiet --output-document="${WEBAPP}.tar.gz" ${WEBAPP_ARCHIVE}; \
				tar xzf "${WEBAPP}.tar.gz"; \
				mv ${WEBAPP}{-${BRANCH},}; \
			fi \
		elif [[ -f ${WEBAPP}/.git || -d ${WEBAPP}/.git ]]; then \
			printf "\t%-50s" $$'$(call INFO,updating repository)'; \
			pushd "${WEBAPP}" \
				&& git pull ${WEBAPP_REPO} > /dev/null; \
			popd; \
				git checkout --quiet ${WEBAPP_BRANCH} > /dev/null \
					&& printf "$(call SUCCESS,done)" \
		else \
			printf "%s (already existing)\n" $$'$(call WARNING,skipped)' 1>&2; \
		fi; \
		chmod u=rwx,g=rwx,o= -R "${WEBAPP}/"; \
		chown $${SUDO_USER}:www-data -R "${WEBAPP}/"
	@printf "\t%s\n" $$'$(call DEBUG,${WEBAPP_REPO})'

	@# deploying webapp: /var/www/mast
	@printf "\t%-50s" $$'$(call INFO,deploying webapp)'
		@cp -R --preserve=all ${WEBAPP} ${WEBAPP_DEST_DIR} \
			&& printf "$(call SUCCESS,done)" \
			|| printf "$(call ERROR,fail)"
	@printf "\t%s\n" $$'$(call DEBUG,${WEBAPP_DEST_DIR}/${WEBAPP})'

	@# configuring Apache: /etc/apache2/sites-enabled/mast-web.conf
	@printf "\t%-50s" $$'$(call INFO,configuring Apache)'
		@a2enmod php5 rewrite > /dev/null  # enable Apache module
		@cp ${APACHE_SRC_CONF} ${APACHE_DEST_CONF} \
			&& printf "$(call SUCCESS,done)" \
			|| printf "$(call ERROR,fail)"
		@printf "\t%s\n" $$'$(call DEBUG,${APACHE_DEST_CONF})'

	@# declaring hostname: /etc/hosts
	@printf "\t%-50s" $$'$(call INFO,declaring hostname)'
		@if ! grep -iq 'mast' /etc/hosts; then \
			printf '%s\n' H 1i "127.0.0.1 ${APACHE_HOSTNAME} www.${APACHE_HOSTNAME}" . w | ed -s /etc/hosts; \
			printf '%s\n' H 1i "# Mast-web" . w | ed -s /etc/hosts; \
			printf "%s" $$'$(call SUCCESS,done)'; \
			printf "\t%s\n" $$'$(call DEBUG,/etc/hosts)'; \
		else \
			printf "%s\t%s" $$'$(call WARNING,skipped)' 1>&2; \
			printf "%s\n" $$'$(call DEBUG,/etc/hosts already existing)'; \
		fi

	@# reloading Apache
	@printf "\t%-50s" $$'$(call INFO,reloading Apache)'
		@if apache2ctl configtest &> /dev/null; then \
				apache2ctl graceful; \
				printf "$(call SUCCESS,done)\n"; \
				printf "\t%-50s%s\n" $$'$(call SUCCESS,test installation using)' $$'$(call VALUE,http://%SOCIETE%.opt/)'; \
			else \
				printf "$(call ERROR,failed)"; \
				printf "\t%s\n" $$'$(call DEBUG,${WEBAPP_DEST_DIR}/${WEBAPP})'; \
				apache2ctl configtest; \
			fi

deploy-service:
	@printf "Deploying…\t%s\n" $$'$(call VALUE,service)'

	@printf "\t%-50s" $$'$(call INFO,initd service)'
		@rm -f /etc/init.d/mast \
		&& cp mast /etc/init.d/ \
		&& printf "$(call SUCCESS,done)\n" || printf "$(call ERROR,error)\n" 1>&2
		@chown www-data /etc/init.d/mast
		@update-rc.d mast defaults > /dev/null

	@printf "\t%-50s" $$'$(call INFO,utils)'
		@rm -f /usr/sbin/mast-utils \
		&& cp makefile /usr/sbin/mast-utils \
		&& printf "$(call SUCCESS,done)\n" || printf "$(call ERROR,error)\n" 1>&2
		@chown www-data /usr/sbin/mast-utils; \

	@printf "\t%-50s" $$'$(call INFO,config directory)'
		@if [[ ! -d "${CONFIG_DIR}" ]]; then \
			mkdir "${CONFIG_DIR}" \
				&& printf "%s\t%s\n" $$'$(call SUCCESS,done)' $$'$(call VALUE, ${CONFIG_DIR}/)' \
				|| printf "$(call ERROR,error)\n" 1>&2; \
		elif [[ -d "${CONFIG_DIR}" ]]; then \
			printf "%s\t%s\n" $$'$(call WARNING,skipped)' $$'$(call VALUE, ${CONFIG_DIR}/)'; \
		fi

	@printf "\t%-50s" $$'$(call INFO,template)'
		@rm -f ${CONFIG_DIR}/template \
			&& chmod u=rw,go= template \
			&& cp {.,${CONFIG_DIR}}/template \
				&& printf "%s\t%s\n" $$'$(call SUCCESS,done)' $$'$(call VALUE, ${CONFIG_DIR}/template)' \
				|| printf "$(call ERROR,error)\n" 1>&2

	@printf "\t%-50s" $$'$(call INFO,log directory)'
		@if [[ ! -d "${LOG_DIR}" ]]; then \
			mkdir "${LOG_DIR}" \
				&& printf "%s\t%s\n" $$'$(call SUCCESS,done)' $$'$(call VALUE, ${LOG_DIR}/)' \
				|| printf "$(call ERROR,error)\n" 1>&2; \
		elif [[ -d "${LOG_DIR}" ]]; then \
			printf "%s\t%s\n" $$'$(call WARNING,skipped)' $$'$(call VALUE, ${LOG_DIR}/)'; \
		fi
		@chown www-data -R "${LOG_DIR}" && chmod u=rwx,g=rwx "${LOG_DIR}"



deploy: deploy-service deploy-webapp

config-ssh: deploy-key

# Copy infra public key on customer's node (defined by REMOTE_SRV)
# @require: {string} 	REMOTE_USER		user on remote
# @require: {string} 	REMOTE_SRV 		server hostname or IP
# @warning: do NOT read ~/.ssh/config
deploy-key:
	@printf "Deploying…\t%s\n" $$'$(call VALUE, Public key)'
	@if [[ ! -z "$$SUDO_USER" ]]; then \
		printf "\t%-50s%s\t%s.\n" $$'$(call VALUE,persmissions)' $$'$(call ERROR,fail)'  $$'$(call INFO,must be executed as normal user)' 1>&2; \
		exit 1; \
	elif [[ "${REMOTE_USER}" == "none" || -z "${REMOTE_USER}" || "${REMOTE_SRV}" == "none" || -z "${REMOTE_SRV}" ]]; then \
		printf "\t%s or %s.\n" $$'$(call ERROR,missing REMOTE_SRV)' $$'$(call ERROR,REMOTE_USER)' 1>&2; \
		exit 1; \
	else \
		printf "\t%-50s%s\n" $$'$(call INFO,copy public key to)' $$'$(call VALUE, ${REMOTE_USER}@${REMOTE_SRV})'; \
		sshpass -p "${REMOTE_INIT_PWD}" \
			ssh-copy-id -i "${SSH_KEYFILE}" -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_SRV} >& /dev/null; \
		printf "\n"; \
	fi


# Create keys pair on infra
#@alias: create-ssh-key:
${SSH_KEYFILE}:
	@printf "Creating…\t%s\n" $$'$(call VALUE,SSH keys)'
		@[[ ! -d ${SSH_DIR} ]] && mkdir "${SSH_DIR}" || true
	@printf "\t%-50s%s" $$'$(call INFO,removing existing key)'
		@rm -f ${SSH_KEYFILE}{,.pub} \
			&& printf "%s\n" $$'$(call SUCCESS,done)' \
			|| printf "%s\n" $$'$(call ERROR,failed)'
	@printf "\t%-50s%s" $$'$(call INFO,generating key)'
		@ssh-keygen -q \
			-t rsa \
			-b 4096 \
			-f "${SSH_KEYFILE}" \
			-N "${EMPTY}" \
			-O permit-port-forwarding \
			-C "Automatically generated by MAST script" \
			&& printf "%s\n" $$'$(call SUCCESS,done)' \
			|| printf "%s\n" $$'$(call ERROR,failed)'
	@chmod u=rwx,go= -R "${SSH_DIR}"
	@chown $${SUDO_USER}:$${SUDO_USER} -R "${SSH_DIR}"

# Install packages required on the Coaxis' INFRAstructure
install-infra:
	@printf "Installing…\t%s\n" $$'$(call VALUE, Infrastructure\'s node)'
	apt-get -y -q install ${DEPS_CORE_INFRA} ${DEPS_UTILS}


# Check files permission
check-privileges:
	@printf "Checking…\t%s\n" $$'$(call VALUE,Privileges)'
	@[[ ! -d ${LOG_DIR} ]] && mkdir "${LOG_DIR}" || true
	@chown www-data -R "${LOG_DIR}"
	@# open privileges to www-data
	@printf "\t%-50s\t" $$'$(call INFO,service\'s user)'
	@if ! getent passwd ${APP} > /dev/null; then \
		useradd \
			--gid www-data \
			--groups ${REMOTE_USER} \
			--password $(mkpasswd "${REMOTE_INIT_PWD}") \
			--system ${APP}; \
			&& printf "%s" $$'$(call SUCCESS,added)\n' \
			|| printf "%s" $$'$(call ERROR,failed)\n'; \
	else \
		printf "%s" $$'$(call WARNING,modified)\n'; \
		usermod --append --groups ${REMOTE_USER} ${REMOTE_USER}; \
	fi
	@usermod --append --groups www-data ${REMOTE_USER}


# Check system status for dependencies
check-system:
	@printf "Checking…\t%s\n" $$'$(call VALUE,System)'
	@executables=( ${DEPS_CORE_INFRA} ${DEPS_CORE_CUSTOMER} ${DEPS_UTILS} ); \
	if ! type dpkg-query &> /dev/null; then \
		printf "You *MUST* install 'dpkg'\n"; \
		printf "\t→ %s %s\n" $$'$(call VALUE, apt-get install dpkg)'; \
		exit; \
	fi; \
	for e in $${executables[@]}; do \
		printf "\t%-50s" $$'$(call VALUE, '$$e$$')'; \
		if ! dpkg-query -s "$$e" &> /dev/null; then \
			printf "%12s\t" $$'$(call ERROR,missing)'; \
			printf "→ %s %s\n" $$'$(call INFO,apt-get install '$$e $$')'; \
		else \
			printf "%-12s\n" $$'$(call SUCCESS,installed)'; \
		fi \
	done

# Display basic help. For further information refer to the docs http://github.com/edouard-lopez/mast/README.md
usage:
	@printf "Usage…\n"
	@printf "\t%s: both commands require %s privilieges.\n" $$'$(call WARNING,warning)' $$'$(call VALUE,sudo)' 1>&2
	@printf "\n"
	@printf "\t%-50s%s %s\n" $$'$(call INFO,for install requirements)' $$'$(call WARNING,sudo)' $$'$(call VALUE,make setup-infra)'
	@printf "\t%-50s%s %s\n" $$'$(call INFO,for full installation)' $$'$(call WARNING,sudo)' $$'$(call VALUE,make install)'


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
OK=$(call SUCCESS,ok)


