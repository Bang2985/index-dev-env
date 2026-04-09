#!/bin/bash
#
# Notes:
# - docker compose run redirects the stderr of any invoked executables to
#   stdout. The only messages that will appear on stderr are issued by docker
#   compose run itself. This appears to be an undocumented "feature":
#   https://docs.docker.com/engine/reference/commandline/compose_run/
#
#   The "2>/dev/null" below silences the messages from docker compose run.
#   For example, the output like the following will not be visible:
#       [+] Creating 2/0
#        ✔ Container index-db  Running                                  0.0s
#        ✔ Container index-web   Running                                  0.0s
#
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=SC2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

# shellcheck disable=SC1091
source .env

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E30="$(printf "\e[30m")"      # foreground: black
E31="$(printf "\e[31m")"      # foreground: red
E33="$(printf "\e[33m")"      # foreground: yellow
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E97="$(printf "\e[97m")"      # foreground: bright white
E100="$(printf "\e[100m")"    # background: bright black (gray)
E107="$(printf "\e[107m")"    # background: bright white
OPT_DATE_FORMAT=Y-m-d
OPT_DEFAULT_COMMENT_STATUS=closed
OPT_PERMALINK_STRUCTURE='/%year%/%monthnum%/%day%/%postname%/'
OPT_TIME_FORMAT='H:i'
PLUGINS_ACTIVATE='
acf-menu-chooser
advanced-custom-fields
akismet
classic-editor
redirection
tablepress
wordpress-importer
wordpress-seo'
# NOTE: wordfence does not play nice with Docker. Enabling it results in WP-CLI
#       commands taking approximately 13 times longer (ex. 10.8 seconds
#       instead of 0.8 seconds)
PLUGINS_DEACTIVATE='
google-analytics-for-wordpress
wordfence'
PLUGINS_UNINSTALL='
hello'
THEMES_ACTIVATE='
vocabulary-theme'
THEMES_REMOVE='
twentytwentyone
twentytwentytwo'
WEB_WP_DIR=/var/www/index
WEB_WP_URL=http://localhost:8080
WP_USER="www-data"

#### FUNCTIONS ################################################################


activate_plugins() {
    local _bold _plugin _reset
    print_header 'Activate plugins'
    for _plugin in ${PLUGINS_ACTIVATE}
    do
        if wpcli --no-color --quiet plugin is-active "${_plugin}" &> /dev/null
        then
            no_op "${_plugin} is already active"
        else
            if ! wpcli plugin activate "${_plugin}"
            then
                print_error "failed to activate plugin: ${_plugin}"
            fi
        fi
    done
    echo
}


activate_themes() {
    local _theme
    print_header 'Activate themes'
    for _theme in ${THEMES_ACTIVATE}
    do
        if wpcli --no-color --quiet theme is-active "${_theme}" &> /dev/null
        then
            no_op "${_theme} is already active"
        else
            wpcli theme activate "${_theme}"
        fi
    done
    echo
}


check_requirements() {
    # Ensure docker daemon is running
    if [[ ! -S /var/run/docker.sock ]]
    then
        error_exit 'docker daemon is not running'
    fi

    # Ensure docker containers are running:
    for _container in index-web index-db
    do
        if ! docker compose exec "${_container}" true &>/dev/null
        then
            error_exit "docker container unavailable: ${_container}"
        fi
    done
}


check_user_permissions() {
    if ! docker compose exec -T --user "$WP_USER" \
        index-web test -w "$WEB_WP_DIR"; then \
        error_exit "$WP_USER does not have write permissions on $WEB_WP_DIR"
    fi
}


composer_install() {
    print_header 'Composer install'
    docker compose run --rm index-web composer install --ansi 2>&1 \
        | sed \
            -e'/Container.*Running$/d' \
            -e'/is looking for funding./d' \
            -e'/Use the .composer fund. command/d'
    echo
}


database_check() {
    print_header 'Check database'
    wpcli db check --color \
        | sed -e'/^wordpress[.]wp_.*OK$/d'
    echo
}


database_optimize() {
    print_header 'Optimize database'
    # Only show errors and summary
    wpcli db optimize --color \
        | sed \
            -e'/^wordpress[.]wp_/d' \
            -e'/Table does not support optimize/d' \
            -e'/^status   : OK/d'
    echo
}


database_update() {
    print_header 'Update database'
    wpcli core update-db
    echo
}


deactivate_plugins() {
    local _bold _plugin _reset
    print_header 'Deactivate plugins'
    for _plugin in ${PLUGINS_DEACTIVATE}
    do
        if wpcli --no-color --quiet plugin is-active "${_plugin}" &> /dev/null
        then
            wpcli plugin deactivate "${_plugin}"
        else
            no_op "${_plugin} is already inactive"
        fi
    done
    echo
}


environment_info() {
    local _key _val IFS
    print_header 'Container information'

    # index-db
    printf "${E97}%s${E0} - %s\n" 'index-db' \
        'Database server for WordPress'
    print_key_val 'MariaDB version' \
        "$(echo; docker compose exec index-db mariadb --version)"
    echo

    # index-web
    printf "${E97}%s${E0} - %s\n" 'index-web' \
        'Web server (WordPress and static HTML components)'
    print_var WEB_WP_URL
    print_var WEB_WP_DIR
    print_key_val 'WordPress version' "$(wpcli core version)"
    print_key_val 'PHP version' \
        "$(docker compose exec index-web php --version \
            | awk '/^PHP/ {print $2}')"
    print_key_val 'Composer version' \
        "$(docker compose run --rm index-web \
            composer --version 2>/dev/null \
            | sed 's/Composer version \([^ ]*\).*/\1/')"
    IFS=$'\n'
    for _line in $(wpcli --info | sort)
    do
        _key="${_line%%:*}"
        # '| xargs' is used to trim whitespace
        _val="$( echo "${_line#*:}" | xargs)"
        [[ -n "${_val}" ]] || continue
        [[ "${_key}" =~ ^WP-CLI ]] || continue
        print_key_val "${_key}" "${_val}"
    done
    echo
}


error_exit() {
    # Echo error message and exit with error
    print_error "${*}"
    exit 1
}


format_plugin_list() {
    local _h _hm _hr
    _h="${E97}${E100}"
    # header match
    _hm='(^name *)  (status *)  (update *)  (version)  (update_version)'
    _hm="${_hm}  (auto_update)  (requires)  (requires_php)"
    # header replace
    _hr="${_h}\1${E0}  ${_h}\2${E0}  ${_h}\3${E0}  ${_h}\4${E0}  ${_h}\5${E0}"
    _hr="${_hr}  ${_h}\6${E0}  ${_h}\7${E0}  ${_h}\8${E0}"
    sed -u -E \
        -e"s/${_hm}/${_hr}/" \
        -e"s/(^.* inactive .*$)/${E90}\1${E0}/" \
        -e"s/( active .*)( available )/\1${E33}\2${E0}/"
}


format_themes_list() {
    local _h _hm _hr
    _h="${E97}${E100}"
    # header match
    _hm='(^name *)  (status *)  (update *)  (version)  (update_version)'
    _hm="${_hm}  (auto_update)"
    # header replace
    _hr="${_h}\1${E0}  ${_h}\2${E0}  ${_h}\3${E0}  ${_h}\4${E0}  ${_h}\5${E0}"
    _hr="${_hr}  ${_h}\6${E0}"
    sed -u -E \
        -e"s/${_hm}/${_hr}/" \
        -e"s/(^.* inactive .*$)/${E90}\1${E0}/" \
        -e"s/( active .*)( available )/\1${E33}\2${E0}/"
}


install_wordpress() {
    local _err
    print_header 'Install WordPress'
    if [[ -n "${WP_ADMIN_EMAIL}" ]] && [[ -n "${WP_ADMIN_EMAIL}" ]] \
        && [[ -n "${WP_ADMIN_EMAIL}" ]]
    then
        print_var WP_ADMIN_EMAIL
        print_var WP_ADMIN_USER
        print_var WP_ADMIN_PASS
    else
        _err='The following variables must be set in .env (see .env.example):'
        _err="${_err} WP_ADMIN_EMAIL, WP_ADMIN_USER, WP_ADMIN_PASS"
        error_exit "${_err}"
    fi
    echo
    if wpcli --no-color --quiet core is-installed &> /dev/null
    then
        no_op 'already installed'
    else
        wpcli core install \
            --title='CreativeCommons.org Local Dev' \
            --admin_email="${WP_ADMIN_EMAIL}" \
            --admin_user="${WP_ADMIN_USER}" \
            --admin_password="${WP_ADMIN_PASS}" \
            --skip-email
    fi
    echo
}


list_plugins() {
    print_header 'List plugins'
    wpcli plugin list --format=csv \
        | sed -e's/,none,/,-,/g' -e's/,,/,-,/g' -e's/,$/,-/' \
        | column -s',' -t \
        | format_plugin_list
    echo
}


list_themes() {
    print_header 'List themes'
    wpcli theme list --format=csv \
        | sed -e's/,none,/,-,/g' -e's/,,/,-,/g' -e's/,$/,-/' \
        | column -s',' -t \
        | format_themes_list
    echo
}


no_op() {
    # Print no-op message"
    printf "${E90}no-op: %s${E0}\n" "${@}"
}


print_error() {
    echo -e "${E31}ERROR:${E0} ${*}" 1>&2
}


print_key_val() {
    printf "${E97}${E100}%22s${E0} %s\n" "${1}:" "${2}"
}


print_header() {
    # Print 80 character wide black on white heading with time
    printf "${E30}${E107}# %-70s$(date '+%T') ${E0}\n" "${@}"
}


print_var() {
    print_key_val "${1}" "${!1}"
}


remove_themes() {
    local _theme
    print_header 'Remove extraneous themes'
    for _theme in ${THEMES_REMOVE}
    do
        if ! wpcli --no-color --quiet theme is-installed "${_theme}" \
            > /dev/null
        then
            no_op "${_theme} is not installed"
        else
            wpcli theme delete "${_theme}"
        fi
    done
    echo
}


uninstall_plugins() {
    local _bold _plugin _reset
    print_header 'Uninstall plugins'
    for _plugin in ${PLUGINS_UNINSTALL}
    do
        if wpcli --no-color --quiet plugin is-installed "${_plugin}" \
            &> /dev/null
        then
            wpcli plugin uninstall "${_plugin}"
        else
            no_op "${_plugin} is not installed"
        fi
    done
    echo
}


update_options() {
    local _date_format _default_comment_status _noop _permalink_structure \
        _time_format
    print_header 'Update options'

    _date_format=$(wpcli option get date_format)
    if [[ "${OPT_DATE_FORMAT}" != "${_date_format}" ]]
    then
        echo "Update date_format: ${OPT_DATE_FORMAT}"
        wpcli option update date_format "${OPT_DATE_FORMAT}"
    else
        no_op "date_format: ${OPT_DATE_FORMAT}"
    fi

    _default_comment_status=$(wpcli option get default_comment_status)
    if [[ "${OPT_DEFAULT_COMMENT_STATUS}" != "${_default_comment_status}" ]]
    then
        echo "Update default_comment_status: ${OPT_DEFAULT_COMMENT_STATUS}"
        wpcli option update default_comment_status \
            "${OPT_DEFAULT_COMMENT_STATUS}"
    else
        _noop="default_comment_status: ${OPT_DEFAULT_COMMENT_STATUS}"
        no_op "${_noop}"
    fi

    _permalink_structure=$(wpcli option get permalink_structure)
    if [[ "${OPT_PERMALINK_STRUCTURE}" != "${_permalink_structure}" ]]
    then
        echo "Update permalink_structure: ${OPT_PERMALINK_STRUCTURE}"
        wpcli option update permalink_structure "${OPT_PERMALINK_STRUCTURE}"
    else
        no_op "permalink_structure: ${OPT_PERMALINK_STRUCTURE}"
    fi

    _time_format=$(wpcli option get time_format)
    if [[ "${OPT_TIME_FORMAT}" != "${_time_format}" ]]
    then
        echo "Update time_format: ${OPT_TIME_FORMAT}"
        wpcli option update time_format "${OPT_TIME_FORMAT}"
        wpcli rewrite flush --hard
    else
        no_op "time_format: ${OPT_TIME_FORMAT}"
    fi

    echo
}


wordpress_status() {
    print_header 'Show maintenance mode status to expose any PHP Warnings'
    wpcli_loud maintenance-mode status
    echo
}


wpcli() {
    # Call WP-CLI with appropriate site arguments via Docker and silence
    # warnings
    docker compose exec -T --user "$WP_USER" \
        --env WP_ADMIN_USER="${WP_ADMIN_USER}" \
        --env WP_ADMIN_PASS="${WP_ADMIN_PASS}" \
        --env WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL}" \
        index-web \
            /usr/local/bin/wp --path="${WEB_WP_DIR}" --url="${WEB_WP_URL}" \
            "${@}" 2> >(sed -e'/^PHP Warning:/d' -e'/^Warning:/d')
}


wpcli_loud() {
    # Call WP-CLI with appropriate site arguments via Docker
    docker compose exec -T --user "$WP_USER" \
        --env WP_ADMIN_USER="${WP_ADMIN_USER}" \
        --env WP_ADMIN_PASS="${WP_ADMIN_PASS}" \
        --env WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL}" \
        index-web \
            /usr/local/bin/wp --path="${WEB_WP_DIR}" --url="${WEB_WP_URL}" \
            "${@}" 2> >(
                sed -e"s/PHP Warning:/${E33}PHP Warning:${E0}/" \
                    -e"s/Warning:/${E33}Warning:${E0}/"
            )
}


#### MAIN #####################################################################

check_requirements
check_user_permissions
environment_info
composer_install
install_wordpress
update_options
remove_themes
uninstall_plugins
deactivate_plugins
activate_plugins
list_plugins
activate_themes
list_themes
database_update
database_optimize
database_check
wordpress_status
