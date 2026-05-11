#!/bin/bash
set -o errexit
set -o errtrace
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf     "\e[0m")"    # reset
E30="$(printf "\e[30m")"      # black foreground
E31="$(printf   "\e[31m")"    # red foreground
E32="$(printf   "\e[32m")"    # green foreground
E90="$(printf   "\e[90m")"    # bright black foreground
E92="$(printf   "\e[92m")"    # bright green foreground
E107="$(printf "\e[107m")"    # bright white background

TARGET_HOST="${1:-http://localhost:8080}"

ENSURE_LOWERCASE='
/LiCeNsEs/By/4.0/DeEd.En
/lIcEnSeS/bY/2.0/uK/
'

ALT_LANG_CODES='
/licenses/by/3.0/es/legalcode.es-es
/licenses/by/3.0/es/legalcode.oci
/licenses/by/3.0/rs/legalcode.sr-cyrl
/licenses/by/3.0/rs/legalcode.sr-latin
/licenses/by/4.0/deed.zh
/licenses/by/4.0/deed.zh_cn
/licenses/by/4.0/deed.zh_tw
'

ISSUE236='
/licenses/by-nc-nd/1.0/deed.INVALID
/licenses/by-nd-nc/1.0/deed.INVALID
/licenses/sampling/1.0/br/deed.apy
/licenses/sampling+/1.0/deed.INVALID
/licenses/by-nc-sa/2.0/deed.INVALID
/licenses/by-nc/2.0/be/deed.wa
/licenses/by-nd/2.1/deed.INVALID
/licenses/by-sa/2.1/jp/deed.ryn
/licenses/by/2.5/deed.INVALID
/licenses/by/2.5/ar/deed.gn
/licenses/by/3.0/deed.INVALID
/licenses/by/3.0/am/deed.hy
/licenses/by/3.0/es/deed.ast
/licenses/by/4.0/deed.INVALID
/licenses/by/4.0/deed.mi
'

# sorted with: sort -t'/' -V -k6 -k7 -k5
ISSUE444_FULL='
/licenses/by-nc-sa/1.0/il/
/licenses/by-nc/1.0/il/
/licenses/by-nd-nc/1.0/il/
/licenses/by-nd/1.0/il/
/licenses/by-sa/1.0/il/
/licenses/by/1.0/il/
/licenses/by-nc-nd/2.0/uk/
/licenses/by-nc-sa/2.0/uk/
/licenses/by-nc/2.0/uk/
/licenses/by-nd/2.0/uk/
/licenses/by-sa/2.0/uk/
/licenses/by/2.0/uk/
/licenses/by-nc-nd/2.0/za/
/licenses/by-nc-sa/2.0/za/
/licenses/by-nc/2.0/za/
/licenses/by-nd/2.0/za/
/licenses/by-sa/2.0/za/
/licenses/by/2.0/za/
/licenses/by-nc-nd/2.5/il/
/licenses/by-nc-sa/2.5/il/
/licenses/by-nc/2.5/il/
/licenses/by-nd/2.5/il/
/licenses/by-sa/2.5/il/
/licenses/by/2.5/il/
/licenses/by-nc-nd/2.5/in/
/licenses/by-nc-sa/2.5/in/
/licenses/by-nc/2.5/in/
/licenses/by-nd/2.5/in/
/licenses/by-sa/2.5/in/
/licenses/by/2.5/in/
/licenses/by-nc-nd/2.5/mk/
/licenses/by-nc-sa/2.5/mk/
/licenses/by-nc/2.5/mk/
/licenses/by-nd/2.5/mk/
/licenses/by-sa/2.5/mk/
/licenses/by/2.5/mk/
/licenses/by-nc-nd/2.5/scotland/
/licenses/by-nc-sa/2.5/scotland/
/licenses/by-nc/2.5/scotland/
/licenses/by-nd/2.5/scotland/
/licenses/by-sa/2.5/scotland/
/licenses/by/2.5/scotland/
/licenses/by-nc-nd/2.5/za/
/licenses/by-nc-sa/2.5/za/
/licenses/by-nc/2.5/za/
/licenses/by-nd/2.5/za/
/licenses/by-sa/2.5/za/
/licenses/by/2.5/za/
/licenses/by-nc-nd/3.0/am/
/licenses/by-nc-sa/3.0/am/
/licenses/by-nc/3.0/am/
/licenses/by-nd/3.0/am/
/licenses/by-sa/3.0/am/
/licenses/by/3.0/am/
/licenses/by-nc-nd/3.0/ge/
/licenses/by-nc-sa/3.0/ge/
/licenses/by-nc/3.0/ge/
/licenses/by-nd/3.0/ge/
/licenses/by-sa/3.0/ge/
/licenses/by/3.0/ge/
/licenses/by-nc-nd/3.0/hk/
/licenses/by-nc-sa/3.0/hk/
/licenses/by-nc/3.0/hk/
/licenses/by-nd/3.0/hk/
/licenses/by-sa/3.0/hk/
/licenses/by/3.0/hk/
/licenses/by-nc-nd/3.0/ie/
/licenses/by-nc-sa/3.0/ie/
/licenses/by-nc/3.0/ie/
/licenses/by-nd/3.0/ie/
/licenses/by-sa/3.0/ie/
/licenses/by/3.0/ie/
/licenses/by-nc-nd/3.0/sg/
/licenses/by-nc-sa/3.0/sg/
/licenses/by-nc/3.0/sg/
/licenses/by-nd/3.0/sg/
/licenses/by-sa/3.0/sg/
/licenses/by/3.0/sg/
/licenses/by-nc-nd/3.0/th/
/licenses/by-nc-sa/3.0/th/
/licenses/by-nc/3.0/th/
/licenses/by-nd/3.0/th/
/licenses/by-sa/3.0/th/
/licenses/by/3.0/th/
/licenses/by-nc-nd/3.0/vn/
/licenses/by-nc-sa/3.0/vn/
/licenses/by-nc/3.0/vn/
/licenses/by-nd/3.0/vn/
/licenses/by-sa/3.0/vn/
/licenses/by/3.0/vn/
/licenses/by-nc-nd/3.0/za/
/licenses/by-nc-sa/3.0/za/
/licenses/by-nc/3.0/za/
/licenses/by-nd/3.0/za/
/licenses/by-sa/3.0/za/
/licenses/by/3.0/za/
'

ISSUE444_PART='
/licenses/by-nc-sa/1.0/il/
/licenses/by-nc-nd/2.0/uk/
/licenses/by-nc-nd/2.5/mk/
/licenses/by/3.0/am/
'

COMPATIBILITY='
/licenses/publicdomain/
/licenses/nc-nd/1.0/
/licenses/mark/1.0/
/licenses/by-nc-nd/1.0/
/license/
/license
/licences
/licence
'

ISSUE1433='
/licenses/list.it/by-nc/2.0/it/by-nc-sa/2.5/dk/sa/2.0/jp/by/4.0/legalcode.sk
/licenses/list.en/invalid/
'

#### FUNCTIONS ################################################################


header() {
    # Print 80 character wide black on white heading with time
    printf "${E30}${E107}# %-69s$(date '+%T') ${E0}\n" "${@}"
}


test1_urls() {
    local _location _result _path _paths _url
    _header="${1}"
    _paths="${2}"
    header "${_header}"
    for _path in ${_paths}
    do
        _url="${TARGET_HOST}${_path}"
        _result=$(http --headers --pretty none "${_url}?")
        _code=$(echo "${_result}" | awk '/^HTTP/ {print $2}')
        case ${_code} in
            200) printf "${E92}";;
            301) printf "${E32}";;
            310) printf "${E32}";;
              *) printf "${E31}";;
        esac
        printf "%-11s  %s${E0}\n" "HTTP/1.1 ${_code}" "${_url}"
        if [[ "${_result}" =~ 301 ]]
        then
            _result=$(http --all --follow --headers --pretty none "${_url}")
            _location=$(echo "${_result}" \
                | awk '/^Location:/ {print $2}' \
                | tail -n1)
            _code=$(echo "${_result}" \
                | awk '/^HTTP/ {print $2}' \
                | tail -n1)
            case ${_code} in
                200) printf "${E92}";;
                301) printf "${E32}";;
                310) printf "${E32}";;
                  *) printf "${E31}";;
            esac
            printf "%-11s  %s${E0}\n" ">>>>>>>> ${_code}" "${_location}"
        fi
    done
    echo
}


test2_urls() {
    local _location _result _path _paths _url
    _header="${1}"
    _paths="${2}"
    header "${_header}"
    for _path in ${_paths}
    do
        _url="${TARGET_HOST}${_path}"
        _result=$(http --headers --pretty none "${_url}?")
        _code=$(echo "${_result}" | awk '/^HTTP/ {print $2}')
        case ${_code} in
            404) printf "${E92}";;
            301) printf "${E32}";;
            310) printf "${E32}";;
              *) printf "${E31}";;
        esac
        printf "%-11s  %s${E0}\n" "HTTP/1.1 ${_code}" "${_url}"
        if [[ "${_result}" =~ 301 ]]
        then
            _result=$(http --all --follow --headers --pretty none "${_url}")
            _location=$(echo "${_result}" \
                | awk '/^Location:/ {print $2}' \
                | tail -n1)
            _code=$(echo "${_result}" \
                | awk '/^HTTP/ {print $2}' \
                | tail -n1)
            case ${_code} in
                200) printf "${E92}";;
                301) printf "${E32}";;
                310) printf "${E32}";;
                  *) printf "${E31}";;
            esac
            printf "%-11s  %s${E0}\n" ">>>>>>>> ${_code}" "${_location}"
        fi
    done
    echo
}


if [[ "${TARGET_HOST}" == 'http://localhost:8080' ]]
then
    docker compose restart index-web
fi


test1_urls 'Ensure lowercase' "${ENSURE_LOWERCASE}"
test1_urls 'Alternate language codes' "${ALT_LANG_CODES}"
test1_urls 'Issue 444 - all URLs' "${ISSUE444_FULL}"
#test1_urls 'Issue 444 - selected URLs' "${ISSUE444_PART}"
test1_urls 'Issue 236' "${ISSUE236}"
test1_urls 'Compatibility' "${COMPATIBILITY}"
test2_urls 'Issue 1433 (path after path)' "${ISSUE1433}"
