#!/usr/bin/env bash

FindPackageManager()
    {

    case "$OSTYPE" in
        "darwin"*)
            PACKAGER_BIN=$(command -v brew)
            ;;
        "linux"*)
            if ! PACKAGER_BIN=$(command -v apt); then
                if ! PACKAGER_BIN=$(command -v yum); then
                    if ! PACKAGER_BIN=$(command -v opkg); then
                        PACKAGER_BIN=''
                    fi
                fi
            fi
            ;;
        *)
            echo "Unidentified platform [$OSTYPE]. Please create a new issue for this on GitHub: https://github.com/teracow/googliser/issues"
            return 1
            ;;
    esac

    [[ -z $PACKAGER_BIN ]] && PACKAGER_BIN=unknown

    readonly PACKAGER_BIN

    return 0

    }

readonly SCRIPT_FILE=googliser.sh
cmd=''
cmd_result=0

FindPackageManager || exit 1

echo " Installing googliser ..."

cat > googliser-completion << 'EOF'
#!/usr/bin/env bash
_GoogliserCompletion()
    {

    # Pointer to current completion word.
    # By convention, it's named "cur" but this isn't strictly necessary.
    local cur

    OPTS='-d -E -h -L -q -s -S -z -a -b -G -i -l -m -n -o -p -P -r -R -t -T -u --debug \
    --exact-search --help --lightning --links-only --no-colour --no-color --safesearch-off \
    --quiet --random --reindex-rename --save-links --skip-no-size --aspect-ratio \
    --border-pixels --colour --color --exclude-links --exclude-words --format --gallery \
    --input-links --input-phrases --lower-size --minimum-pixels --number --output --parallel \
    --phrase --recent --retries --sites --thumbnails --timeout --title --type --upper-size --usage-rights'

    COMPREPLY=()   # Array variable storing the possible completions.
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$cur" in
        -*)
        COMPREPLY=( $( compgen -W "${OPTS}" -- ${cur} ) );;
    esac

    # Display file completion for options that require files as arguments
    case "$prev" in
        --input-links|--exclude-links|-i|--input-phrases)
        _filedir ;;
    esac

    return 0

    }

complete -F _GoogliserCompletion -o filenames googliser
EOF

case "$OSTYPE" in
    darwin*)
        if ! (command -v brew >/dev/null); then
            ruby -e "$(curl -fsSL git.io/get-brew)"
        fi
        brew install coreutils ghostscript gnu-sed imagemagick gnu-getopt bash-completion
        mv googliser-completion /usr/local/etc/bash_completion.d/
        SHELL=$(ps -p $$ -o ppid= | xargs ps -o comm= -p)
        if [[ "$SHELL" == "zsh" ]]; then
            echo "autoload -Uz compinit && compinit && autoload bashcompinit && bashcompinit" >> "$HOME/.zshrc"
            echo "source /usr/local/etc/bash_completion.d/googliser-completion" >> "$HOME/.zshrc"
            #. "$HOME/.zshrc"
        else
            echo "[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion" >> "$HOME/.bash_profile"
            # shellcheck disable=SC1090
            . "$HOME/.bash_profile"
        fi
        ;;
    linux*)
        SUDO='sudo -k '         # '-k' disables cached authentication, so a password will be required every time
        if [[ $EUID -eq 0 ]]; then
            SUDO=''
        fi
        readonly SUDO

        ! (command -v wget >/dev/null) && cmd+='wget '
        if ! (command -v convert >/dev/null) || ! (command -v montage >/dev/null) || ! (command -v identify >/dev/null); then
            if [[ -e /etc/fedora-release ]]; then
                cmd+='ImageMagick '
            else
                cmd+='imagemagick '
            fi
        fi

        if [[ -n $cmd ]]; then
            cmd="${SUDO}$PACKAGER_BIN install $cmd"

            echo " Executing: '$cmd'"
            eval "$cmd"; cmd_result=$?
        fi

        if [[ $cmd_result -gt 0 ]]; then
            echo " Unable to continue"
            exit 1
        fi

        cmd="${SUDO}mv googliser-completion /etc/bash_completion.d/"
        echo " Executing: '$cmd'"
        eval "$cmd"; cmd_result=$?

        if [[ $cmd_result -gt 0 ]]; then
            echo " Unable to continue"
            exit 1
        fi

        # shellcheck disable=SC1091
        . /etc/bash_completion.d/googliser-completion
        ;;
esac

if [[ ! -e $SCRIPT_FILE ]]; then
    if (command -v wget >/dev/null); then
        wget -q git.io/googliser.sh
    elif (command -v curl >/dev/null); then
        curl -skLO git.io/googliser.sh
    else
        echo " Unable to find a way to download script"
        exit 1
    fi
fi

[[ ! -x $SCRIPT_FILE ]] && chmod +x "$SCRIPT_FILE"

cmd="${SUDO}mv $SCRIPT_FILE /usr/local/bin/googliser"
echo " Executing: '$cmd'"
eval "$cmd"; cmd_result=$?

if [[ $cmd_result -gt 0 ]]; then
    echo " Unable to continue"
    exit 1
fi

echo " Installation complete"
echo
echo " Type 'googliser -h' for help"
