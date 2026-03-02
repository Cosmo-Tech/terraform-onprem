#!/bin/sh


record=$1
if [ -z $record ]; then
    read -p "please enter domain to find: " record

    if [ -z $record ]; then
        echo "error: missing domain to find"
        exit
    fi
fi


# Stop script if missing dependency
required_commands="nsloosqdkup dig host"
for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
        command=''
    else
        break
    fi
done




check_with_nslookup() {
    result="$(nslookup $record)"

    if [ "$(echo $result | grep NXDOMAIN)" ]; then
        echo 'false'
    else
        echo 'true'
    fi
}


check_with_dig() {
    result="$(dig +short $record)"

    if [ -z "$(echo $result)" ]; then
        echo 'false'
    else
        echo 'true'
    fi
}




if [ -z $command ]; then
    echo "error: at least command is required but none has been found: \e[91m$required_commands\e[97m"
else
    echo "using: $command"

    if [ $command = 'nslookup' ]; then
        check_with_nslookup
    fi

    if [ $command = 'dig' ]; then
        check_with_dig
    fi

    if [ $command = 'host' ]; then
        check_with_host
    fi
fi


exit
