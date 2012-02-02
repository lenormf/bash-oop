#! /usr/bin/env bash

## Private functions
function _exit {
	echo "$@" 1>&2
	exit 1
}

function _is_in_array {
  	local VALUE="$1"
	
	test $# -lt 2 && _exit "_is_in_array: not enough arguments"
  	shift
  	for i in "$@"; do
    	test "$i" = "$VALUE" && exit 1
  	done

  	exit 0
}

# Usage: _assert_class_declared Foo
function _assert_class_declared {
  	test $# -lt 1 && _exit "_assert_class_declared: not enough arguments"
  	test -z $(eval "echo \$__CLASS__${1}__") && _exit "_assert_class_declared: unknown class ${1}"
}

# Usage: _assert_class_declared Foo my_var
function _assert_variable_declared {
  	test $# -lt 2 && _exit "_assert_variable_declared: not enough arguments"
  	_assert_class_declared "$1"

  	$(_is_in_array "$2" $(get_class_variables "$1")) \
    	&& _exit "_assert_variable_declared: variable $2 was not declared in $1"
}

# Usage: _assert_object_instantiated Foo foo
function _assert_object_instantiated {
	test $# -lt 2 && _exit "_assert_object_instantiated: not enough arguments"

	test -z $(eval echo __INST_${1}_${2}__) && _exit "_assert_object_instantiated: no instance of $1 called $2 has been defined"
}

## Public functions
# Usage: get_class_variables Foo
function get_class_variables {
	test $# -lt 1 && _exit "get_class_variables: not enough arguments"	
  	_assert_class_declared "$1"

	local CLASS_NAME="$1"
	eval "echo \${__CLASS__${CLASS_NAME}__[@]}"
}

# Usage: get_value Foo foo my_var
function get_value {
 	test $# -lt 3 && _exit "get_value: not enough argument"
  	_assert_variable_declared "$1" "$3"

	local PREFIX="__VAR__${1}_${2}_${3}__"
  	eval echo \"'$'${PREFIX}\"
}

# Usage: set_value Foo foo my_var value
function set_value {
	test $# -lt 4 && _exit "set_value: not enough arguments"
	_assert_variable_declared "$1" "$3"
	_assert_object_instantiated "$1" "$2"

	local TYPE="$1"
	local INST="$2"
	local VAR="$3"
	shift 3
	eval "__VAR__${TYPE}_${INST}_${VAR}__=\"$@\""
}

# Access variables of an object
__DECL_INST_ACCESS='
	if [ \$# -ge 2 ]; then
		local VARNAME="\$2"
    	case "\$1" in
      		.)
				test \$# -eq 2 && get_value "$THIS_TYPE" "\$THIS_INST" "\$VARNAME"
				test \$# -ge 4 && test "\$3" = "=" && shift 3 \
					&& set_value "$THIS_TYPE" "\$THIS_INST" "\$VARNAME" "\$@"
				;;
      		*) _exit "Unknown operation \$1";;
    	esac
	fi
'

# Instantiate an object of a certain type
__DECL_CLASS_INST="
	test \$# -lt 1 && _exit \"${CLASS_NAME}: not enough arguments\"

	eval \"function \$1 {
    	local THIS_INST=\"\$1\"

    	for i in \$(get_class_variables \${THIS_TYPE}); do
			local PREFIX=__VAR__\${THIS_TYPE}_\\\${THIS_INST}_\\\${i}__
      		local VARNAME=\\\$(eval echo '$'\\\${PREFIX})

      		test ! -z \"\\\$VARNAME\" && break
      		eval \"\\\${PREFIX}=0\"
    	done

		$__DECL_INST_ACCESS
	}\"
"

# Declare a class
function class {
	test $# -lt 3 && _exit "class: not enough arguments"
	test "$2" != '{' -o $(eval "echo \$$#") != '}' && _exit "class: missing braces"
  	test ! -z $(eval "echo \$__CLASS__${1}__") && _exit "class: class $1 has always been declared"

	local CLASS_NAME="$1"
	local VARIABLES_LIST=""

	shift 2

	for i in "$@"; do
		test "$i" != '}' && VARIABLES_LIST="$VARIABLES_LIST $i"
	done

	eval "__CLASS__${CLASS_NAME}__=(${VARIABLES_LIST})"
	eval "function $CLASS_NAME {
    	local THIS_TYPE=\"$CLASS_NAME\"
		local INST_DEC=__INST__\${THIS_TYPE}_\${1}__

		test ! -z \$(eval echo '$'\${INST_DEC}) \
			&& _exit \"\${1}: \${THIS_INST} has already been declared\" \
			|| eval \"\${INST_DEC}=1\"

		$__DECL_CLASS_INST
	}"
}
