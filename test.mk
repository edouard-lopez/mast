#!/usr/bin/env make

# force use of Bash
SHELL := /bin/bash


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

default:
	$(call self,$@)
	@assert=1; \
	test=$$(make default | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

setup-customer:
	$(call self,$@)
	@assert=1; \
	test=$$(make setup-customer | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

setup-infra:
	$(call self,$@)
	@assert=1; \
	test=$$(make setup-infra | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

create-ssh-key:
	$(call self,$@)
	@assert=1; \
	test=$$(make create-ssh-key | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

list-channels:
	$(call self,$@)
	@assert=2; \
	test=$$(make create-ssh-key | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

list-logs:
	$(call self,$@)
	@assert=1; \
	test=$$(make list-logs | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

list-host:
	$(call self,$@)
	@assert=1; \
	test=$$(make list-host  &> /dev/null| grep -c ''); \
	(( test >= assert )) && printf "$$'$(call PASS)'" || printf "$(call FAIL)" 1>&2;

add-host:
	$(call self,$@)
	@assert=1; \
	test=$$(make add-host | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

remove-host:
	$(call self,$@)
	@assert=1; \
	test=$$(make remove-host | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

uninstall:
	$(call self,$@)
	@assert=1; \
	test=$$(make uninstall | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

deploy-webapp:
	$(call self,$@)
	@assert=1; \
	test=$$(make deploy-webapp | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

deploy-service:
	$(call self,$@)
	@assert=7; \
	test=$$(make deploy-service | grep -cE 'done|skipped') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

deploy:
	$(call self,$@)
	@assert=1; \
	test=$$(make deploy | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

config-ssh:
	$(call self,$@)
	@assert=1; \
	test=$$(make config-ssh | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

deploy-key:
	$(call self,$@)
	@assert=1; \
	test=$$(make deploy-key | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

install-infra:
	$(call self,$@)
	@assert=1; \
	test=$$(make install-infra | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

install-systemd:
	$(call self,$@)
	@assert=1; \
	test=$$(make install-systemd | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

install-customer:
	$(call self,$@)
	@assert=1; \
	test=$$(make install-customer | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

check-system:
	$(call self,$@)
	@assert=1; \
	test=$$(make check-system | grep -c '') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;


usage:
	$(call self,$@)
	@assert=2; \
	test=$$(make usage 2>&1 | grep -c 'make') &> /dev/null; \
	(( test >= assert )) && printf "$(call PASS)" || printf "$(call FAIL)" 1>&2;

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

PASS=$(_SUCCESS_)pass$(_RESET_)\n
FAIL=$(_ERROR_)fail$(_RESET_): $$assert ≠ $$test\n
self=@printf "\t%-30s" $$'$(call VALUE,$(1))'
