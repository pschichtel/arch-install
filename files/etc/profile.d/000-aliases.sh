alias sudo='sudo '
alias fuck='sudo $(history -p \!\!)'

LS_OPTIONS="--color=auto"
alias "ls=ls $LS_OPTIONS"
alias "ll=ls $LS_OPTIONS -l"
alias "l=ls $LS_OPTIONS -lA"

GREP_OPTIONS="--color=auto"
alias "grep=grep $GREP_OPTIONS"

alias "top=htop"

export EDITOR=/usr/bin/editor

ncs() {
    local host="$1"
    if ! [ -z "$2" ]
    then
        host="$host:$2"
    fi
    openssl s_client -connect "$host"
}

