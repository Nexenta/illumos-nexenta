#!/usr/bin/bash

enabler="spa_import"
functions_list_file="functions_list.txt"

if [ ! -z "$1" ]; then
	enabler="$1"
fi

if [ ! -z "$2" ]; then
	functions_list_file="$2"
fi

build_probe_list()
{
	provider="fbt"
	module="zfs"
	probe="entry"

	list_file="$1"
	if [ ! -z "$2" ]; then
		probe="$2"
	fi
	if [ ! -z "$3" ]; then
		module="$3"
	fi
	if [ ! -z "$4" ]; then
		provider="$4"
	fi

	functions=( $(cat ${list_file}) )
	pos=$(( ${#functions[*]} - 1 ))
	last=${functions[$pos]}
	
	for func in "${functions[@]}"; do
		echo -n "${provider}:${module}:${func}:${probe}"
		if [[ ${func} == ${last} ]]; then
			echo
		else
			echo ","
		fi
	done
}

entry_probe_list=$(build_probe_list ${functions_list_file})
return_probe_list=$(build_probe_list ${functions_list_file} "return")

cat<<EOF 
#!/usr/sbin/dtrace -s
fbt:zfs:${enabler}:entry
{
	self->ts[probefunc] = timestamp;
	self->trace = 1;
	printf("%Y\n", self->ts[probefunc]);
}

fbt:zfs:${enabler}:return
/self->trace && self->ts[probefunc]/
{
	this->ts = timestamp - self->ts[probefunc];
	self->ts[probefunc] = 0;
	self->trace = 0;
	printf("%Y\n", timestamp);
	printf("%s took %lu.%09lu seconds\n", stringof(probefunc),
	    this->ts / 1000000000, this->ts % 1000000000);
}

${entry_probe_list}
/self->trace && (self->rec_count[probefunc] == 0)/
{
	self->ts[probefunc] = timestamp;
	++self->rec_count[probefunc];
	printf("%Y\n", self->ts[probefunc]);
}

${entry_probe_list}
/self->trace && (self->rec_count[probefunc] > 0) && self->ts[probefunc]/
{
	++self->rec_count[probefunc];
}

${return_probe_list}
/self->trace && (self->rec_count[probefunc] <= 2) && self->ts[probefunc]/
{
        this->ts = timestamp - self->ts[probefunc];
        self->ts[probefunc] = 0;
	self->rec_count[probefunc] = 0;
	printf("%Y\n", timestamp);
        printf("%s took %lu.%09lu seconds\n", stringof(probefunc),
            this->ts / 1000000000, this->ts % 1000000000);
}

${return_probe_list}
/self->trace && (self->rec_count[probefunc] > 2) && self->ts[probefunc]/
{
	--self->rec_count[probefunc];
}

EOF
