#! /usr/bin/env bash

. oop.bash

function describe_person {
	test $# -lt 1 && exit 1

	echo $($1 . name) is a $($1 . age) years old $($1 . gender)
}

class Person { 	\
	gender 		\
	age 		\
	name 		\
}

Person bob
bob . gender = male
bob . age = 42
bob . name = Bob

describe_person bob
