##
## oop.bash for bash-oop
## by lenormf
##

_OOP_DEBUG=0

## Mangling
## Classes:	_BC<namelen><name> (points to the number of fields)
## Field:	_BF<namelen><name><field type (unused)><field name>
## Instances:	_BI<namelen><name><instance name>
## Values:	_BV<namelen><instance name><variable name> (points to the value of the variable)

## A few utils
function _panic {
	echo "$@"
	exit 1
}

function _debug_log {
	test $_OOP_DEBUG -eq 1 && echo "$@" >&2
}

function _func_exists {
	declare -F | grep -qw "$1"
}

## Functions that take care of mangling the names
## Declare a class in the AST
function _set_class {
	export "_BC${#1}${1}"="$2"
	_debug_log "_BC${#1}${1}=$2"
}

## Declare a field in a class
function _set_field {
	export "_BF${#1}${1}${2}${3}"=''
	_debug_log "_BF${#1}${1}${2}${3}"
}

## Declare an instance of a class
function _set_instance {
	export "_BI${#1}${1}${2}"=''
	_debug_log "_BI${#1}${1}${2}"
}

## Set the value of a field of an instance
function _set_value {
	export "_BV${#1}${1}${2}"="$3"
	_debug_log "_BV${#1}${1}${2}=$3"
}

## Getters
## Get the value of an instance's field
function _get_value {
	printenv "_BV${#1}${1}${2}"
}

## Get the list of classes
function _get_class {
	local mangl=$(declare | egrep -o "_BI[0-9]+[A-Za-z_]+${1}")
	local symlen=$(echo "${mangl:3}" | egrep -o '[0-9]+')

	echo "${mangl:$((${#symlen} + 3)):${symlen}}"
}

## Has-functions
## Test if a field was declared in a class
function _has_field {
	declare | grep -wq "_BF${#1}${1}${2}${3}"
}

## Test if an instance of a class was declared
function _has_instance {
	declare | grep -wq "_BI${#1}${1}${2}"
}

## Test if a class was declared
function _has_class {
	declare | grep -wq "_BC${#1}${1}"
}

## Internal functions
function _delete_instance {
	local class_name="$1"
	local inst_name="$2"

	for i in $(declare | egrep -o "_BV${#inst_name}${inst_name}\w+"); do
		unset "$i"
	done

	unset $(declare | egrep -o "_BI${#class_name}${class_name}${inst_name}")
}

## Called when the script exists, this function calls all the destructors of living instances
function _call_dtors {
	local M=( $(declare | egrep -o "_BI[0-9]+[A-Za-z_]+") )

	for i in "${M[@]}"; do
		local symlen=$(echo "${i:3}" | egrep -o '[0-9]+')
		local class_name="${i:$((${#symlen} + 3)):${symlen}}"
		local inst_name="${i:$((${#symlen} + 3 + ${#class_name}))}"

		_func_exists "dtor_${class_name}" \
			&& eval "dtor_${class_name}" "${inst_name}"
	done
}

function _get_op_callback {
	local op="$1"

	for i in "${_OPS[@]}"; do
		local o=$(echo "$i" | cut -d: -f1)
		local cb=$(echo "$i" | cut -d: -f2)

		test "$op" = "$o" && echo "$cb" && return
	done

	echo
}

## Available operators
_OPS=(
	.:_op_get
	!:_op_call
)

function _op_get {
	local class_name="$1"
	local inst_name="$2"
	local var_name="$3"

	shift 3
	test -z "$var_name" && _panic "$inst_name (operator .): no field name given"
	_has_field "${class_name}" 0 "$var_name" || _panic "$inst_name (operator .): no such field $var_name"

	if [ $# -gt 1 ]; then
		test "$1" != = && _panic "$inst_name (operator .): unknown parameter $1"

		_set_value "$inst_name" "$var_name" "$2"
	else
		_get_value "$inst_name" "$var_name"
	fi
}

function _op_call {
	local class_name="$1"
	local inst_name="$2"
	local var_name="$3"

	shift 3
	test -z "$var_name" && _panic "$inst_name (operator .): no field name given"
	_has_field "${class_name}" 0 "$var_name" || _panic "$inst_name (operator !): no such field $var_name"

	local v=$(_get_value "$inst_name" "$var_name")
	eval "$v" "$inst_name" "$@"
}

## The following variables contain code included in the actual commands, to improve readability
_CLASS_INSTANCE_ACCESSOR="
	local op=\\\"\\\$1\\\"
	local cb=\\\$(_get_op_callback \\\"\\\$op\\\")

	shift
	test -z \\\"\\\$cb\\\" && _panic \\\"\\\$inst_name: unknown operator \\\$op\\\"

	\\\$cb \\\"\\\$class_name\\\" \\\"\\\$inst_name\\\" \\\"\\\$@\\\"
"

## Exported commands
function class {
	test $# -lt 3 && _panic "class: invalid number or arguments (expected 3)"
	test "$2" != '{' -o "${!#}" != '}' && _panic "class: missing braces"
	echo "$1" | egrep -q '^[A-Za-z_]+$' || _panic "class $1: class name must contain letters and underscores only"

	local class_name="$1"

	_has_class "$class_name" && _panic "class: class $class_name was already declared"

	## Declare the class name
	_set_class "$class_name" $(($# - 3))

	## Export the field names
	shift 2
	for i in "$@"; do
		test "$i" = '}' && break
		echo "$i" | egrep -q "^[A-Za-z_]+$" || _panic "class $1 ($i): field names must contain letters and underscores only"

		## TODO: set variable types with declare ?
		_set_field "$class_name" 0 "$i"
	done

	## Export the instances declarator
	eval "function $class_name {
		test \$# -lt 1 && _panic \"${class_name}: no instance name given\"
		echo \"\$1\" | egrep -q \"^[A-Za-z_]+$\" || _panic \"${class_name} \$1: instance name must contain letters and underscores only\"

		local cn=\$(_get_class \"\$1\")

		test ! -z \"\$cn\" && _panic \"${class_name}: instance already declared (class \$cn)\"

		_set_instance \"$class_name\" \"\$1\"

		## Export the variables accessor
		eval \"function \$1 {
			test \\\$# -lt 1 && _panic \\\"\$1: invalid number of arguments (expected at least 1)\\\"

			## Export the variable again to have access to it in this function's context
			local class_name="$class_name"
			local inst_name="\$1"

			$_CLASS_INSTANCE_ACCESSOR
		}\"

		_func_exists \"ctor_${class_name}\" && eval \"ctor_${class_name}\" \"\$1\"
	}"
}

function delete {
	test $# -lt 1 && _panic "delete: invalid number of arguments (expected at least 1)"

	for inst_name in "$@"; do
		local class_name=$(_get_class "$inst_name")

		_func_exists "dtor_${class_name}" \
			&& eval "dtor_${class_name}" "$inst_name"

		_delete_instance "$class_name" "$inst_name"
	done
}

## "Garbage collector"
trap _call_dtors EXIT
