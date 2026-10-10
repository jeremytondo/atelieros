# First-login setup. On an interactive login before setup has finished,
# atelieros-setup replaces the login shell. It starts a new login shell when
# it's done, or a plain one if it fails or is interrupted.
#
# bash and zsh both read this file. Commands over SSH, scp, sftp and remote
# editors have no terminal or aren't interactive, so they never start setup.
# Fedora's /etc/bashrc also reads profile.d in shells that aren't login shells;
# those skip it too. Sorted last, so the rest of profile.d has run first.
if [ -z "${ATELIEROS_SETUP_SKIP-}" ] && [ ! -e "$HOME/.local/state/atelieros/setup-done" ] \
    && [ -t 0 ] && [ -t 1 ] && [ -x /usr/bin/atelieros-setup ] && [ "$(id -u)" != 0 ]; then
    case $- in
        *i*)
            # shellcheck disable=SC3044 # only bash reaches shopt
            if [ -z "${BASH_VERSION-}" ] || shopt -q login_shell; then
                exec /usr/bin/atelieros-setup --login
            fi
            ;;
    esac
fi
