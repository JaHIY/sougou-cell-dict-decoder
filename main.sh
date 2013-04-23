#!/bin/sh -

getopt -T > /dev/null
GETOPT_ERR_CODE=$?
if [ "${GETOPT_ERR_CODE}" -eq 4 ]
then
    ARGV=$(getopt -o 'lh' -l 'list,help' -n "${0}" -- "$@")
else
    ARGV=$(getopt 'lh' "$@")
fi

if [ $? -ne 0 ]
then
    exit 2
fi

eval set -- "$ARGV"

TEMP_PINYIN_TABLE='/tmp/pinyintable-$$.txt'
REVERSE_HEX_ORDER='s/^[[:space:]]*\([[:xdigit:]]\{2\}\)[[:space:]]\([[:xdigit:]]\{2\}\)$/\2\1/g'


reset_cols() {
    awk 'BEGIN{
            n=0;
        }
        {
            for(i=1;i<=NF;i++) {
                n++;
                j=n%'"${1}"';
                if(j != 1) {
                    printf OFS;
                }
                printf "%s",$i;
                if(j == 0) {
                    printf ORS;
                }
            }
        }
        END{
            if(n%'"${1}"' != 0) {
                printf ORS;
            }
        }'
}

list_information() {
    printf '%s%s\n' \
    '词库名：' "$(dict_info "${1}" '0x130' '520')" \
    '词库类型：' "$(dict_info "${1}" '0x338' '520')" \
    '描述信息：' "$(dict_info "${1}" '0x540' '2048')" \
    '词库示例：' "$(dict_info "${1}" '0xd40' '1024')"
}

print_usage() {
    printf '%s\n' \
            "Usage: ${0} [OPTION...] [FILE...]" \
            'Decode sougou cell dict file (.scel).' \
            '' \
            ' Information:' \
            '  -l, --list                 list information of sougou cell dict' \
            '' \
            ' Output control:' \
            '  -h, --help                 show this help list'
}

print_error() {
    local my_name="${0}"
    printf '%s\n' \
            "${my_name}: missing optstring argument" \
            "Try \`${my_name} -h' for more information." 1>&2
}

err() {
    printf '\033[31;1mERROR:\033[0m \033[1m%s\033[0m\n' "$@" 1>&2
}

clean_up() {
    local rm_code
    rm_err=$(rm "${TEMP_PINYIN_TABLE}" 2>&1)
    rm_code=$?
    [ $rm_code -eq 0 ] || err "[${rm_code}]${rm_err}"
}

abort_msg() {
    printf '\n' 1>&2
    err 'Aborted by user! Exiting...'
}

abort_msg_on_exit() {
    abort_msg
    exit 4
}

clean_up_on_exit() {
    abort_msg
    clean_up
    exit 1
}

byte2str_core() {
        local num_dec="$(printf '%s\n' "obase=10;ibase=16;${1}" | bc)"
        local num_bin="$(printf '%s\n' "obase=2;ibase=16;${1}" | bc)"
        local first_part=''
        local sencond_part=''
        local third_part=''
        #Unicode  0000-007F      0080-07FF               0800-FFFF
        #UTF-8    0xxxxxxx   110xxxxx 10xxxxxx   1110xxxx 10xxxxxx 10xxxxxx
        if [ "${num_dec}" -ge 0 ] && [ "${num_dec}" -le 127 ]
        then
            num_bin="$(printf '%08d\n' "${num_bin}")"
            printf '%s\n' "${num_bin}"
        elif [ "${num_dec}" -ge 128 ] && [ "${num_dec}" -le 2047 ]
        then
            num_bin="$(printf '%011d\n' "${num_bin}")"
            first_part="$(cut -c -5 <<< "${num_bin}")"
            sencond_part="$(cut -c 6- <<< "${num_bin}")"
            printf '%s\n' "110${first_part}" "10${sencond_part}"
        elif [ "${num_dec}" -ge 2048 ] && [ "${num_dec}" -le 65535 ]
        then
            num_bin="$(printf '%016d\n' "${num_bin}")"
            first_part="$(cut -c -4 <<< "${num_bin}")"
            sencond_part="$(cut -c 5-10 <<< "${num_bin}")"
            third_part="$(cut -c 11- <<< "${num_bin}")"
            printf '%s\n' "1110${first_part}" "10${sencond_part}" "10${third_part}"
        fi
}

after_byte2str_core() {
    local line=''
    printf '%b' "$(while read line
        do
            printf '\\x%s' "$(printf '%s\n' "obase=16;ibase=2;${line}" | bc)"
        done | \
        sed -e 's/\\x0\{0,1\}[dD]/\\x0A/g')"
}

byte2str() {
    local line=''
    while read line
    do
        byte2str_core "${line}"
    done | \
        after_byte2str_core
}

dict_info() {
    od -An -tx1 -j "${2}" -N "${3}" -v "${1}" | \
        reset_cols 2 | \
        sed -e "${REVERSE_HEX_ORDER}" \
            -e '/^0000$/d' | \
        tr '[:lower:]' '[:upper:]' | \
        byte2str
}

print_pinyin_table() {
    local index=''
    local len=''
    local pinyin=''
    od -An -tx1 -j 0x1544 -N 4324 -v "${1}" | \
        reset_cols 2 | \
        sed -e "${REVERSE_HEX_ORDER}" | \
        tr '[:lower:]' '[:upper:]' | \
        while read index
        do
            read len
            len="$(printf '%s\n' "obase=10;ibase=16;${len}/2" | bc)"
            until [ "${len}" -eq 0 ]
            do
                read pinyin
                byte2str_core "${pinyin}"
                len="$(expr "${len}" - 1)"
            done | \
                after_byte2str_core
            printf '\n'
        done
}

print_dict() {
    local line=''
    local homophone_amount=''
    local pinyin_len=''
    local pinyin=''
    local pinyin_index=''
    local chinese_phrase_len=''
    local chinese_char=''
    local extend_len=''
    local chinese_phrase_frequency=''
    od -An -tx1 -j 0x2628 -v "${1}" | \
        reset_cols 2 | \
        sed -e "${REVERSE_HEX_ORDER}" | \
        tr '[:lower:]' '[:upper:]' | \
        while read line
        do
            homophone_amount="$(printf '%s\n' "obase=10;ibase=16;${line}" | bc)"
            read pinyin_len
            pinyin_len="$(printf '%s\n' "obase=10;ibase=16;${pinyin_len}/2" | bc)"
            pinyin=''
            while [ "${pinyin_len}" -gt 0 ]
            do
                read pinyin_index
                pinyin_index="$(printf '%s\n' "obase=10;ibase=16;${pinyin_index}" | bc)"
                pinyin_index="$(expr "${pinyin_index}" + 1)"
                pinyin="${pinyin} $(sed -n -e "${pinyin_index}p" "${TEMP_PINYIN_TABLE}")"
                pinyin_len="$(expr "${pinyin_len}" - 1)"
            done
            while [ "${homophone_amount}" -gt 0 ]
            do
                printf '%s\n' "${pinyin}" | colrm 1 1
                read chinese_phrase_len
                chinese_phrase_len="$(printf '%s\n' "obase=10;ibase=16;${chinese_phrase_len}/2" | bc)"
                while [ "${chinese_phrase_len}" -gt 0 ]
                do
                    read chinese_char
                    byte2str_core "${chinese_char}"
                    chinese_phrase_len="$(expr "${chinese_phrase_len}" - 1)"
                done | \
                    after_byte2str_core
                printf '\n'
                read extend_len
                read chinese_phrase_frequency
                printf '%s\n' "obase=10;ibase=16;${chinese_phrase_frequency}" | bc
                printf '\n'
                extend_len="$(printf '%s\n' "obase=10;ibase=16;${extend_len}/2" | bc)"
                extend_len="$(expr "${extend_len}" - 1)"
                while [ "${extend_len}" -gt 0 ]
                do
                    read
                    extend_len="$(expr "${extend_len}" - 1)"
                done
                homophone_amount="$(expr "${homophone_amount}" - 1)"
            done
        done
}

main() {
    local list_flag=0
    local my_umask='077'
    local old_umask="$(umask)"
    trap 'abort_msg_on_exit' HUP INT QUIT TERM
    while true
    do
        case "${1}" in
            '-l'|'--list')
                list_flag=1
                shift
            ;;
            '-h'|'--help')
                print_usage
                return 0
            ;;
            '--')
                shift
                break
            ;;
            *)
                print_error
                return 3
            ;;
        esac
    done
    if [ $# -le 0 ]
    then
        print_error
    elif [ "${list_flag}" -eq 1 ]
    then
        while true
        do
            list_information "${1}"
            shift
            [ $# -gt 0 ] || break
        done
    else
        trap 'clean_up_on_exit' HUP INT QUIT TERM
        while true
        do
            umask "$my_umask"
            print_pinyin_table "${1}" > "${TEMP_PINYIN_TABLE}"
            umask "$old_umask"
            print_dict "${1}"
            clean_up
            shift
            [ $# -gt 0 ] || break
        done
    fi
    return 0
}

main "$@"
