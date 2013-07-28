#! /usr/bin/env bash
##
## example.bash for bash-oop
## by lenormf
##

source oop.bash

class Session {		\
	shell		\
	username	\
	wm		\
	run		\
}

function ctor_Session {
	local this="$1"

	$this . shell = "$SHELL"
	$this . username = "$USER"
	$this . wm = "BarbieWM"
	$this . run = run_Session

	echo "Opening session ($($this . username))"
}

function dtor_Session {
	local this="$1"

	echo "Closing session ($($this . username))"
}

function run_Session {
	local this="$1"

	shift
	echo "Running session on $1 ($($this . username))"
}

class Empty { }

function dtor_Empty {
	local this="$1"

	echo "I'll be called when the script exits ($this)"
}

Session my_session

echo "Windows manager before changes: $(my_session . wm)"
my_session . wm = "i3"
echo "Windows manager after changes: $(my_session . wm)"

my_session ! run $(hostname)

delete my_session

Empty my_session
Empty foo
