
ps1_string() {

    local black="\[\033[00;30m\]"
    local blue="\[\033[00;34m\]"
    local green="\[\033[00;32m\]"
    local cyan="\[\033[00;36m\]"
    local red="\[\033[00;31m\]"
    local purple="\[\033[00;35m\]"
    local brown="\[\033[00;33m\]"
    local lgray="\[\033[00;37m\]"
    local dgray="\[\033[01;30m\]"
    local lblue="\[\033[01;34m\]"
    local lgreen="\[\033[01;32m\]"
    local lcyan="\[\033[01;36m\]"
    local lred="\[\033[01;31m\]"
    local lpurple="\[\033[01;35m\]"
    local yellow="\[\033[01;33m\]"
    local white="\[\033[01;37m\]"
    local reset="\[\033[00;00m\]"
    
    local check="\342\234\223"
    local cross="\342\234\227"

    local prefix=" \$(if [ \"\$?\" = '0' ]; then echo \"${lgreen}${check}\"; else echo \"${lred}${cross}\"; fi)"
    local path="${cyan}\$(echo -n '\w' | sed 's/\//${dgray}\/${cyan}/g' | sed 's/^~/${lgreen}~/g')"

    if [ "$UID" = '0' ]
    then
        local user="${red}\u"
    else
        local user="${lgreen}\u"
    fi
    local separator="${yellow}@"
    local host="${lcyan}\h"
    local suffix="${green}\$${reset} "
    
    echo -n "$prefix ${user}${separator}${host} $path $suffix"
}

PS1=$(ps1_string)

unset -f ps1_string

