_gfox_contains() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

_gfox() {
    local i cur prev opts0 opts1 rtypes no_opt
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts0=(-1 -2 -3 -r -w)
    opts1=(-t -p -C -R)
    rtypes="sum1 sum2 sum3 red white wresults rresults"

    _gfox_contains "--" "${COMP_WORDS[@]:0:$COMP_CWORD}" && no_opt=1
    _gfox_contains "$prev" "${opts1[@]}" && no_opt=1

    if [[ ${cur} == -* && -z "$no_opt" ]] ; then
        COMPREPLY=( $(compgen -W "${opts0[*]} ${opts1[*]}" -- ${cur}) )
        return 0
    fi

    if [[ ${prev} == -t ]] ; then
        COMPREPLY=( $(compgen -W "${rtypes}" -- ${cur}) )
        return 0
    fi

}

complete -F _gfox -o bashdefault -o default gfox
