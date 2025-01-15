#----------------------
# Parse makefile arguments
#----------------------
RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(RUN_ARGS):;@:)

#----------------------
# Silence GNU Make
#----------------------
ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

#----------------------
# Load .env file
#----------------------
ifneq ("$(wildcard .env)","")
include .env
export
else
endif

#----------------------
# Terminal
#----------------------

GREEN  := $(shell tput -Txterm setaf 2)
WHITE  := $(shell tput -Txterm setaf 7)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

#------------------------------------------------------------------
# - Add the following 'help' target to your Makefile
# - Add help text after each target name starting with '\#\#'
# - A category can be added with @category
#------------------------------------------------------------------

.PHONY: build test

HELP_FUN = \
	%help; \
	while(<>) { \
		push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z\-]+)\s*:.*\#\#(?:@([a-zA-Z\-]+))?\s(.*)$$/ }; \
		print "\n"; \
		for (sort keys %help) { \
			print "${WHITE}$$_${RESET \
		}\n"; \
		for (@{$$help{$$_}}) { \
			$$sep = " " x (32 - length $$_->[0]); \
			print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; \
		}; \
		print ""; \
	}

help: ##@other Show this help.
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

#----------------------
# mysql
#----------------------

mysql-init: ##@mysql Initialize database
	@./scripts/banner.sh "Initializing MySQL Database..."
	$(COMPOSE_COMMAND) kill mysql
	$(COMPOSE_COMMAND) build mysql
	$(COMPOSE_COMMAND) up -d mysql
	$(DRUNPREFIX) $(COMPOSE_COMMAND) run --user=root mysql bash -c "chown -R mysql:mysql /var/lib/mysql && exit"
	$(COMPOSE_COMMAND) up -d mysql
	$(DRUNPREFIX) $(COMPOSE_COMMAND) exec -T mysql sh -c 'while ! mysqladmin ping -h "mysql" --silent; do sleep .5; done'
	$(DRUNPREFIX) $(COMPOSE_COMMAND) exec mysql sh -c "mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} -e 'CREATE DATABASE IF NOT EXISTS ${MYSQL_EQEMU_DATABASE}'"
	$(DRUNPREFIX) $(COMPOSE_COMMAND) exec mysql sh -c "mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} -e 'GRANT ALL PRIVILEGES ON ${MYSQL_EQEMU_DATABASE}.* TO \"${MYSQL_USERNAME}\"@\"%\"'"
	$(DRUNPREFIX) $(COMPOSE_COMMAND) exec mysql sh -c "mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} -e 'CREATE DATABASE IF NOT EXISTS ${MYSQL_SPIRE_DATABASE}';"
	$(DRUNPREFIX) $(COMPOSE_COMMAND) exec mysql sh -c "mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} -e 'GRANT ALL PRIVILEGES ON ${MYSQL_SPIRE_DATABASE}.* TO \"${MYSQL_USERNAME}\"@\"%\"'"

init-strip-mysql-remote-root: ##@mysql Strips MySQL remote root user
	$(DRUNPREFIX) $(COMPOSE_COMMAND) exec mysql bash -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h localhost -e \"delete from mysql.user where User = 'root' and Host = '%'; FLUSH PRIVILEGES\""
