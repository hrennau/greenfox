_gfox() {
    local i cur prev opts0 opts1 cmds
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="gfox"
    opts0="-a -b -c -r -w"
    opts1="-t"
    rtypes="white red sum1 sum2 sum3 wresults rresults"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts0} ${opts1}" -- ${cur}) )
        return 0
    fi

    if [[ ${prev} == -t ]] ; then
        COMPREPLY=( $(compgen -W "${rtypes}" -- ${cur}) )
        return 0
    fi

}

complete -F _gfox -o bashdefault -o default gfox
