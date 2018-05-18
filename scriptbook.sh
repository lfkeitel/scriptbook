#!/usr/bin/zsh

scriptbook() {
local SCRIPTBOOK_DIR=${SCRIPTBOOK_DIR:-$HOME/scriptbook}
local SYSTEM_TYPE="$(uname)"
local ALIAS_NAME=run

local GREP_CMD="grep"

# Prompt with a default of no
confirmPromptN() {
    response=$(prompt "$1 [y/N]?")
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "y"
        return
    fi
    echo "n"
}

# Prompt with a default of yes
confirmPromptY() {
    response=$(prompt "$1 [Y/n]?")
    if [[ $response =~ ^([nN][oO]|[nN])$ ]]; then
        echo "n"
        return
    fi
    echo "y"
}

prompt() {
    if [[ "$SHELL" =~ "zsh" ]]; then
        read "response?$1 "
    else
        read -r -p "$1 " response
    fi
    echo "$response"
}

scriptExists() {
    [ -f "$SCRIPTBOOK_DIR/$1.json" ]
    return $?
}

checkScriptName() {
    [ -z "$(echo "$1" | $GREP_CMD ':')" ]
    return $?
}

removeScriptFromBook() {
    script_name="$1"
    if [ -z "$script_name" ]; then
        usage
        return
    fi

    checkScriptName "$script_name"
    if [ $? -ne 0 ]; then
        echo "Script name cannot contain a colon."
        return
    fi

    if ! scriptExists "$script_name"; then
        echo "Script $script_name doesn't exist"
        return
    fi

    response="$(confirmPromptY "Are you sure you want to delete $script_name?")"
    if [ "$response" != "y" ]; then
        return
    fi

    rm -f "$SCRIPTBOOK_DIR/$script_name.json"
    echo "Script $script_name removed"
}

listAllScripts() {
    echo "Scripts:"
    (
        echo " Name\tCommand"

        (
            for f in $SCRIPTBOOK_DIR/*; do
                name="$(basename $f | cut -d'.' -f1)"
                cmd="$(jq -r '.command' "$f")"
                echo " $name\t$cmd"
            done
        ) | sort
    ) | column -t -s $'\t'
}

runScriptCmd() {
    script_name="$1"
    checkScriptName "$script_name"
    if [ $? -ne 0 ]; then
        echo "Script name cannot contain a colon."
        return
    fi

    if ! scriptExists $script_name; then
        echo "Script $script_name doesn't exist"
        return
    fi

    scriptJson="$SCRIPTBOOK_DIR/$script_name.json"
    wd="$(jq -r '."working-dir"' "$scriptJson")"
    cmd="$(jq -r '.command' "$scriptJson")"

    if [[ -z $wd || $wd == "." ]]; then
        alias $ALIAS_NAME="_scriptbook_run(){$cmd \"\$@\"; unset -f _scriptbook_run};_scriptbook_run"
    else
        alias $ALIAS_NAME="_scriptbook_run(){pushd $wd>/dev/null; $cmd \"\$@\"; popd>/dev/null; unset -f _scriptbook_run};_scriptbook_run"
    fi
}

usage() {
    echo "Usage: scriptbook.sh COMMAND scriptname"
    cat <<"EOF"

Commands:
    bind          Bind the command to the alias `run`
    remove|rm|r   Remove a script from the book
    list|ls       List all scripts
    version|ver|v Display version information
EOF
}

showVersion() {
    cat <<"EOF"
scriptbook - v0.1.0

Copyright 2018 Lee Keitel <lee@onesimussystems.com>

This software is distributed under the BSD 3-clause license.
EOF
}

if [ ! -d "$SCRIPTBOOK_DIR" ]; then
    mkdir -p $SCRIPTBOOK_DIR
    if [ $? -ne 0 ]; then
        return
    fi
fi

case "$1" in
    bind)
        shift; runScriptCmd $@;;
    list|ls)
        shift; listAllScripts $@;;
    remove|rm|r)
        shift; removeScriptFromBook $@;;
    version|ver|v)
        shift; showVersion $@;;
    *)
        usage
esac
}

# If invoked as a normal script, execute with arguments
if [ "$#" -gt 0 ]; then
    scriptbook "$@"
fi
