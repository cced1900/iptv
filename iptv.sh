#!/bin/bash
#
# A [ ffmpeg / v2ray / nginx ] Wrapper Script By MTimer
# Copyright (C) 2019
# Released under BSD 3 Clause License
#
# 使用方法: tv -i [直播源] [-s 段时长(秒)] [-o 输出目录名称] [-c m3u8包含的段数目] [-b 比特率] [-p m3u8文件名称] [-C] [-l] [-P http代理]
#     -i  直播源(支持 mpegts / hls / flv / youtube ...)
#         可以是视频路径
#         可以输入不同链接地址(监控按顺序尝试使用)，用空格分隔
#     -s  段时长(秒)(默认：6)
#     -o  输出目录名称(默认：随机名称)
#
#     -l  非无限时长直播, 无法设置切割段数目且无法监控(默认：不设置)
#     -P  ffmpeg 的 http 代理, 直播源是 http 链接时可用(默认：不设置)
#
#     -p  m3u8名称(前缀)(默认：随机)
#     -c  m3u8里包含的段数目(默认：5)
#     -S  段所在子目录名称(默认：不使用子目录)
#     -t  段名称(前缀)(默认：跟m3u8名称相同)
#     -a  音频编码(默认：aac) (不需要转码时输入 copy)
#     -v  视频编码(默认：libx264) (不需要转码时输入 copy)
#     -f  画面或声音延迟(格式如： v_3 画面延迟3秒，a_2 声音延迟2秒
#         使用此功能*暂时*会忽略部分参数，画面声音不同步时使用)
#     -q  crf视频质量(如果同时设置了输出视频比特率，则优先使用crf视频质量)(数值0~63 越大质量越差)
#         (默认: 不设置crf视频质量值)
#     -b  输出视频的比特率(kb/s)(默认：900-1280x720)
#         如果已经设置crf视频质量值，则比特率用于 -maxrate -bufsize
#         如果没有设置crf视频质量值，则可以继续设置是否固定码率
#         多个比特率用逗号分隔(注意-如果设置多个比特率，就是生成自适应码流)
#         同时可以指定输出的分辨率(比如：-b 600-600x400,900-1280x720)
#         可以输入 omit 省略此选项
#     -C  固定码率(只有在没有设置crf视频质量的情况下才有效)(默认：否)
#     -e  加密段(默认：不加密)
#     -K  Key名称(默认：随机)
#     -z  频道名称(默认：跟m3u8名称相同)
#     也可以不输出 HLS，比如 flv 推流
#     -k  设置推流类型，比如 -k flv
#     -T  设置推流地址，比如 rtmp://127.0.0.1/flv/xxx
#     -L  输入拉流(播放)地址(可省略)，比如 http://domain.com/flv?app=flv&stream=xxx
#     -m  ffmpeg 额外的 输入参数
#         (默认：-reconnect 1 -reconnect_at_eof 1 
#         -reconnect_streamed 1 -reconnect_delay_max 2000 
#         -rw_timeout 10000000 -y -nostats -nostdin -hide_banner -loglevel fatal)
#         如果输入的直播源是 hls 链接，需去除 -reconnect_at_eof 1
#         如果输入的直播源是 rtmp 或本地链接，需去除 -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2000
#     -n  ffmpeg 额外的 输出参数, 可以输入 omit 省略此选项
#         (默认：-g 25 -sc_threshold 0 -sn -preset superfast -pix_fmt yuv420p -profile:v main)
#
# 举例:
#     使用crf值控制视频质量: 
#         tv -i http://xxx.com/xxx.ts -s 6 -o hbo1 -p hbo1 -q 15 -b 1500-1280x720 -z 'hbo直播1'
#     使用比特率控制视频质量[默认]: 
#         tv -i http://xxx.com/xxx.ts -s 6 -o hbo2 -p hbo2 -b 900-1280x720 -z 'hbo直播2'
#     不需要转码的设置: -a copy -v copy -n omit
#     不输出 HLS, 推流 flv :
#         tv -i http://xxx/xxx.ts -a aac -v libx264 -b 3000 -k flv -T rtmp://127.0.0.1/flv/xxx
#
# 快捷键:
#     tv 打开 HLS 管理面板
#     tv f 打开 FLV 管理面板
#
#     tv e 手动修改 channels.json
#     tv m 开启监控
#         tv m l [行数] 查看监控日志
#         tv m s 关闭监控
#
#     tv l 列出所有开启的频道
#
#     cx 打开 xtream codes 面板
#     v2 打开 v2ray 面板
#     nx 打开 nginx 面板

set -euo pipefail

sh_ver="1.25.0"
sh_debug=0
export LANG=en_US.UTF-8
SH_LINK="https://raw.githubusercontent.com/woniuzfb/iptv/master/iptv.sh"
SH_LINK_BACKUP="http://hbo.epub.fun/iptv.sh"
SH_FILE="/usr/local/bin/tv"
NX_FILE="/usr/local/bin/nx"
V2_FILE="/usr/local/bin/v2"
V2CTL_FILE="/usr/bin/v2ray/v2ctl"
V2_CONFIG="/etc/v2ray/config.json"
XC_FILE="/usr/local/bin/cx"
IPTV_ROOT="/usr/local/iptv"
NODE_ROOT="$IPTV_ROOT/node"
IP_DENY="$IPTV_ROOT/ip.deny"
IP_LOG="$IPTV_ROOT/ip.log"
FFMPEG_LOG_ROOT="$IPTV_ROOT/ffmpeg"
FFMPEG_MIRROR_LINK="http://pngquant.com/ffmpeg"
FFMPEG_MIRROR_ROOT="$IPTV_ROOT/ffmpeg"
LIVE_ROOT="$IPTV_ROOT/live"
CREATOR_LINK="https://raw.githubusercontent.com/bentasker/HLS-Stream-Creator/master/HLS-Stream-Creator.sh"
CREATOR_LINK_BACKUP="http://hbo.epub.fun/HLS-Stream-Creator.sh"
CREATOR_FILE="$IPTV_ROOT/HLS-Stream-Creator.sh"
JQ_FILE="$IPTV_ROOT/jq"
CHANNELS_FILE="$IPTV_ROOT/channels.json"
DEFAULT_DEMOS="http://hbo.epub.fun/default.json"
DEFAULT_CHANNELS_LINK="http://hbo.epub.fun/channels.json"
LOCK_FILE="$IPTV_ROOT/lock"
MONITOR_LOG="$IPTV_ROOT/monitor.log"
LOGROTATE_CONFIG="$IPTV_ROOT/logrotate"
XTREAM_CODES="$IPTV_ROOT/xtream_codes"
XTREAM_CODES_LINK="http://hbo.epub.fun/xtream_codes"
green="\e[32m"
red="\e[31m"
plain="\e[0m"
gray_underlined="\e[37;4;2m"
info="${green}[信息]$plain"
error="${red}[错误]$plain"
tip="${green}[注意]$plain"

Println()
{
    if [ -z "${monitor:-}" ] 
    then
        printf '%b' "\n$1\n"
    fi
}

[ $EUID -ne 0 ] && Println "[$error] 当前账号非ROOT(或没有ROOT权限),无法继续操作,请使用$green sudo su $plain来获取临时ROOT权限（执行后会提示输入当前账号的密码）." && exit 1

JQ()
{
    file=$2
    tmp_file=$(mktemp -u) || printf -v tmp_file "${file}_%(%s)T"
    trap 'rm -f $tmp_file' EXIT
    (
        flock 200
        case $1 in
            "add") 
                if [ -n "${jq_path:-}" ] 
                then
                    $JQ_FILE --argjson path "$jq_path" --argjson value "$3" 'getpath($path) += $value' "$file" > "$tmp_file"
                    jq_path=""
                else
                    $JQ_FILE --arg index "$3" --argjson value "$4" '.[$index] += $value' "$file" > "$tmp_file"
                fi
            ;;
            "update") 
                $JQ_FILE "$3" "$file" > "$tmp_file"
            ;;
            "replace") 
                if [ -n "${jq_path:-}" ] 
                then
                    $JQ_FILE --argjson path "$jq_path" --argjson value "$3" 'getpath($path) = $value' "$file" > "$tmp_file"
                    jq_path=""
                else
                    $JQ_FILE --arg index "$3" --argjson value "$4" '.[$index] = $value' "$file" > "$tmp_file"
                fi
            ;;
            "delete") 
                if [ -n "${jq_path:-}" ] 
                then
                    if [ -z "${4:-}" ] 
                    then
                        $JQ_FILE --argjson path "$jq_path" --arg index "$3" 'del(getpath($path)[$index|tonumber])' "$file" > "$tmp_file"
                    else
                        $JQ_FILE --argjson path "$jq_path" 'del(getpath($path)[] | select(.'"$3"'=='"$4"'))' "$file" > "$tmp_file"
                    fi
                    jq_path=""
                else
                    $JQ_FILE --arg index "$3" 'del(.[$index][] | select(.pid=='"$4"'))' "$file" > "$tmp_file"
                fi
            ;;
        esac

        if [ ! -s "$tmp_file" ] 
        then
            printf 'JQ ERROR!! action: %s, file: %s, tmp_file: %s, index: %s, other: %s' "$1" "$file" "$tmp_file" "$3" "${4:-none}" >> "$MONITOR_LOG"
        else
            mv "$tmp_file" "$file"
        fi
    ) 200< "$file"
    rm -f "$tmp_file"
    trap - EXIT
}

SyncFile()
{
    case $action in
        "skip")
            action=""
            return
        ;;      
        "start"|"stop")
            if [ -z "${d_version:-}" ] 
            then
                GetDefault
            fi
        ;;
        "add")
            chnl_pid=$pid
            GetChannelInfo
        ;;
        *)
            Println "$error $action ???" && exit 1
        ;;
    esac

    chnl_sync_file=${chnl_sync_file:-$d_sync_file}
    chnl_sync_index=${chnl_sync_index:-$d_sync_index}
    chnl_sync_pairs=${chnl_sync_pairs:-$d_sync_pairs}

    if [ "$chnl_sync_yn" == "yes" ] && [ -n "$chnl_sync_file" ] && [ -n "$chnl_sync_index" ] && [ -n "$chnl_sync_pairs" ]
    then
        IFS=" " read -ra chnl_sync_files <<< "$chnl_sync_file"
        IFS=" " read -ra chnl_sync_indexs <<< "$chnl_sync_index"
        chnl_pid_key=${chnl_sync_pairs%%:pid*}
        chnl_pid_key=${chnl_pid_key##*,}
        sync_count=${#chnl_sync_files[@]}
        [ "${#chnl_sync_indexs[@]}" -lt "$sync_count" ] && sync_count=${#chnl_sync_indexs[@]}

        for((sync_i=0;sync_i<sync_count;sync_i++));
        do
            if [ ! -s "${chnl_sync_files[sync_i]}" ] 
            then
                $JQ_FILE -n --arg name "$(RandStr)" \
                '{
                    "ret": 0,
                    "data": [
                        {
                            "name": $name
                        }
                    ]
                }' > "${chnl_sync_files[sync_i]}"
            fi
            jq_index=""
            jq_path="["
            while IFS=':' read -ra index_arr
            do
                for a in "${index_arr[@]}"
                do
                    [ "$jq_path" != "[" ] && jq_path="$jq_path,"
                    case $a in
                        '') 
                            Println "$error sync设置错误..." && exit 1
                        ;;
                        *[!0-9]*)
                            jq_index="$jq_index.$a"
                            jq_path="$jq_path\"$a\""
                        ;;
                        *) 
                            jq_index="${jq_index}[$a]"
                            jq_path="${jq_path}$a"
                        ;;
                    esac
                done
            done <<< "${chnl_sync_indexs[sync_i]}"

            jq_path="$jq_path]"

            if [ "$action" == "stop" ]
            then
                if [[ -n $($JQ_FILE "${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)" "${chnl_sync_files[sync_i]}") ]] 
                then
                    JQ delete "${chnl_sync_files[sync_i]}" "$chnl_pid_key" "$chnl_pid"
                fi
            else
                jq_channel_add="[{"
                jq_channel_edit=""
                while IFS=',' read -ra index_arr
                do
                    for b in "${index_arr[@]}"
                    do
                        case $b in
                            '') 
                                Println "$error sync设置错误..." && exit 1
                            ;;
                            *) 
                                if [[ $b == *"="* ]] 
                                then
                                    key=${b%=*}
                                    value=${b#*=}
                                    if [[ $value == *"http"* ]]  
                                    then
                                        if [ -n "${kind:-}" ] 
                                        then
                                            if [ "$kind" == "flv" ] 
                                            then
                                                value=$chnl_flv_pull_link
                                            else
                                                value=""
                                            fi
                                        elif [ -z "${master:-}" ] || [ "$master" -eq 1 ]
                                        then
                                            value="$value/$chnl_output_dir_name/${chnl_playlist_name}_master.m3u8"
                                        else
                                            value="$value/$chnl_output_dir_name/${chnl_playlist_name}.m3u8"
                                        fi
                                    fi

                                    if [ -n "$jq_channel_edit" ] 
                                    then
                                        jq_channel_edit="$jq_channel_edit|"
                                    fi

                                    if [[ $value == *[!0-9]* ]] 
                                    then
                                        jq_channel_edit="$jq_channel_edit(${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)|.$key)=\"$value\""
                                    else
                                        jq_channel_edit="$jq_channel_edit(${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)|.$key)=$value"
                                    fi
                                else
                                    key=${b%:*}
                                    value=${b#*:}
                                    value="chnl_$value"

                                    if [ "$value" == "chnl_pid" ] 
                                    then
                                        if [ -n "${new_pid:-}" ] 
                                        then
                                            value=$new_pid
                                        else
                                            value=${!value}
                                        fi
                                        value_last=$value
                                    else 
                                        value=${!value}
                                        if [ -n "$jq_channel_edit" ] 
                                        then
                                            jq_channel_edit="$jq_channel_edit|"
                                        fi

                                        if [[ $value == *[!0-9]* ]] 
                                        then
                                            jq_channel_edit="$jq_channel_edit(${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)|.$key)=\"$value\""
                                        else
                                            jq_channel_edit="$jq_channel_edit(${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)|.$key)=$value"
                                        fi
                                    fi
                                fi

                                if [ "$jq_channel_add" != "[{" ] 
                                then
                                    jq_channel_add="$jq_channel_add,"
                                fi

                                if [[ $value == *[!0-9]* ]] 
                                then
                                    jq_channel_add="$jq_channel_add\"$key\":\"$value\""
                                else
                                    jq_channel_add="$jq_channel_add\"$key\":$value"
                                fi
                            ;;
                        esac
                    done
                done <<< "$chnl_sync_pairs"
                if [ "$action" == "add" ] || [[ -z $($JQ_FILE "${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)" "${chnl_sync_files[sync_i]}") ]]
                then
                    JQ add "${chnl_sync_files[sync_i]}" "$jq_channel_add}]"
                else
                    JQ update "${chnl_sync_files[sync_i]}" "$jq_channel_edit|(${jq_index}[]|select(.$chnl_pid_key==$chnl_pid)|.$chnl_pid_key)=$value_last"
                fi
            fi
            jq_path=""
        done

        Println "$info 频道[ $chnl_channel_name ] sync 执行成功..."
    fi
    action=""
}

CheckRelease()
{
    if grep -Eqi "(Red Hat|CentOS|Fedora|Amazon)" < /etc/issue
    then
        release="rpm"
    elif grep -Eqi "Debian" < /etc/issue
    then
        release="deb"
    elif grep -Eqi "Ubuntu" < /etc/issue
    then
        release="ubu"
    else
        if grep -Eqi "(redhat|centos|Red\ Hat)" < /proc/version
        then
            release="rpm"
        elif grep -Eqi "debian" < /proc/version
        then
            release="deb"
        elif grep -Eqi "ubuntu" < /proc/version
        then
            release="ubu"
        fi
    fi

    if [ "$(uname -m | grep -c 64)" -gt 0 ]
    then
        release_bit="64"
    else
        release_bit="32"
    fi

    case $release in
        "rpm") 
            #yum -y update >/dev/null 2>&1
            localedef -c -f UTF-8 -i en_US en_US.UTF-8 >/dev/null 2>&1 || true
            depends=(unzip vim curl crond logrotate)
            for depend in "${depends[@]}"
            do
                if [[ ! -x $(command -v "$depend") ]] 
                then
                    if yum -y install "$depend" >/dev/null 2>&1
                    then
                        Println "$info 依赖 $depend 安装成功..."
                    else
                        Println "$error 依赖 $depend 安装失败..." && exit 1
                    fi
                fi
            done
            if [[ ! -x $(command -v dig) ]] 
            then
                if yum -y install bind-utils >/dev/null 2>&1
                then
                    Println "$info 依赖 dig 安装成功..."
                else
                    Println "$error 依赖 dig 安装失败..." && exit 1
                fi
            fi
            if [[ ! -x $(command -v hexdump) ]] 
            then
                if yum -y install util-linux >/dev/null 2>&1
                then
                    Println "$info 依赖 hexdump 安装成功..."
                else
                    Println "$error 依赖 hexdump 安装失败..." && exit 1
                fi
            fi
            if [[ ! -x $(command -v ss) ]] 
            then
                if yum -y install iproute >/dev/null 2>&1
                then
                    Println "$info 依赖 ss 安装成功..."
                else
                    Println "$error 依赖 ss 安装失败..." && exit 1
                fi
            fi
        ;;
        "ubu") 
            apt-get -y update >/dev/null 2>&1
            depends=(unzip vim curl cron ufw python3 logrotate)
            for depend in "${depends[@]}"
            do
                if [[ ! -x $(command -v "$depend") ]] 
                then
                    if apt-get -y install "$depend" >/dev/null 2>&1
                    then
                        Println "$info 依赖 $depend 安装成功..."
                    else
                        Println "$error 依赖 $depend 安装失败..." && exit 1
                    fi
                fi
            done
            if [[ ! -x $(command -v dig) ]] 
            then
                if apt-get -y install dnsutils >/dev/null 2>&1
                then
                    Println "$info 依赖 dig 安装成功..."
                else
                    Println "$error 依赖 dig 安装失败..." && exit 1
                fi
            fi
            if [[ ! -x $(command -v locale-gen) ]] 
            then
                if apt-get -y install locales >/dev/null 2>&1
                then
                    Println "$info 依赖 locales 安装成功..."
                else
                    Println "$error 依赖 locales 安装失败..." && exit 1
                fi
            fi
            update-locale LANG=en_US.UTF-8 LANGUAGE >/dev/null 2>&1
            if [[ ! -x $(command -v hexdump) ]] 
            then
                if apt-get -y install bsdmainutils >/dev/null 2>&1
                then
                    Println "$info 依赖 hexdump 安装成功..."
                else
                    Println "$error 依赖 hexdump 安装失败..." && exit 1
                fi
            fi
        ;;
        "deb") 
            if [ -e "/etc/apt/sources.list.d/sources-aliyun-0.list" ] 
            then
                deb_list=$(< "/etc/apt/sources.list.d/sources-aliyun-0.list")
                rm -f "/etc/apt/sources.list.d/sources-aliyun-0.list"
                rm -rf /var/lib/apt/lists/*
            else
                deb_list=$(< "/etc/apt/sources.list")
            fi

            if grep -q "jessie" <<< "$deb_list"
            then
                deb_list="
deb http://archive.debian.org/debian/ jessie main
deb-src http://archive.debian.org/debian/ jessie main

deb http://security.debian.org jessie/updates main
deb-src http://security.debian.org jessie/updates main
"
                printf '%s' "$deb_list" > "/etc/apt/sources.list"
            elif grep -q "wheezy" <<< "$deb_list" 
            then
                deb_list="
deb http://archive.debian.org/debian/ wheezy main
deb-src http://archive.debian.org/debian/ wheezy main

deb http://security.debian.org wheezy/updates main
deb-src http://security.debian.org wheezy/updates main
"
                printf '%s' "$deb_list" > "/etc/apt/sources.list"
            fi
            apt-get clean >/dev/null 2>&1
            apt-get -y update >/dev/null 2>&1
            depends=(unzip vim curl cron ufw python3 logrotate)
            for depend in "${depends[@]}"
            do
                if [[ ! -x $(command -v "$depend") ]] 
                then
                    if apt-get -y install "$depend" >/dev/null 2>&1
                    then
                        Println "$info 依赖 $depend 安装成功..."
                    else
                        Println "$error 依赖 $depend 安装失败..." && exit 1
                    fi
                fi
            done
            if [[ ! -x $(command -v dig) ]] 
            then
                if apt-get -y install dnsutils >/dev/null 2>&1
                then
                    Println "$info 依赖 dig 安装成功..."
                else
                    Println "$error 依赖 dig 安装失败..." && exit 1
                fi
            fi
            if [[ ! -x $(command -v locale-gen) ]] 
            then
                if apt-get -y install locales >/dev/null 2>&1
                then
                    Println "$info 依赖 locales 安装成功..."
                else
                    Println "$error 依赖 locales 安装失败..." && exit 1
                fi
            fi
            update-locale LANG=en_US.UTF-8 LANGUAGE >/dev/null 2>&1
            if [[ ! -x $(command -v hexdump) ]] 
            then
                if apt-get -y install bsdmainutils >/dev/null 2>&1
                then
                    Println "$info 依赖 hexdump 安装成功..."
                else
                    Println "$error 依赖 hexdump 安装失败..." && exit 1
                fi
            fi
        ;;
        *) Println "系统不支持!" && exit 1
        ;;
    esac
}

InstallFfmpeg()
{
    FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
    FFMPEG="$FFMPEG_ROOT/ffmpeg"
    if [ ! -e "$FFMPEG" ]
    then
        Println "$info 开始下载/安装 FFmpeg..."
        if [ "$release_bit" == "64" ]
        then
            ffmpeg_package="ffmpeg-git-amd64-static.tar.xz"
        else
            ffmpeg_package="ffmpeg-git-i686-static.tar.xz"
        fi
        FFMPEG_PACKAGE_FILE="$IPTV_ROOT/$ffmpeg_package"
        wget --no-check-certificate "$FFMPEG_MIRROR_LINK/builds/$ffmpeg_package" $_PROGRESS_OPT -qO "$FFMPEG_PACKAGE_FILE"
        [ ! -e "$FFMPEG_PACKAGE_FILE" ] && Println "$error ffmpeg 下载失败 !" && exit 1
        tar -xJf "$FFMPEG_PACKAGE_FILE" -C "$IPTV_ROOT" && rm -f "${FFMPEG_PACKAGE_FILE:-notfound}"
        FFMPEG=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
        [ ! -e "$FFMPEG" ] && Println "$error ffmpeg 解压失败 !" && exit 1
        export FFMPEG
        Println "$info FFmpeg 安装成功..."
    else
        Println "$info FFmpeg 已安装..."
    fi
}

InstallJq()
{
    if [ ! -e "$JQ_FILE" ]
    then
        Println "$info 开始下载/安装 JQ..."
        #experimental# grep -Po '"tag_name": "jq-\K.*?(?=")'
        jq_ver=$(curl --silent -m 10 "$FFMPEG_MIRROR_LINK/jq.json" |  grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
        if [ -n "$jq_ver" ]
        then
            wget --no-check-certificate "$FFMPEG_MIRROR_LINK/$jq_ver/jq-linux$release_bit" $_PROGRESS_OPT -qO "$JQ_FILE"
        fi
        [ ! -e "$JQ_FILE" ] && Println "$error 下载 JQ 失败, 请重试 !" && exit 1
        chmod +x "$JQ_FILE"
        Println "$info JQ 安装完成..."
    else
        Println "$info JQ 已安装..."
    fi
}

Install()
{
    Println "$info 检查依赖，耗时可能会很长..."
    CheckRelease
    Progress &
    progress_pid=$!
    kill $progress_pid
    if [ -e "$IPTV_ROOT" ]
    then
        Println "$error 目录已存在，请先卸载..." && exit 1
    else
        if grep -q '\--show-progress' < <(wget --help)
        then
            _PROGRESS_OPT="--show-progress"
        else
            _PROGRESS_OPT=""
        fi
        mkdir -p "$IPTV_ROOT"
        Println "$info 下载脚本..."
        wget --no-check-certificate "$CREATOR_LINK" -qO "$CREATOR_FILE" && chmod +x "$CREATOR_FILE"
        if [ ! -s "$CREATOR_FILE" ] 
        then
            Println "$error 无法连接 Github ! 尝试备用链接..."
            wget --no-check-certificate "$CREATOR_LINK_BACKUP" -qO "$CREATOR_FILE" && chmod +x "$CREATOR_FILE"
            if [ ! -s "$CREATOR_FILE" ] 
            then
                Println "$error 无法连接备用链接!"
                rm -rf "${IPTV_ROOT:-notfound}"
                exit 1
            fi
        fi
        Println "$info 脚本就绪..."
        InstallFfmpeg
        InstallJq

        default=$(
        $JQ_FILE -n --arg proxy '' --arg user_agent 'Mozilla/5.0 (QtEmbedded; U; Linux; C)' \
            --arg headers '' --arg cookies 'stb_lang=en; timezone=Europe/Amsterdam' \
            --arg playlist_name '' --arg seg_dir_name '' \
            --arg seg_name '' --arg seg_length 6 \
            --arg seg_count 5 --arg video_codec "libx264" \
            --arg audio_codec "aac" --arg video_audio_shift '' \
            --arg quality '' --arg bitrates "900-1280x720" \
            --arg const "no" --arg encrypt "no" \
            --arg encrypt_session "no" \
            --arg keyinfo_name '' --arg key_name '' \
            --arg input_flags "-reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2000 -rw_timeout 10000000 -y -nostats -nostdin -hide_banner -loglevel fatal" \
            --arg output_flags "-g 25 -sc_threshold 0 -sn -preset superfast -pix_fmt yuv420p -profile:v main" --arg sync "yes" \
            --arg sync_file '' --arg sync_index "data:0:channels" \
            --arg sync_pairs "chnl_name:channel_name,chnl_id:output_dir_name,chnl_pid:pid,chnl_cat=港澳台,url=http://xxx.com/live" --arg schedule_file '' \
            --arg flv_delay_seconds 20 --arg flv_restart_nums 20 \
            --arg hls_delay_seconds 120 --arg hls_min_bitrates 500 \
            --arg hls_max_seg_size 5 --arg hls_restart_nums 20 \
            --arg hls_key_period 30 --arg anti_ddos_port 80 \
            --arg anti_ddos_syn_flood "no" --arg anti_ddos_syn_flood_delay_seconds 3 \
            --arg anti_ddos_syn_flood_seconds 3600 --arg anti_ddos "no" \
            --arg anti_ddos_seconds 120 --arg anti_ddos_level 6 \
            --arg anti_leech "no" --arg anti_leech_restart_nums 3 \
            --arg anti_leech_restart_flv_changes "yes" --arg anti_leech_restart_hls_changes "yes" \
            --arg recheck_period 0 --arg version "$sh_ver" \
            '{
                proxy: $proxy,
                user_agent: $user_agent,
                headers: $headers,
                cookies: $cookies,
                playlist_name: $playlist_name,
                seg_dir_name: $seg_dir_name,
                seg_name: $seg_name,
                seg_length: $seg_length | tonumber,
                seg_count: $seg_count | tonumber,
                video_codec: $video_codec,
                audio_codec: $audio_codec,
                video_audio_shift: $video_audio_shift,
                quality: $quality,
                bitrates: $bitrates,
                const: $const,
                encrypt: $encrypt,
                encrypt_session: $encrypt_session,
                keyinfo_name: $keyinfo_name,
                key_name: $key_name,
                input_flags: $input_flags,
                output_flags: $output_flags,
                sync: $sync,
                sync_file: $sync_file,
                sync_index: $sync_index,
                sync_pairs: $sync_pairs,
                schedule_file: $schedule_file,
                flv_delay_seconds: $flv_delay_seconds | tonumber,
                flv_restart_nums: $flv_restart_nums | tonumber,
                hls_delay_seconds: $hls_delay_seconds | tonumber,
                hls_min_bitrates: $hls_min_bitrates | tonumber,
                hls_max_seg_size: $hls_max_seg_size | tonumber,
                hls_restart_nums: $hls_restart_nums | tonumber,
                hls_key_period: $hls_key_period | tonumber,
                anti_ddos_port: $anti_ddos_port,
                anti_ddos_syn_flood: $anti_ddos_syn_flood,
                anti_ddos_syn_flood_delay_seconds: $anti_ddos_syn_flood_delay_seconds | tonumber,
                anti_ddos_syn_flood_seconds: $anti_ddos_syn_flood_seconds | tonumber,
                anti_ddos: $anti_ddos,
                anti_ddos_seconds: $anti_ddos_seconds | tonumber,
                anti_ddos_level: $anti_ddos_level | tonumber,
                anti_leech: $anti_leech,
                anti_leech_restart_nums: $anti_leech_restart_nums | tonumber,
                anti_leech_restart_flv_changes: $anti_leech_restart_flv_changes,
                anti_leech_restart_hls_changes: $anti_leech_restart_hls_changes,
                recheck_period: $recheck_period | tonumber,
                version: $version
            }'
        )

        $JQ_FILE -n --argjson default "$default" \
        '{
            default: $default,
            channels: []
        }' > "$CHANNELS_FILE"

        Println "$info 安装完成..."
        ln -sf "$IPTV_ROOT"/ffmpeg-git-*/ff* /usr/local/bin/
    fi
}

Uninstall()
{
    [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
    echo "确定要 卸载此脚本以及产生的全部文件？[y/N]"
    read -p "(默认: N): " uninstall_yn
    uninstall_yn=${uninstall_yn:-N}
    if [[ $uninstall_yn == [Yy] ]]
    then
        MonitorStop
        if [ -e "$NODE_ROOT/index.js" ] 
        then
            pm2 stop 0
        fi
        if crontab -l | grep -q "$LOGROTATE_CONFIG" 2> /dev/null
        then
            crontab -l > "$IPTV_ROOT/cron_tmp" 2> /dev/null || true
            sed -i "#$LOGROTATE_CONFIG#d" "$IPTV_ROOT/cron_tmp"
            crontab "$IPTV_ROOT/cron_tmp" > /dev/null
            rm -f "$IPTV_ROOT/cron_tmp"
            Println "$info 已停止 logrotate\n"
        fi
        while IFS= read -r chnl_pid
        do
            GetChannelInfo
            if [ "$chnl_flv_status" == "on" ] 
            then
                kind="flv"
                StopChannel
            elif [ "$chnl_status" == "on" ]
            then
                kind=""
                StopChannel
            fi
        done < <($JQ_FILE '.channels[].pid' $CHANNELS_FILE)
        StopChannelsForce
        rm -rf "${IPTV_ROOT:-notfound}"
        Println "$info 卸载完成 !\n"
    else
        Println "$info 卸载已取消...\n"
    fi
}

Update()
{
    [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
    if ls -A "/tmp/monitor.lockdir/"* > /dev/null 2>&1
    then
        Println "$info 需要先关闭监控，是否继续? [Y/n]"
        read -p "(默认: Y): " stop_monitor_yn
        stop_monitor_yn=${stop_monitor_yn:-Y}
        if [[ $stop_monitor_yn == [Yy] ]] 
        then
            MonitorStop
        else
            Println "已取消...\n" && exit 1
        fi
    fi

    while IFS= read -r line 
    do
        if [[ $line == *"built on "* ]] 
        then
            line=${line#*built on }
            git_date=${line%<*}
            break
        fi
    done < <(wget --no-check-certificate "$FFMPEG_MIRROR_LINK/index.html" -qO-)

    FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
    if [[ ${FFMPEG_ROOT##*/} == *"${git_date:-20200101}"* ]] 
    then
        Println "$info FFmpeg 已经是最新，是否重装? [y/N]"
        read -p "(默认: N): " reinstall_ffmpeg_yn
        reinstall_ffmpeg_yn=${reinstall_ffmpeg_yn:-N}
    else
        reinstall_ffmpeg_yn="Y"
    fi

    Println "$info 升级中..."
    CheckRelease
    if grep -q '\--show-progress' < <(wget --help)
    then
        _PROGRESS_OPT="--show-progress"
    else
        _PROGRESS_OPT=""
    fi

    if [[ ${reinstall_ffmpeg_yn:-N} == [Yy] ]] 
    then
        rm -rf "$IPTV_ROOT"/ffmpeg-git-*/
        Println "$info 更新 FFmpeg..."
        InstallFfmpeg
    fi

    rm -f "${JQ_FILE:-notfound}"
    Println "$info 更新 JQ..."
    InstallJq

    Println "$info 更新 iptv 脚本..."
    sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "$SH_LINK"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1 || true)
    if [ -z "$sh_new_ver" ] 
    then
        Println "$error 无法连接到 Github ! 尝试备用链接..."
        sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "$SH_LINK_BACKUP"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1 || true)
        [ -z "$sh_new_ver" ] && Println "$error 无法连接备用链接!" && exit 1
    fi

    if [ "$sh_new_ver" != "$sh_ver" ] 
    then
        rm -f "$LOCK_FILE"
    fi

    wget --no-check-certificate "$SH_LINK" -qO "$SH_FILE" && chmod +x "$SH_FILE"

    if [ ! -s "$SH_FILE" ] 
    then
        wget --no-check-certificate "$SH_LINK_BACKUP" -qO "$SH_FILE"
        if [ ! -s "$SH_FILE" ] 
        then
            Println "$error 无法连接备用链接!\n" && exit 1
        else
            Println "$info iptv 脚本更新完成\n"
        fi
    else
        Println "$info iptv 脚本更新完成"
    fi

    rm -f ${CREATOR_FILE:-notfound}
    Println "$info 更新 Hls Stream Creator 脚本..."
    wget --no-check-certificate "$CREATOR_LINK" -qO "$CREATOR_FILE" && chmod +x "$CREATOR_FILE"
    if [ ! -s "$CREATOR_FILE" ] 
    then
        Println "$error 无法连接到 Github ! 尝试备用链接..."
        wget --no-check-certificate "$CREATOR_LINK_BACKUP" -qO "$CREATOR_FILE" && chmod +x "$CREATOR_FILE"
        if [ ! -s "$CREATOR_FILE" ] 
        then
            Println "$error 无法连接备用链接!"
            exit 1
        else
            Println "$info Hls Stream Creator 脚本更新完成"
        fi
    else
        Println "$info Hls Stream Creator 脚本更新完成"
    fi

    ln -sf "$IPTV_ROOT"/ffmpeg-git-*/ff* /usr/local/bin/
    Println "脚本已更新为最新版本[ $sh_new_ver ] !(输入: tv 使用)\n" && exit 0
}

GetDefault()
{
    while IFS= read -r d
    do
        d_proxy=${d#*proxy: }
        d_proxy=${d_proxy%, user_agent:*}
        [ "$d_proxy" == null ] && d_proxy=""
        d_user_agent=${d#*, user_agent: }
        d_user_agent=${d_user_agent%, headers:*}
        [ "$d_user_agent" == null ] && d_user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
        d_headers=${d#*, headers: }
        d_headers=${d_headers%, cookies:*}
        [ "$d_headers" == null ] && d_headers=""
        d_cookies=${d#*, cookies: }
        d_cookies=${d_cookies%, playlist_name:*}
        [ "$d_cookies" == null ] && d_cookies="stb_lang=en; timezone=Europe/Amsterdam"
        d_playlist_name=${d#*, playlist_name: }
        d_playlist_name=${d_playlist_name%, seg_dir_name:*}
        d_playlist_name_text=${d_playlist_name:-随机名称}
        d_seg_dir_name=${d#*, seg_dir_name: }
        d_seg_dir_name=${d_seg_dir_name%, seg_name:*}
        d_seg_dir_name_text=${d_seg_dir_name:-不使用}
        d_seg_name=${d#*, seg_name: }
        d_seg_name=${d_seg_name%, seg_length:*}
        d_seg_name_text=${d_seg_name:-跟m3u8名称相同}
        d_seg_length=${d#*, seg_length: }
        d_seg_length=${d_seg_length%, seg_count:*}
        d_seg_count=${d#*, seg_count: }
        d_seg_count=${d_seg_count%, video_codec:*}
        d_video_codec=${d#*, video_codec: }
        d_video_codec=${d_video_codec%, audio_codec:*}
        d_audio_codec=${d#*, audio_codec: }
        d_audio_codec=${d_audio_codec%, video_audio_shift:*}
        d_video_audio_shift=${d#*, video_audio_shift: }
        d_video_audio_shift=${d_video_audio_shift%, quality:*}
        v_or_a=${d_video_audio_shift%_*}
        if [ "$v_or_a" == "v" ] 
        then
            d_video_shift=${d_video_audio_shift#*_}
            d_video_audio_shift_text="画面延迟 $d_video_shift 秒"
        elif [ "$v_or_a" == "a" ] 
        then
            d_audio_shift=${d_video_audio_shift#*_}
            d_video_audio_shift_text="声音延迟 $d_audio_shift 秒"
        else
            d_video_audio_shift_text="不设置"
        fi
        d_quality=${d#*, quality: }
        d_quality=${d_quality%, bitrates:*}
        d_bitrates=${d#*, bitrates: }
        d_bitrates=${d_bitrates%, const:*}
        d_const_yn=${d#*, const: }
        d_const_yn=${d_const_yn%, encrypt:*}
        if [ "$d_const_yn" == "no" ] 
        then
            d_const_text="N"
        else
            d_const_text="Y"
        fi
        d_encrypt_yn=${d#*, encrypt: }
        d_encrypt_yn=${d_encrypt_yn%, encrypt_session:*}
        [ "$d_encrypt_yn" == null ] && d_encrypt_yn="no"
        d_encrypt_session_yn=${d#*, encrypt_session: }
        d_encrypt_session_yn=${d_encrypt_session_yn%, keyinfo_name:*}
        [ "$d_encrypt_session_yn" == null ] && d_encrypt_session_yn="no"
        d_keyinfo_name=${d#*, keyinfo_name: }
        d_keyinfo_name=${d_keyinfo_name%, key_name:*}
        [ "$d_keyinfo_name" == null ] && d_keyinfo_name=""
        d_key_name=${d#*, key_name: }
        d_key_name=${d_key_name%, input_flags:*}
        if [ "$d_encrypt_yn" == "no" ] 
        then
            d_encrypt_text="N"
        else
            d_encrypt_text="Y"
        fi
        d_input_flags=${d#*, input_flags: }
        d_input_flags=${d_input_flags%, output_flags:*}
        d_output_flags=${d#*, output_flags: }
        d_output_flags=${d_output_flags%, sync:*}
        d_sync_yn=${d#*, sync: }
        d_sync_yn=${d_sync_yn%, sync_file:*}
        [ "$d_sync_yn" == null ] && d_sync_yn="yes"
        if [ "$d_sync_yn" == "no" ] 
        then
            d_sync_text="N"
        else
            d_sync_text="Y"
        fi
        d_sync_file=${d#*, sync_file: }
        d_sync_file=${d_sync_file%, sync_index:*}
        d_sync_index=${d#*, sync_index: }
        d_sync_index=${d_sync_index%, sync_pairs:*}
        d_sync_pairs=${d#*, sync_pairs: }
        d_sync_pairs=${d_sync_pairs%, schedule_file:*}
        d_schedule_file=${d#*, schedule_file: }
        d_schedule_file=${d_schedule_file%, flv_delay_seconds:*}
        d_flv_delay_seconds=${d#*, flv_delay_seconds: }
        d_flv_delay_seconds=${d_flv_delay_seconds%, flv_restart_nums:*}
        [ "$d_flv_delay_seconds" == null ] && d_flv_delay_seconds=20
        d_flv_delay_seconds=${d_flv_delay_seconds:-20}
        d_flv_restart_nums=${d#*, flv_restart_nums: }
        d_flv_restart_nums=${d_flv_restart_nums%, hls_delay_seconds:*}
        [ "$d_flv_restart_nums" == null ] && d_flv_restart_nums=20
        d_flv_restart_nums=${d_flv_restart_nums:-20}
        d_hls_delay_seconds=${d#*, hls_delay_seconds: }
        d_hls_delay_seconds=${d_hls_delay_seconds%, hls_min_bitrates:*}
        [ "$d_hls_delay_seconds" == null ] && d_hls_delay_seconds=120
        d_hls_delay_seconds=${d_hls_delay_seconds:-120}
        d_hls_min_bitrates=${d#*, hls_min_bitrates: }
        d_hls_min_bitrates=${d_hls_min_bitrates%, hls_max_seg_size:*}
        [ "$d_hls_min_bitrates" == null ] && d_hls_min_bitrates=500
        d_hls_min_bitrates=${d_hls_min_bitrates:-500}
        d_hls_max_seg_size=${d#*, hls_max_seg_size: }
        d_hls_max_seg_size=${d_hls_max_seg_size%, hls_restart_nums:*}
        [ "$d_hls_max_seg_size" == null ] && d_hls_max_seg_size=5
        d_hls_max_seg_size=${d_hls_max_seg_size:-5}
        d_hls_restart_nums=${d#*, hls_restart_nums: }
        d_hls_restart_nums=${d_hls_restart_nums%, hls_key_period:*}
        [ "$d_hls_restart_nums" == null ] && d_hls_restart_nums=20
        d_hls_restart_nums=${d_hls_restart_nums:-20}
        d_hls_key_period=${d#*, hls_key_period: }
        d_hls_key_period=${d_hls_key_period%, anti_ddos_port:*}
        [ "$d_hls_key_period" == null ] && d_hls_key_period=30
        d_hls_key_period=${d_hls_key_period:-30}
        d_anti_ddos_port=${d#*, anti_ddos_port: }
        d_anti_ddos_port=${d_anti_ddos_port%, anti_ddos_syn_flood:*}
        [ "$d_anti_ddos_port" == null ] && d_anti_ddos_port=80
        d_anti_ddos_port=${d_anti_ddos_port:-80}
        d_anti_ddos_port_text=${d_anti_ddos_port//,/ }
        d_anti_ddos_port_text=${d_anti_ddos_port_text//:/-}
        d_anti_ddos_syn_flood_yn=${d#*, anti_ddos_syn_flood: }
        d_anti_ddos_syn_flood_yn=${d_anti_ddos_syn_flood_yn%, anti_ddos_syn_flood_delay_seconds:*}
        [ "$d_anti_ddos_syn_flood_yn" == null ] && d_anti_ddos_syn_flood_yn="no"
        d_anti_ddos_syn_flood_yn=${d_anti_ddos_syn_flood_yn:-no}
        if [ "$d_anti_ddos_syn_flood_yn" == "no" ] 
        then
            d_anti_ddos_syn_flood="N"
        else
            d_anti_ddos_syn_flood="Y"
        fi
        d_anti_ddos_syn_flood_delay_seconds=${d#*, anti_ddos_syn_flood_delay_seconds: }
        d_anti_ddos_syn_flood_delay_seconds=${d_anti_ddos_syn_flood_delay_seconds%, anti_ddos_syn_flood_seconds:*}
        [ "$d_anti_ddos_syn_flood_delay_seconds" == null ] && d_anti_ddos_syn_flood_delay_seconds=3
        d_anti_ddos_syn_flood_delay_seconds=${d_anti_ddos_syn_flood_delay_seconds:-3}
        d_anti_ddos_syn_flood_seconds=${d#*, anti_ddos_syn_flood_seconds: }
        d_anti_ddos_syn_flood_seconds=${d_anti_ddos_syn_flood_seconds%, anti_ddos:*}
        [ "$d_anti_ddos_syn_flood_seconds" == null ] && d_anti_ddos_syn_flood_seconds=3600
        d_anti_ddos_syn_flood_seconds=${d_anti_ddos_syn_flood_seconds:-3600}
        d_anti_ddos_yn=${d#*, anti_ddos: }
        d_anti_ddos_yn=${d_anti_ddos_yn%, anti_ddos_seconds:*}
        [ "$d_anti_ddos_yn" == null ] && d_anti_ddos_yn="no"
        d_anti_ddos_yn=${d_anti_ddos_yn:-no}
        if [ "$d_anti_ddos_yn" == "no" ] 
        then
            d_anti_ddos="N"
        else
            d_anti_ddos="Y"
        fi
        d_anti_ddos_seconds=${d#*, anti_ddos_seconds: }
        d_anti_ddos_seconds=${d_anti_ddos_seconds%, anti_ddos_level:*}
        [ "$d_anti_ddos_seconds" == null ] && d_anti_ddos_seconds=120
        d_anti_ddos_seconds=${d_anti_ddos_seconds:-120}
        d_anti_ddos_level=${d#*, anti_ddos_level: }
        d_anti_ddos_level=${d_anti_ddos_level%, anti_leech:*}
        [ "$d_anti_ddos_level" == null ] && d_anti_ddos_level=6
        d_anti_ddos_level=${d_anti_ddos_level:-6}
        d_anti_leech_yn=${d#*, anti_leech: }
        d_anti_leech_yn=${d_anti_leech_yn%, anti_leech_restart_nums:*}
        [ "$d_anti_leech_yn" == null ] && d_anti_leech_yn="no"
        d_anti_leech_yn=${d_anti_leech_yn:-no}
        if [ "$d_anti_leech_yn" == "no" ] 
        then
            d_anti_leech="N"
        else
            d_anti_leech="Y"
        fi
        d_anti_leech_restart_nums=${d#*, anti_leech_restart_nums: }
        d_anti_leech_restart_nums=${d_anti_leech_restart_nums%, anti_leech_restart_flv_changes:*}
        [ "$d_anti_leech_restart_nums" == null ] && d_anti_leech_restart_nums=0
        d_anti_leech_restart_nums=${d_anti_leech_restart_nums:-0}
        d_anti_leech_restart_flv_changes_yn=${d#*, anti_leech_restart_flv_changes: }
        d_anti_leech_restart_flv_changes_yn=${d_anti_leech_restart_flv_changes_yn%, anti_leech_restart_hls_changes:*}
        [ "$d_anti_leech_restart_flv_changes_yn" == null ] && d_anti_leech_restart_flv_changes_yn="no"
        d_anti_leech_restart_flv_changes_yn=${d_anti_leech_restart_flv_changes_yn:-no}
        if [ "$d_anti_leech_restart_flv_changes_yn" == "no" ] 
        then
            d_anti_leech_restart_flv_changes="N"
        else
            d_anti_leech_restart_flv_changes="Y"
        fi
        d_anti_leech_restart_hls_changes_yn=${d#*, anti_leech_restart_hls_changes: }
        d_anti_leech_restart_hls_changes_yn=${d_anti_leech_restart_hls_changes_yn%, recheck_period:*}
        [ "$d_anti_leech_restart_hls_changes_yn" == null ] && d_anti_leech_restart_hls_changes_yn="no"
        d_anti_leech_restart_hls_changes_yn=${d_anti_leech_restart_hls_changes_yn:-no}
        if [ "$d_anti_leech_restart_hls_changes_yn" == "no" ] 
        then
            d_anti_leech_restart_hls_changes="N"
        else
            d_anti_leech_restart_hls_changes="Y"
        fi
        d_recheck_period=${d#*, recheck_period: }
        d_recheck_period=${d_recheck_period%, version:*}
        [ "$d_recheck_period" == null ] && d_recheck_period=0
        d_recheck_period=${d_recheck_period:-0}
        if [ "$d_recheck_period" -eq 0 ] 
        then
            d_recheck_period_text="不设置"
        else
            d_recheck_period_text=$d_recheck_period
        fi
        d_version=${d#*, version: }
        d_version=${d_version%\"}
    done < <($JQ_FILE 'to_entries | map(select(.key=="default")) | map("proxy: \(.value.proxy), user_agent: \(.value.user_agent), headers: \(.value.headers), cookies: \(.value.cookies), playlist_name: \(.value.playlist_name), seg_dir_name: \(.value.seg_dir_name), seg_name: \(.value.seg_name), seg_length: \(.value.seg_length), seg_count: \(.value.seg_count), video_codec: \(.value.video_codec), audio_codec: \(.value.audio_codec), video_audio_shift: \(.value.video_audio_shift), quality: \(.value.quality), bitrates: \(.value.bitrates), const: \(.value.const), encrypt: \(.value.encrypt), encrypt_session: \(.value.encrypt_session), keyinfo_name: \(.value.keyinfo_name), key_name: \(.value.key_name), input_flags: \(.value.input_flags), output_flags: \(.value.output_flags), sync: \(.value.sync), sync_file: \(.value.sync_file), sync_index: \(.value.sync_index), sync_pairs: \(.value.sync_pairs), schedule_file: \(.value.schedule_file), flv_delay_seconds: \(.value.flv_delay_seconds), flv_restart_nums: \(.value.flv_restart_nums), hls_delay_seconds: \(.value.hls_delay_seconds), hls_min_bitrates: \(.value.hls_min_bitrates), hls_max_seg_size: \(.value.hls_max_seg_size), hls_restart_nums: \(.value.hls_restart_nums), hls_key_period: \(.value.hls_key_period), anti_ddos_port: \(.value.anti_ddos_port), anti_ddos_syn_flood: \(.value.anti_ddos_syn_flood), anti_ddos_syn_flood_delay_seconds: \(.value.anti_ddos_syn_flood_delay_seconds), anti_ddos_syn_flood_seconds: \(.value.anti_ddos_syn_flood_seconds), anti_ddos: \(.value.anti_ddos), anti_ddos_seconds: \(.value.anti_ddos_seconds), anti_ddos_level: \(.value.anti_ddos_level), anti_leech: \(.value.anti_leech), anti_leech_restart_nums: \(.value.anti_leech_restart_nums), anti_leech_restart_flv_changes: \(.value.anti_leech_restart_flv_changes), anti_leech_restart_hls_changes: \(.value.anti_leech_restart_hls_changes), recheck_period: \(.value.recheck_period), version: \(.value.version)") | .[]' "$CHANNELS_FILE")
    #done < <($JQ_FILE '.default | to_entries | map([.key,.value]|join(": ")) | join(", ")' "$CHANNELS_FILE")
}

GetChannelsInfo()
{
    [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1

    chnls_count=0
    chnls_pid=()
    chnls_status=()
    chnls_stream_link=()
    chnls_stream_links=()
    chnls_live=()
    chnls_proxy=()
    chnls_user_agent=()
    chnls_headers=()
    chnls_cookies=()
    chnls_output_dir_name=()
    chnls_playlist_name=()
    chnls_seg_dir_name=()
    chnls_seg_name=()
    chnls_seg_length=()
    chnls_seg_count=()
    chnls_video_codec=()
    chnls_audio_codec=()
    chnls_video_audio_shift=()
    chnls_quality=()
    chnls_bitrates=()
    chnls_const=()
    chnls_encrypt=()
    chnls_encrypt_session=()
    chnls_keyinfo_name=()
    chnls_key_name=()
    chnls_key_time=()
    chnls_input_flags=()
    chnls_output_flags=()
    chnls_channel_name=()
    chnls_channel_time=()
    chnls_sync=()
    chnls_sync_file=()
    chnls_sync_index=()
    chnls_sync_pairs=()
    chnls_flv_status=()
    chnls_flv_push_link=()
    chnls_flv_pull_link=()
    
    while IFS= read -r channel
    do
        chnls_count=$((chnls_count+1))
        map_pid=${channel#*pid: }
        map_pid=${map_pid%, status:*}
        map_status=${channel#*, status: }
        map_status=${map_status%, stream_link:*}
        map_stream_link=${channel#*, stream_link: }
        map_stream_link=${map_stream_link%, live:*}
        IFS=" " read -ra map_stream_links <<< "$map_stream_link"
        map_live=${channel#*, live: }
        map_live=${map_live%, proxy:*}
        [ "$map_live" == null ] && map_live="yes"
        map_proxy=${channel#*, proxy: }
        map_proxy=${map_proxy%, user_agent:*}
        [ "$map_proxy" == null ] && map_proxy=""
        map_user_agent=${channel#*, user_agent: }
        map_user_agent=${map_user_agent%, headers:*}
        [ "$map_user_agent" == null ] && map_user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
        map_headers=${channel#*, headers: }
        map_headers=${map_headers%, cookies:*}
        [ "$map_headers" == null ] && map_headers=""
        map_cookies=${channel#*, cookies: }
        map_cookies=${map_cookies%, output_dir_name:*}
        [ "$map_cookies" == null ] && map_cookies="stb_lang=en; timezone=Europe/Amsterdam"
        map_output_dir_name=${channel#*, output_dir_name: }
        map_output_dir_name=${map_output_dir_name%, playlist_name:*}
        map_playlist_name=${channel#*, playlist_name: }
        map_playlist_name=${map_playlist_name%, seg_dir_name:*}
        map_seg_dir_name=${channel#*, seg_dir_name: }
        map_seg_dir_name=${map_seg_dir_name%, seg_name:*}
        map_seg_name=${channel#*, seg_name: }
        map_seg_name=${map_seg_name%, seg_length:*}
        map_seg_length=${channel#*, seg_length: }
        map_seg_length=${map_seg_length%, seg_count:*}
        map_seg_count=${channel#*, seg_count: }
        map_seg_count=${map_seg_count%, video_codec:*}
        map_video_codec=${channel#*, video_codec: }
        map_video_codec=${map_video_codec%, audio_codec:*}
        map_audio_codec=${channel#*, audio_codec: }
        map_audio_codec=${map_audio_codec%, video_audio_shift:*}
        map_video_audio_shift=${channel#*, video_audio_shift: }
        map_video_audio_shift=${map_video_audio_shift%, quality:*}
        [ "$map_video_audio_shift" == null ] && map_video_audio_shift=""
        map_quality=${channel#*, quality: }
        map_quality=${map_quality%, bitrates:*}
        map_bitrates=${channel#*, bitrates: }
        map_bitrates=${map_bitrates%, const:*}
        map_const=${channel#*, const: }
        map_const=${map_const%, encrypt:*}
        map_encrypt=${channel#*, encrypt: }
        map_encrypt=${map_encrypt%, encrypt_session:*}
        map_encrypt_session=${channel#*, encrypt_session: }
        map_encrypt_session=${map_encrypt_session%, keyinfo_name:*}
        [ "$map_encrypt_session" == null ] && map_encrypt_session="no"
        map_keyinfo_name=${channel#*, keyinfo_name: }
        map_keyinfo_name=${map_keyinfo_name%, key_name:*}
        [ "$map_keyinfo_name" == null ] && map_keyinfo_name=$(RandStr)
        map_key_name=${channel#*, key_name: }
        map_key_name=${map_key_name%, key_time:*}
        map_key_time=${channel#*, key_time: }
        map_key_time=${map_key_time%, input_flags:*}
        if [ "$map_key_time" == null ] 
        then
            [ -z "${now:-}" ] && printf -v now '%(%s)T'
            map_key_time=$now
        fi
        map_input_flags=${channel#*, input_flags: }
        map_input_flags=${map_input_flags%, output_flags:*}
        map_output_flags=${channel#*, output_flags: }
        map_output_flags=${map_output_flags%, channel_name:*}
        map_channel_name=${channel#*, channel_name: }
        map_channel_name=${map_channel_name%, channel_time:*}
        map_channel_time=${channel#*, channel_time: }
        map_channel_time=${map_channel_time%, sync:*}
        if [ "$map_channel_time" == null ] 
        then
            [ -z "${now:-}" ] && printf -v now '%(%s)T'
            map_channel_time=$now
        fi
        map_sync=${channel#*, sync: }
        map_sync=${map_sync%, sync_file:*}
        [ "$map_sync" == null ] && map_sync="yes"
        map_sync_file=${channel#*, sync_file: }
        map_sync_file=${map_sync_file%, sync_index:*}
        [ "$map_sync_file" == null ] && map_sync_file=""
        map_sync_index=${channel#*, sync_index: }
        map_sync_index=${map_sync_index%, sync_pairs:*}
        [ "$map_sync_index" == null ] && map_sync_index=""
        map_sync_pairs=${channel#*, sync_pairs: }
        map_sync_pairs=${map_sync_pairs%, flv_status:*}
        [ "$map_sync_pairs" == null ] && map_sync_pairs=""
        map_flv_status=${channel#*, flv_status: }
        map_flv_status=${map_flv_status%, flv_push_link:*}
        [ "$map_flv_status" == null ] && map_flv_status="off"
        map_flv_push_link=${channel#*, flv_push_link: }
        map_flv_push_link=${map_flv_push_link%, flv_pull_link:*}
        [ "$map_flv_push_link" == null ] && map_flv_push_link=""
        map_flv_pull_link=${channel#*, flv_pull_link: }
        map_flv_pull_link=${map_flv_pull_link%\"}
        [ "$map_flv_pull_link" == null ] && map_flv_pull_link=""

        chnls_pid+=("$map_pid")
        chnls_status+=("$map_status")
        chnls_stream_link+=("${map_stream_links[0]}")
        chnls_stream_links+=("$map_stream_link")
        chnls_live+=("$map_live")
        chnls_proxy+=("$map_proxy")
        chnls_user_agent+=("$map_user_agent")
        chnls_headers+=("$map_headers")
        chnls_cookies+=("$map_cookies")
        chnls_output_dir_name+=("$map_output_dir_name")
        chnls_playlist_name+=("$map_playlist_name")
        chnls_seg_dir_name+=("$map_seg_dir_name")
        chnls_seg_name+=("$map_seg_name")
        chnls_seg_length+=("$map_seg_length")
        chnls_seg_count+=("$map_seg_count")
        chnls_video_codec+=("$map_video_codec")
        chnls_audio_codec+=("$map_audio_codec")
        chnls_video_audio_shift+=("$map_video_audio_shift")
        chnls_quality+=("$map_quality")
        chnls_bitrates+=("$map_bitrates")
        chnls_const+=("$map_const")
        chnls_encrypt+=("$map_encrypt")
        chnls_encrypt_session+=("$map_encrypt_session")
        chnls_keyinfo_name+=("$map_keyinfo_name")
        chnls_key_name+=("$map_key_name")
        chnls_key_time+=("$map_key_time")
        chnls_input_flags+=("$map_input_flags")
        chnls_output_flags+=("$map_output_flags")
        chnls_channel_name+=("$map_channel_name")
        chnls_channel_time+=("$map_channel_time")
        chnls_sync+=("$map_sync")
        chnls_sync_file+=("$map_sync_file")
        chnls_sync_index+=("$map_sync_index")
        chnls_sync_pairs+=("$map_sync_pairs")
        chnls_flv_status+=("$map_flv_status")
        chnls_flv_push_link+=("$map_flv_push_link")
        chnls_flv_pull_link+=("$map_flv_pull_link")
    done < <($JQ_FILE '.channels | to_entries | map("pid: \(.value.pid), status: \(.value.status), stream_link: \(.value.stream_link), live: \(.value.live), proxy: \(.value.proxy), user_agent: \(.value.user_agent), headers: \(.value.headers), cookies: \(.value.cookies), output_dir_name: \(.value.output_dir_name), playlist_name: \(.value.playlist_name), seg_dir_name: \(.value.seg_dir_name), seg_name: \(.value.seg_name), seg_length: \(.value.seg_length), seg_count: \(.value.seg_count), video_codec: \(.value.video_codec), audio_codec: \(.value.audio_codec), video_audio_shift: \(.value.video_audio_shift), quality: \(.value.quality), bitrates: \(.value.bitrates), const: \(.value.const), encrypt: \(.value.encrypt), encrypt_session: \(.value.encrypt_session), keyinfo_name: \(.value.keyinfo_name), key_name: \(.value.key_name), key_time: \(.value.key_time), input_flags: \(.value.input_flags), output_flags: \(.value.output_flags), channel_name: \(.value.channel_name), channel_time: \(.value.channel_time), sync: \(.value.sync), sync_file: \(.value.sync_file), sync_index: \(.value.sync_index), sync_pairs: \(.value.sync_pairs), flv_status: \(.value.flv_status), flv_push_link: \(.value.flv_push_link), flv_pull_link: \(.value.flv_pull_link)") | .[]' "$CHANNELS_FILE")

    return 0
}

ListChannels()
{
    GetChannelsInfo
    if [ "$chnls_count" -eq 0 ]
    then
        Println "$error 没有发现频道，请检查 !\n" && exit 1
    fi
    chnls_list=""
    for((index = 0; index < chnls_count; index++)); do
        chnls_output_dir_root="$LIVE_ROOT/${chnls_output_dir_name[index]}"

        v_or_a=${chnls_video_audio_shift[index]%_*}
        if [ "$v_or_a" == "v" ] 
        then
            chnls_video_shift=${chnls_video_audio_shift[index]#*_}
            chnls_video_audio_shift_text="画面延迟 $chnls_video_shift 秒"
        elif [ "$v_or_a" == "a" ] 
        then
            chnls_audio_shift=${chnls_video_audio_shift[index]#*_}
            chnls_video_audio_shift_text="声音延迟 $chnls_audio_shift 秒"
        else
            chnls_video_audio_shift_text="不设置"
        fi

        if [ "${chnls_const[index]}" == "no" ] 
        then
            chnls_const_index_text=" 固定频率:否"
        else
            chnls_const_index_text=" 固定频率:是"
        fi

        chnls_quality_text=""
        chnls_bitrates_text=""
        chnls_playlist_file_text=""

        if [ -n "${chnls_bitrates[index]}" ] 
        then
            while IFS= read -r chnls_br
            do
                if [[ $chnls_br == *"-"* ]]
                then
                    chnls_br_a=${chnls_br%-*}
                    chnls_br_b=" 分辨率: ${chnls_br#*-}"
                    chnls_quality_text="${chnls_quality_text}[ -maxrate ${chnls_br_a}k -bufsize ${chnls_br_a}k${chnls_br_b} ] "
                    chnls_bitrates_text="${chnls_bitrates_text}[ 比特率 ${chnls_br_a}k${chnls_br_b}${chnls_const_index_text} ] "
                    chnls_playlist_file_text="$chnls_playlist_file_text$chnls_output_dir_root/${chnls_playlist_name[index]}_$chnls_br_a.m3u8 "
                elif [[ $chnls_br == *"x"* ]] 
                then
                    chnls_quality_text="${chnls_quality_text}[ 分辨率: $chnls_br ] "
                    chnls_bitrates_text="${chnls_bitrates_text}[ 分辨率: $chnls_br${chnls_const_index_text} ] "
                    chnls_playlist_file_text="$chnls_playlist_file_text$chnls_output_dir_root/${chnls_playlist_name[index]}.m3u8 "
                else
                    chnls_quality_text="${chnls_quality_text}[ -maxrate ${chnls_br}k -bufsize ${chnls_br}k ] "
                    chnls_bitrates_text="${chnls_bitrates_text}[ 比特率 ${chnls_br}k${chnls_const_index_text} ] "
                    chnls_playlist_file_text="$chnls_playlist_file_text$chnls_output_dir_root/${chnls_playlist_name[index]}_$chnls_br.m3u8 "
                fi
            done <<< ${chnls_bitrates[index]//,/$'\n'}
        else
            chnls_playlist_file_text="$chnls_playlist_file_text$chnls_output_dir_root/${chnls_playlist_name[index]}.m3u8 "
        fi

        if [ -n "${chnls_quality[index]}" ] 
        then
            chnls_video_quality_text="crf值${chnls_quality[index]} ${chnls_quality_text:-不设置}"
        else
            chnls_video_quality_text="比特率值 ${chnls_bitrates_text:-不设置}"
        fi

        if [ -z "${kind:-}" ] && [ "${chnls_video_codec[index]}" == "copy" ] && [ "${chnls_audio_codec[index]}" == "copy" ]  
        then
            chnls_video_quality_text="原画"
        fi

        if [ -n "${chnls_proxy[index]}" ] 
        then
            chnls_proxy_text="[代理]"
        else
            chnls_proxy_text=""
        fi

        if [ "$index" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi

        if [ -z "${kind:-}" ] 
        then
            if [ "${chnls_status[index]}" == "on" ]
            then
                chnls_status_text=$green"开启"$plain
            else
                chnls_status_text=$red"关闭"$plain
            fi
            chnls_list=$chnls_list"# $green$((index+1))$plain $blank进程ID: $green${chnls_pid[index]}$plain 状态: $chnls_status_text 频道名称: $green${chnls_channel_name[index]} $chnls_proxy_text$plain\n     编码: $green${chnls_video_codec[index]}:${chnls_audio_codec[index]}$plain 延迟: $green$chnls_video_audio_shift_text$plain 视频质量: $green$chnls_video_quality_text$plain\n     源: ${chnls_stream_link[index]}\n     m3u8位置: $chnls_playlist_file_text\n\n"
        elif [ "$kind" == "flv" ] 
        then
            if [ "${chnls_flv_status[index]}" == "on" ] 
            then
                chnls_flv_status_text=$green"开启"$plain
            else
                chnls_flv_status_text=$red"关闭"$plain
            fi
            chnls_list=$chnls_list"# $green$((index+1))$plain $blank进程ID: $green${chnls_pid[index]}$plain 状态: $chnls_flv_status_text 频道名称: $green${chnls_channel_name[index]} $chnls_proxy_text$plain\n     编码: $green${chnls_video_codec[index]}:${chnls_audio_codec[index]}$plain 延迟: $green$chnls_video_audio_shift_text$plain 视频质量: $green$chnls_video_quality_text$plain\n     flv推流地址: ${chnls_flv_push_link[index]:-无}\n     flv拉流地址: ${chnls_flv_pull_link[index]:-无}\n\n"
        fi
    done

    if [ "$menu_num" -eq 7 ] 
    then
        chnls_list=$chnls_list"# $green$((chnls_count+1))$plain $blank开启所有关闭的频道\n\n"
        chnls_list=$chnls_list"# $green$((chnls_count+2))$plain $blank关闭所有开启的频道\n\n"
    elif [ "$menu_num" -eq 8 ] 
    then
        chnls_list=$chnls_list"# $green$((chnls_count+1))$plain $blank重启所有开启的频道\n\n"
    fi
    Println "=== 频道总数 $green $chnls_count $plain"
    Println "$chnls_list"
}

GetChannelInfo()
{
    if [ -z "${d_version:-}" ] 
    then
        GetDefault
    fi
    
    if [ -z "${monitor:-}" ] 
    then
        select=".value.pid==$chnl_pid"
    elif [ "${kind:-}" == "flv" ] 
    then
        select=".value.flv_push_link==\"$chnl_flv_push_link\""
    else
        select=".value.output_dir_name==\"$output_dir_name\""
    fi

    chn_found=0
    while IFS= read -r channel
    do
        chn_found=1
        chnl_pid=${channel#*pid: }
        chnl_pid=${chnl_pid%, status:*}
        chnl_status=${channel#*, status: }
        chnl_status=${chnl_status%, stream_link:*}
        chnl_stream_links=${channel#*, stream_link: }
        chnl_stream_links=${chnl_stream_links%, live:*}
        chnl_stream_link=${chnl_stream_links%% *}
        chnl_live_yn=${channel#*, live: }
        chnl_live_yn=${chnl_live_yn%, proxy:*}
        if [ "$chnl_live_yn" == "no" ]
        then
            chnl_live=""
            chnl_live_text="$red否$plain"
        else
            chnl_live="-l"
            chnl_live_text="$green是$plain"
        fi
        chnl_proxy=${channel#*, proxy: }
        chnl_proxy=${chnl_proxy%, user_agent:*}
        if [ "${chnl_stream_link:0:4}" == "http" ] && [ -n "$chnl_proxy" ]
        then
            chnl_proxy_command="-http_proxy $chnl_proxy"
        else
            chnl_proxy=""
            chnl_proxy_command=""
        fi
        chnl_user_agent=${channel#*, user_agent: }
        chnl_user_agent=${chnl_user_agent%, headers:*}
        chnl_headers=${channel#*, headers: }
        chnl_headers=${chnl_headers%, cookies:*}
        if [ -n "$chnl_headers" ] && [[ ! $chnl_headers == *"\r\n" ]] && [[ $chnl_headers == *"\r\n"* ]]
        then
            chnl_headers="$chnl_headers\r\n"
        fi
        chnl_cookies=${channel#*, cookies: }
        chnl_cookies=${chnl_cookies%, output_dir_name:*}
        chnl_output_dir_name=${channel#*, output_dir_name: }
        chnl_output_dir_name=${chnl_output_dir_name%, playlist_name:*}
        chnl_output_dir_root="$LIVE_ROOT/$chnl_output_dir_name"
        chnl_playlist_name=${channel#*, playlist_name: }
        chnl_playlist_name=${chnl_playlist_name%, seg_dir_name:*}
        chnl_seg_dir_name=${channel#*, seg_dir_name: }
        chnl_seg_dir_name=${chnl_seg_dir_name%, seg_name:*}
        chnl_seg_name=${channel#*, seg_name: }
        chnl_seg_name=${chnl_seg_name%, seg_length:*}
        chnl_seg_length=${channel#*, seg_length: }
        chnl_seg_length=${chnl_seg_length%, seg_count:*}
        chnl_seg_count=${channel#*, seg_count: }
        chnl_seg_count=${chnl_seg_count%, video_codec:*}
        if [ -n "$chnl_live" ]
        then
            chnl_seg_count_command="-c $chnl_seg_count"
        else
            chnl_seg_count_command=""
        fi
        chnl_video_codec=${channel#*, video_codec: }
        chnl_video_codec=${chnl_video_codec%, audio_codec:*}
        chnl_audio_codec=${channel#*, audio_codec: }
        chnl_audio_codec=${chnl_audio_codec%, video_audio_shift:*}
        chnl_video_audio_shift=${channel#*, video_audio_shift: }
        chnl_video_audio_shift=${chnl_video_audio_shift%, quality:*}
        v_or_a=${chnl_video_audio_shift%_*}
        if [ "$v_or_a" == "v" ] 
        then
            chnl_video_shift=${chnl_video_audio_shift#*_}
            chnl_audio_shift=""
            chnl_video_audio_shift_text="$green画面延迟 $chnl_video_shift 秒$plain"
        elif [ "$v_or_a" == "a" ] 
        then
            chnl_video_shift=""
            chnl_audio_shift=${chnl_video_audio_shift#*_}
            chnl_video_audio_shift_text="$green声音延迟 $chnl_audio_shift 秒$plain"
        else
            chnl_video_audio_shift_text="$green不设置$plain"
            chnl_video_shift=""
            chnl_audio_shift=""
        fi
        chnl_quality=${channel#*, quality: }
        chnl_quality=${chnl_quality%, bitrates:*}
        chnl_bitrates=${channel#*, bitrates: }
        chnl_bitrates=${chnl_bitrates%, const:*}
        chnl_const_yn=${channel#*, const: }
        chnl_const_yn=${chnl_const_yn%, encrypt:*}
        if [ "$chnl_const_yn" == "no" ]
        then
            chnl_const=""
            chnl_const_text=" 固定频率:否"
        else
            chnl_const="-C"
            chnl_const_text=" 固定频率:是"
        fi
        chnl_encrypt_yn=${channel#*, encrypt: }
        chnl_encrypt_yn=${chnl_encrypt_yn%, encrypt_session:*}
        if [ "$chnl_encrypt_yn" == "no" ]
        then
            chnl_encrypt=""
            chnl_encrypt_text=$red"否"$plain
        else
            chnl_encrypt="-e"
            chnl_encrypt_text=$green"是"$plain
        fi
        chnl_encrypt_session_yn=${channel#*, encrypt_session: }
        chnl_encrypt_session_yn=${chnl_encrypt_session_yn%, keyinfo_name:*}
        chnl_keyinfo_name=${channel#*, keyinfo_name: }
        chnl_keyinfo_name=${chnl_keyinfo_name%, key_name:*}
        chnl_key_name=${channel#*, key_name: }
        chnl_key_name=${chnl_key_name%, key_time:*}
        if [ -n "$chnl_encrypt" ] 
        then
            chnl_key_name_command="-K $chnl_key_name"
        else
            chnl_key_name_command=""
        fi
        chnl_key_time=${channel#*, key_time: }
        chnl_key_time=${chnl_key_time%, input_flags:*}
        chnl_input_flags=${channel#*, input_flags: }
        chnl_input_flags=${chnl_input_flags%, output_flags:*}
        chnl_output_flags=${channel#*, output_flags: }
        chnl_output_flags=${chnl_output_flags%, channel_name:*}
        chnl_channel_name=${channel#*, channel_name: }
        chnl_channel_name=${chnl_channel_name%, channel_time:*}
        chnl_channel_time=${channel#*, channel_time: }
        chnl_channel_time=${chnl_channel_time%, sync:*}
        chnl_sync_yn=${channel#*, sync: }
        chnl_sync_yn=${chnl_sync_yn%, sync_file:*}
        chnl_sync_file=${channel#*, sync_file: }
        chnl_sync_file=${chnl_sync_file%, sync_index:*}
        chnl_sync_index=${channel#*, sync_index: }
        chnl_sync_index=${chnl_sync_index%, sync_pairs:*}
        chnl_sync_pairs=${channel#*, sync_pairs: }
        chnl_sync_pairs=${chnl_sync_pairs%, flv_status:*}
        chnl_flv_status=${channel#*, flv_status: }
        chnl_flv_status=${chnl_flv_status%, flv_push_link:*}
        chnl_flv_push_link=${channel#*, flv_push_link: }
        chnl_flv_push_link=${chnl_flv_push_link%, flv_pull_link:*}
        chnl_flv_pull_link=${channel#*, flv_pull_link: }
        chnl_flv_pull_link=${chnl_flv_pull_link%\"}

        if [ -z "${monitor:-}" ] 
        then
            if [ "$chnl_sync_yn" == "no" ]
            then
                chnl_sync_text="$red禁用$plain"
            else
                chnl_sync_text="$green启用$plain"
            fi
            if [ "$chnl_status" == "on" ]
            then
                chnl_status_text=$green"开启"$plain
            else
                chnl_status_text=$red"关闭"$plain
            fi

            chnl_seg_dir_name_text=${chnl_seg_dir_name:-不使用}
            if [ -n "$chnl_seg_dir_name" ] 
            then
                chnl_seg_dir_name_text="$green$chnl_seg_dir_name$plain"
            else
                chnl_seg_dir_name_text="$red不使用$plain"
            fi
            chnl_seg_length_text="$green$chnl_seg_length s$plain"

            chnl_crf_text=""
            chnl_nocrf_text=""
            chnl_playlist_file_text=""

            if [ -n "$chnl_bitrates" ] 
            then
                while IFS= read -r chnl_br
                do
                    if [[ $chnl_br == *"-"* ]]
                    then
                        chnl_br_a=${chnl_br%-*}
                        chnl_br_b=" 分辨率: ${chnl_br#*-}"
                        chnl_crf_text="${chnl_crf_text}[ -maxrate ${chnl_br_a}k -bufsize ${chnl_br_a}k${chnl_br_b} ] "
                        chnl_nocrf_text="${chnl_nocrf_text}[ 比特率 ${chnl_br_a}k${chnl_br_b}${chnl_const_text} ] "
                        chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}_$chnl_br_a.m3u8$plain "
                    elif [[ $chnl_br == *"x"* ]] 
                    then
                        chnl_crf_text="${chnl_crf_text}[ 分辨率: $chnl_br ] "
                        chnl_nocrf_text="${chnl_nocrf_text}[ 分辨率: $chnl_br${chnl_const_text} ] "
                        chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}.m3u8$plain "
                    else
                        chnl_crf_text="${chnl_crf_text}[ -maxrate ${chnl_br}k -bufsize ${chnl_br}k ] "
                        chnl_nocrf_text="${chnl_nocrf_text}[ 比特率 ${chnl_br}k${chnl_const_text} ] "
                        chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}_$chnl_br.m3u8$plain "
                    fi
                done <<< ${chnl_bitrates//,/$'\n'}
            else
                chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}.m3u8$plain "
            fi

            if [ "$chnl_sync_yn" == "yes" ]
            then
                sync_file=${chnl_sync_file:-$d_sync_file}
                sync_index=${chnl_sync_index:-$d_sync_index}
                sync_pairs=${chnl_sync_pairs:-$d_sync_pairs}
                if [ -n "$sync_file" ] && [ -n "$sync_index" ] && [ -n "$sync_pairs" ] && [[ $sync_pairs == *"=http"* ]]
                then
                    chnl_playlist_link=${sync_pairs#*=http}
                    chnl_playlist_link=${chnl_playlist_link%%,*}
                    chnl_playlist_link="http$chnl_playlist_link/$chnl_output_dir_name/${chnl_playlist_name}_master.m3u8"
                    chnl_playlist_link_text="$green$chnl_playlist_link$plain"
                else
                    chnl_playlist_link_text="$red请先设置 sync$plain"
                fi
            else
                chnl_playlist_link_text="$red请先启用 sync$plain"
            fi

            if [ -n "$chnl_quality" ] 
            then
                chnl_video_quality_text="${green}crf值$chnl_quality ${chnl_crf_text:-不设置}$plain"
            else
                chnl_video_quality_text="$green比特率值 ${chnl_nocrf_text:-不设置}$plain"
            fi

            if [ "$chnl_flv_status" == "on" ]
            then
                chnl_flv_status_text=$green"开启"$plain
            else
                chnl_flv_status_text=$red"关闭"$plain
            fi

            if [ -z "${kind:-}" ] && [ "$chnl_video_codec" == "copy" ] && [ "$chnl_audio_codec" == "copy" ]  
            then
                chnl_video_quality_text="$green原画$plain"
                chnl_playlist_link=${chnl_playlist_link:-}
                chnl_playlist_link=${chnl_playlist_link//_master.m3u8/.m3u8}
                chnl_playlist_link_text=${chnl_playlist_link_text//_master.m3u8/.m3u8}
            elif [ -z "$chnl_bitrates" ] 
            then
                chnl_playlist_link=${chnl_playlist_link:-}
                chnl_playlist_link=${chnl_playlist_link//_master.m3u8/.m3u8}
                chnl_playlist_link_text=${chnl_playlist_link_text//_master.m3u8/.m3u8}
            fi
        fi
    done < <($JQ_FILE '.channels | to_entries | map(select('"$select"')) | map("pid: \(.value.pid), status: \(.value.status), stream_link: \(.value.stream_link), live: \(.value.live), proxy: \(.value.proxy), user_agent: \(.value.user_agent), headers: \(.value.headers), cookies: \(.value.cookies), output_dir_name: \(.value.output_dir_name), playlist_name: \(.value.playlist_name), seg_dir_name: \(.value.seg_dir_name), seg_name: \(.value.seg_name), seg_length: \(.value.seg_length), seg_count: \(.value.seg_count), video_codec: \(.value.video_codec), audio_codec: \(.value.audio_codec), video_audio_shift: \(.value.video_audio_shift), quality: \(.value.quality), bitrates: \(.value.bitrates), const: \(.value.const), encrypt: \(.value.encrypt), encrypt_session: \(.value.encrypt_session), keyinfo_name: \(.value.keyinfo_name), key_name: \(.value.key_name), key_time: \(.value.key_time), input_flags: \(.value.input_flags), output_flags: \(.value.output_flags), channel_name: \(.value.channel_name), channel_time: \(.value.channel_time), sync: \(.value.sync), sync_file: \(.value.sync_file), sync_index: \(.value.sync_index), sync_pairs: \(.value.sync_pairs), flv_status: \(.value.flv_status), flv_push_link: \(.value.flv_push_link), flv_pull_link: \(.value.flv_pull_link)") | .[]' "$CHANNELS_FILE")

    if [ "$chn_found" -eq 0 ] && [ -z "${monitor:-}" ]
    then
        Println "$error 频道发生变化，请重试 !\n" && exit 1
    fi
}

GetChannelInfoLite()
{
    if [ -z "${d_version:-}" ] 
    then
        GetDefault
    fi

    for((i=0;i<chnls_count;i++));
    do
        if [ -n "${monitor:-}" ] 
        then
            if { [ "${kind:-}" == "flv" ] && [ "${chnls_flv_push_link[i]}" != "$chnl_flv_push_link" ]; } || { [ -z "${kind:-}" ] && [ "${chnls_output_dir_name[i]}" != "$output_dir_name" ]; }
            then
                continue
            fi
        elif [ "${chnls_pid[i]}" != "$chnl_pid" ] 
        then
            continue
        fi
        chnl_pid=${chnls_pid[i]}
        chnl_status=${chnls_status[i]}
        chnl_stream_links=${chnls_stream_link[i]}
        chnl_stream_link=${chnl_stream_links%% *}
        chnl_live_yn=${chnls_live[i]}
        if [ "$chnl_live_yn" == "no" ]
        then
            chnl_live=""
            chnl_live_text="$red否$plain"
        else
            chnl_live="-l"
            chnl_live_text="$green是$plain"
        fi
        chnl_proxy=${chnls_proxy[i]}
        if [ "${chnl_stream_link:0:4}" == "http" ] && [ -n "$chnl_proxy" ]
        then
            chnl_proxy_command="-http_proxy $chnl_proxy"
        else
            chnl_proxy_command=""
        fi
        chnl_user_agent=${chnls_user_agent[i]}
        chnl_headers=${chnls_headers[i]}
        if [ -n "$chnl_headers" ] && [[ ! $chnl_headers == *"\r\n" ]] && [[ $chnl_headers == *"\r\n"* ]]
        then
            chnl_headers="$chnl_headers\r\n"
        fi
        chnl_cookies=${chnls_cookies[i]}
        chnl_output_dir_name=${chnls_output_dir_name[i]}
        chnl_output_dir_root="$LIVE_ROOT/$chnl_output_dir_name"
        chnl_playlist_name=${chnls_playlist_name[i]}
        chnl_seg_dir_name=${chnls_seg_dir_name[i]}
        chnl_seg_name=${chnls_seg_name[i]}
        chnl_seg_length=${chnls_seg_length[i]}
        chnl_seg_count=${chnls_seg_count[i]}
        chnl_video_codec=${chnls_video_codec[i]}
        chnl_audio_codec=${chnls_audio_codec[i]}
        chnl_video_audio_shift=${chnls_video_audio_shift[i]}
        v_or_a=${chnl_video_audio_shift%_*}
        if [ "$v_or_a" == "v" ] 
        then
            chnl_video_shift=${chnl_video_audio_shift#*_}
            chnl_audio_shift=""
            chnl_video_audio_shift_text="$green画面延迟 $chnl_video_shift 秒$plain"
        elif [ "$v_or_a" == "a" ] 
        then
            chnl_video_shift=""
            chnl_audio_shift=${chnl_video_audio_shift#*_}
            chnl_video_audio_shift_text="$green声音延迟 $chnl_audio_shift 秒$plain"
        else
            chnl_video_audio_shift_text="$green不设置$plain"
            chnl_video_shift=""
            chnl_audio_shift=""
        fi
        chnl_quality=${chnls_quality[i]}
        chnl_bitrates=${chnls_bitrates[i]}
        chnl_const_yn=${chnls_const[i]}
        if [ "$chnl_const_yn" == "no" ]
        then
            chnl_const=""
            chnl_const_text=" 固定频率:否"
        else
            chnl_const="-C"
            chnl_const_text=" 固定频率:是"
        fi
        chnl_encrypt_yn=${chnls_encrypt[i]}
        if [ "$chnl_encrypt_yn" == "no" ]
        then
            chnl_encrypt=""
            chnl_encrypt_text=$red"否"$plain
        else
            chnl_encrypt="-e"
            chnl_encrypt_text=$green"是"$plain
        fi
        chnl_encrypt_session_yn=${chnls_encrypt_session[i]}
        chnl_keyinfo_name=${chnls_keyinfo_name[i]}
        chnl_key_name=${chnls_key_name[i]}
        chnl_key_time=${chnls_key_time[i]}
        chnl_input_flags=${chnls_input_flags[i]}
        chnl_output_flags=${chnls_output_flags[i]}
        chnl_channel_name=${chnls_channel_name[i]}
        chnl_channel_time=${chnls_channel_time[i]}
        chnl_sync_yn=${chnls_sync[i]}
        if [ "$chnl_sync_yn" == "no" ]
        then
            chnl_sync_text="$red禁用$plain"
        else
            chnl_sync_text="$green启用$plain"
        fi
        chnl_sync_file=${chnls_sync_file[i]}
        chnl_sync_index=${chnls_sync_index[i]}
        chnl_sync_pairs=${chnls_sync_pairs[i]}
        chnl_flv_status=${chnls_flv_status[i]}
        chnl_flv_push_link=${chnls_flv_push_link[i]}
        chnl_flv_pull_link=${chnls_flv_pull_link[i]}

        if [ -z "${monitor:-}" ] 
        then
            if [ "$chnl_status" == "on" ]
            then
                chnl_status_text=$green"开启"$plain
            else
                chnl_status_text=$red"关闭"$plain
            fi

            chnl_seg_dir_name_text=${chnl_seg_dir_name:-不使用}
            if [ -n "$chnl_seg_dir_name" ] 
            then
                chnl_seg_dir_name_text="$green$chnl_seg_dir_name$plain"
            else
                chnl_seg_dir_name_text="$red不使用$plain"
            fi
            chnl_seg_length_text="$green$chnl_seg_length s$plain"

            chnl_crf_text=""
            chnl_nocrf_text=""
            chnl_playlist_file_text=""

            if [ -n "$chnl_bitrates" ] 
            then
                while IFS= read -r chnl_br
                do
                    if [[ $chnl_br == *"-"* ]]
                    then
                        chnl_br_a=${chnl_br%-*}
                        chnl_br_b=" 分辨率: ${chnl_br#*-}"
                        chnl_crf_text="${chnl_crf_text}[ -maxrate ${chnl_br_a}k -bufsize ${chnl_br_a}k${chnl_br_b} ] "
                        chnl_nocrf_text="${chnl_nocrf_text}[ 比特率 ${chnl_br_a}k${chnl_br_b}${chnl_const_text} ] "
                        chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}_$chnl_br_a.m3u8$plain "
                    elif [[ $chnl_br == *"x"* ]] 
                    then
                        chnl_crf_text="${chnl_crf_text}[ 分辨率: $chnl_br ] "
                        chnl_nocrf_text="${chnl_nocrf_text}[ 分辨率: $chnl_br${chnl_const_text} ] "
                        chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}.m3u8$plain "
                    else
                        chnl_crf_text="${chnl_crf_text}[ -maxrate ${chnl_br}k -bufsize ${chnl_br}k ] "
                        chnl_nocrf_text="${chnl_nocrf_text}[ 比特率 ${chnl_br}k${chnl_const_text} ] "
                        chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}_$chnl_br.m3u8$plain "
                    fi
                done <<< ${chnl_bitrates//,/$'\n'}
            else
                chnl_playlist_file_text="$chnl_playlist_file_text$green$chnl_output_dir_root/${chnl_playlist_name}.m3u8$plain "
            fi

            if [ "$chnl_sync_yn" == "yes" ]
            then
                sync_file=${chnl_sync_file:-$d_sync_file}
                sync_index=${chnl_sync_index:-$d_sync_index}
                sync_pairs=${chnl_sync_pairs:-$d_sync_pairs}
                if [ -n "$sync_file" ] && [ -n "$sync_index" ] && [ -n "$sync_pairs" ] && [[ $sync_pairs == *"=http"* ]]
                then
                    chnl_playlist_link=${sync_pairs#*=http}
                    chnl_playlist_link=${chnl_playlist_link%%,*}
                    chnl_playlist_link="http$chnl_playlist_link/$chnl_output_dir_name/${chnl_playlist_name}_master.m3u8"
                    chnl_playlist_link_text="$green$chnl_playlist_link$plain"
                else
                    chnl_playlist_link_text="$red请先设置 sync$plain"
                fi
            else
                chnl_playlist_link_text="$red请先启用 sync$plain"
            fi

            if [ -n "$chnl_quality" ] 
            then
                chnl_video_quality_text="${green}crf值$chnl_quality ${chnl_crf_text:-不设置}$plain"
            else
                chnl_video_quality_text="$green比特率值 ${chnl_nocrf_text:-不设置}$plain"
            fi

            if [ "$chnl_flv_status" == "on" ]
            then
                chnl_flv_status_text=$green"开启"$plain
            else
                chnl_flv_status_text=$red"关闭"$plain
            fi

            if [ -z "${kind:-}" ] && [ "$chnl_video_codec" == "copy" ] && [ "$chnl_audio_codec" == "copy" ]  
            then
                chnl_video_quality_text="$green原画$plain"
                chnl_playlist_link=${chnl_playlist_link:-}
                chnl_playlist_link=${chnl_playlist_link//_master.m3u8/.m3u8}
                chnl_playlist_link_text=${chnl_playlist_link_text//_master.m3u8/.m3u8}
            elif [ -z "$chnl_bitrates" ] 
            then
                chnl_playlist_link=${chnl_playlist_link:-}
                chnl_playlist_link=${chnl_playlist_link//_master.m3u8/.m3u8}
                chnl_playlist_link_text=${chnl_playlist_link_text//_master.m3u8/.m3u8}
            fi
        fi
        break
    done
}

ViewChannelInfo()
{
    Println "==================================================="
    Println " 频道 [$chnl_channel_name] 的配置信息：\n"
    printf "%s\r\e[20C$green%s$plain\n" " 进程ID" "$chnl_pid"

    if [ -z "${kind:-}" ] 
    then
        printf '%b' " 状态\r\e[20C$chnl_status_text\n"
        printf "%s\r\e[20C$green%s$plain\n" " m3u8名称" "$chnl_playlist_name"
        printf '%b' " m3u8位置\r\e[20C$chnl_playlist_file_text\n"
        printf '%b' " m3u8链接\r\e[20C$chnl_playlist_link_text\n"
        printf '%b' " 段子目录\r\e[20C$chnl_seg_dir_name_text\n"
        printf "%s\r\e[20C$green%s$plain\n" " 段名称" "$chnl_seg_name"
        printf '%b' " 段时长\r\e[20C$chnl_seg_length_text\n"
        printf "%s\r\e[20C$green%s$plain\n" " m3u8包含段数目" "$chnl_seg_count"
        printf '%b' " 加密\r\e[20C$chnl_encrypt_text\n"
        if [ -n "$chnl_encrypt" ] 
        then
            printf "%s\r\e[20C$green%s$plain\n" " keyinfo名称" "$chnl_keyinfo_name"
            printf "%s\r\e[20C$green%s$plain\n" " key名称" "$chnl_key_name"
        fi
    elif [ "$kind" == "flv" ] 
    then
        printf '%b' " 状态\r\e[20C$chnl_flv_status_text\n"
        printf "%s\r\e[20C$green%s$plain\n" " 推流地址" "${chnl_flv_push_link:-无}"
        printf "%s\r\e[20C$green%s$plain\n" " 拉流地址" "${chnl_flv_pull_link:-无}"
    fi

    printf "%s\r\e[20C$green%s$plain\n" " 直播源" "${chnl_stream_links// /, }"
    printf '%b' " 无限时长直播\r\e[20C$chnl_live_text\n"
    printf "%s\r\e[20C$green%s$plain\n" " 代理" "${chnl_proxy:-无}"
    printf "%s\r\e[20C$green%s$plain\n" " user agent" "${chnl_user_agent:-无}"
    printf "%s\r\e[20C$green%s$plain\n" " headers" "${chnl_headers:-无}"
    printf "%s\r\e[20C$green%s$plain\n" " cookies" "${chnl_cookies:-无}"
    printf "%s\r\e[20C$green%s$plain\n" " 视频编码" "$chnl_video_codec"
    printf "%s\r\e[20C$green%s$plain\n" " 音频编码" "$chnl_audio_codec"
    printf '%b' " 视频质量\r\e[20C$chnl_video_quality_text\n"
    printf '%b' " 延迟\r\e[20C$chnl_video_audio_shift_text\n"

    printf "%s\r\e[20C$green%s$plain\n" " 输入参数" "${chnl_input_flags:-不设置}"
    printf "%s\r\e[20C$green%s$plain\n" " 输出参数" "${chnl_output_flags:-不设置}"
    printf '%b' " sync\r\e[20C$chnl_sync_text\n"
    if [ -n "$chnl_sync_file" ] 
    then
        printf "%s\r\e[20C$green%s$plain\n" " sync_file" "${chnl_sync_file// /, }"
    fi
    if [ -n "$chnl_sync_index" ] 
    then
        printf "%s\r\e[20C$green%s$plain\n" " sync_index" "${chnl_sync_index// /, }"
    fi
    if [ -n "$chnl_sync_pairs" ] 
    then
        printf "%s\r\e[20C$green%s$plain\n" " sync_pairs" "${chnl_sync_pairs// /, }"
    fi
    echo
}

InputChannelsIndex()
{
    echo -e "请输入频道的序号 "
    echo -e "$tip 多个序号用空格分隔 比如: 5 7 9-11 \n"
    while read -p "(默认: 取消): " chnls_index_input
    do
        chnls_pid_chosen=()

        if [[ $menu_num -eq 7 ]] 
        then
            if [[ $chnls_index_input == $((chnls_count+1)) ]] 
            then
                found_chnls_off=0
                for((i=0;i<chnls_count;i++));
                do
                    if [[ -z ${kind:-} ]] && [[ ${chnls_status[i]} == "off" ]]
                    then
                        chnls_pid_chosen+=("${chnls_pid[i]}")
                        found_chnls_off=1
                    elif [[ ${kind:-} == "flv" ]] && [[ ${chnls_flv_status[i]} == "off" ]]
                    then
                        chnls_pid_chosen+=("${chnls_pid[i]}")
                        found_chnls_off=1
                    fi
                done
                [[ $found_chnls_off -eq 0 ]] && Println "$error 没有找到关闭的频道\n" && exit 1
                break
            elif [[ $chnls_index_input == $((chnls_count+2)) ]] 
            then
                found_chnls_on=0
                for((i=0;i<chnls_count;i++));
                do
                    if [[ -z ${kind:-} ]] && [[ ${chnls_status[i]} == "on" ]]
                    then
                        chnls_pid_chosen+=("${chnls_pid[i]}")
                        found_chnls_on=1
                    elif [[ ${kind:-} == "flv" ]] && [[ ${chnls_flv_status[i]} == "on" ]]
                    then
                        chnls_pid_chosen+=("${chnls_pid[i]}")
                        found_chnls_on=1
                    fi
                done
                [[ $found_chnls_on -eq 0 ]] && Println "$error 没有找到开启的频道\n" && exit 1
                break
            fi
        elif [[ $menu_num -eq 8 ]] && [[ $chnls_index_input == $((chnls_count+1)) ]]
        then
            found_chnls_on=0
            for((i=0;i<chnls_count;i++));
            do
                if [[ -z ${kind:-} ]] && [[ ${chnls_status[i]} == "on" ]]
                then
                    chnls_pid_chosen+=("${chnls_pid[i]}")
                    found_chnls_on=1
                elif [[ ${kind:-} == "flv" ]] && [[ ${chnls_flv_status[i]} == "on" ]]
                then
                    chnls_pid_chosen+=("${chnls_pid[i]}")
                    found_chnls_on=1
                fi
            done
            [[ $found_chnls_on -eq 0 ]] && Println "$error 没有找到开启的频道\n" && exit 1
            break
        fi

        IFS=" " read -ra chnls_index <<< "$chnls_index_input"
        [ -z "$chnls_index_input" ] && Println "已取消...\n" && exit 1

        for chnl_index in "${chnls_index[@]}"
        do
            if [[ $chnl_index == *"-"* ]] 
            then
                chnl_index_start=${chnl_index%-*}
                chnl_index_end=${chnl_index#*-}

                if [[ $chnl_index_start == *[!0-9]* ]] || [[ $chnl_index_end == *[!0-9]* ]] 
                then
                    Println "$error 多选输入错误！\n"
                    continue 2
                elif [[ $chnl_index_start -gt 0 ]] && [[ $chnl_index_end -le $chnls_count ]] && [[ $chnl_index_end -gt $chnl_index_start ]] 
                then
                    ((chnl_index_start--))
                    for((i=chnl_index_start;i<chnl_index_end;i++));
                    do
                        chnls_pid_chosen+=("${chnls_pid[i]}")
                    done
                else
                    Println "$error 多选输入错误！\n"
                    continue 2
                fi
            elif [[ $chnl_index == *[!0-9]* ]] || [[ $chnl_index -eq 0 ]] || [[ $chnl_index -gt $chnls_count ]] 
            then
                Println "$error 请输入正确的序号！\n"
                continue 2
            else
                ((chnl_index--))
                chnls_pid_chosen+=("${chnls_pid[chnl_index]}")
            fi
        done
        break
    done
}

ViewChannelMenu(){
    ListChannels
    InputChannelsIndex
    for chnl_pid in "${chnls_pid_chosen[@]}"
    do
        GetChannelInfo
        ViewChannelInfo
    done
}

InstallYoutubeDl()
{
    Println "$info 安装 youtube-dl...\n"
    curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl
    chmod a+rx /usr/local/bin/youtube-dl
}

SetStreamLink()
{
    if [ "${xc:-0}" -eq 1 ] 
    then
        Println "	直播源: $green $stream_link $plain\n"
        return 0
    fi
    if [ -n "${chnl_stream_links:-}" ] && [[ $chnl_stream_links == *" "* ]]
    then
        Println "是否只是调整频道 ${green}[ $chnl_channel_name ]$plain 直播源顺序? [y/N]"
        read -p "(默认: N): " stream_links_sort_yn
        stream_links_sort_yn=${stream_links_sort_yn:-N}
        if [[ $stream_links_sort_yn == [Yy] ]] 
        then
            IFS=" " read -ra stream_links <<< "$chnl_stream_links"
            stream_links_count=${#stream_links[@]}
            stream_links_list=""
            for((i=0;i<stream_links_count;i++));
            do
                stream_links_list="$stream_links_list$green$((i+1)).$plain ${stream_links[i]}\n\n"
            done
            re=""
            for((i=stream_links_count;i>0;i--));
            do
                [ -n "$re" ] && re="$re "
                re="$re$i"
            done
            Println "$stream_links_list"
            echo -e "输入新的次序"
            while read -p "(比如 $re ): " orders_input
            do
                IFS=" " read -ra orders <<< "$orders_input"
                if [ "${#orders[@]}" -eq "$stream_links_count" ] 
                then
                    flag=0
                    for order in "${orders[@]}"
                    do
                        if [[ $order == *[!0-9]* ]] || [ "$order" -lt 1 ] || [ "$order" -gt "$stream_links_count" ] || [ "$order" -eq "$flag" ] 
                        then
                            Println "$error 输入错误\n"
                            continue 2
                        else
                            flag=$order
                        fi
                    done

                    stream_links_input=""
                    for order in "${orders[@]}"
                    do
                        index=$((order-1))
                        [ -n "$stream_links_input" ] && stream_links_input="$stream_links_input "
                        stream_links_input="$stream_links_input${stream_links[index]}"
                    done
                    break
                else
                    Println "$error 输入错误\n"
                fi
            done
            return 0
        fi
    fi
    Println "请输入直播源( mpegts / hls / flv / youtube ...)"
    echo -e "$tip 可以是视频路径, 可以输入不同链接地址(监控按顺序尝试使用), 用空格分隔\n"
    read -p "(默认: 取消): " stream_links_input
    [ -z "$stream_links_input" ] && Println "已取消...\n" && exit 1
    IFS=" " read -ra stream_links <<< "$stream_links_input"

    if [[ $stream_links_input == *"https://www.youtube.com"* ]] || [[ $stream_links_input == *"https://youtube.com"* ]] 
    then
        if [[ ! -x $(command -v youtube-dl) ]] 
        then
            InstallYoutubeDl
        fi
        if [[ ! -x $(command -v python) ]] 
        then
            ln -s /usr/bin/python3 /usr/bin/python
        fi
        for((i=0;i<${#stream_links[@]};i++));
        do
            link="${stream_links[i]}"
            if { [ "${link:0:23}" == "https://www.youtube.com" ] || [ "${link:0:19}" == "https://youtube.com" ]; } && [[ $link != *".m3u8"* ]] && [[ $link != *"|"* ]]
            then
                Println "$info 查询 $green$link$plain 视频信息..."

                found=0
                count=0
                codes=()
                format_list=""
                while IFS= read -r line 
                do
                    if [[ $line == "format code"* ]] 
                    then
                        found=1
                    elif [[ $found -eq 1 ]] 
                    then
                        count=$((count+1))
                        code=${line%% *}
                        codes+=("$code")
                        code="code: $green$code$plain, "
                        line=${line#* }
                        lead=${line%%[^[:blank:]]*}
                        line=${line#${lead}}
                        extension=${line%% *}
                        extension="格式: $green$extension$plain, "
                        line=${line#* }
                        lead=${line%%[^[:blank:]]*}
                        line=${line#${lead}}
                        note=${line#* , }
                        line=${line%% , *}
                        bitrate=${line##* }
                        if [[ ${line:0:1} == *[!0-9]* ]] 
                        then
                            resolution=""
                            line=${line// $bitrate/}
                            note="其它: $line$note"
                        else
                            resolution=${line%% *}
                            line=${line#* }
                            lead=${line%%[^[:blank:]]*}
                            line=${line#${lead}}
                            line=${line// $bitrate/}
                            trail=${line##*[^[:blank:]]}
                            line=${line%${trail}}
                            resolution="分辨率: $green$resolution$plain, $green${line##* }$plain, "
                            note="其它: $line$note"
                        fi
                        format_list=$format_list"$green$count.$plain $resolution$code$extension$note\n\n"
                    fi
                done < <(youtube-dl --list-formats "$link")
                if [ -n "$format_list" ] 
                then
                    Println "$format_list"
                    echo "输入序号"
                    while read -p "(默认: $count): " format_num
                    do
                        case "$format_num" in
                            "")
                                code=${codes[count-1]}
                                break
                            ;;
                            *[!0-9]*)
                                Println "$error 请输入正确的数字\n"
                            ;;
                            *)
                                if [ "$format_num" -ge 1 ] && [ "$format_num" -le $count ]
                                then
                                    code=${codes[format_num-1]}
                                    break
                                else
                                    Println "$error 请输入正确的数字\n"
                                fi
                            ;;
                        esac
                    done
                    stream_links[i]="${stream_links[i]}|$code"
                else
                    Println "$error 无法解析链接 $link\n" && exit 1
                fi
            fi
        done

        Println "$info 解析 youtube 链接..."
        stream_link=${stream_links[0]}
        code=${stream_link#*|}
        stream_link=${stream_link%|*}
        stream_link=$(youtube-dl -f "$code" -g "$stream_link")

        stream_links_input=""
        for link in "${stream_links[@]}"
        do
            [ -n "$stream_links_input" ] && stream_links_input="$stream_links_input "
            stream_links_input="$stream_links_input$link"
        done
    else
        stream_link=${stream_links[0]}
    fi

    if [ "${stream_link:13:12}" == "fengshows.cn" ] 
    then
        ts=$(date +%s%3N)
        tx_time=$(printf '%X' $((ts/1000+1800)))

        stream_link=${stream_link%\?*}

        relative_path=${stream_link#*//}
        relative_path="/${relative_path#*/}"

        tx_secret=$(printf '%s' "obb9Lxyv5C${relative_path%.*}$tx_time" | md5sum)
        tx_secret=${tx_secret%% *}

        stream_link="$stream_link?txSecret=$tx_secret&txTime=$tx_time"
        #token=$(printf '%s' "$ts/${relative_path:1}ifengims" | md5sum)
        #token=${token%% *}
        #stream_link_md5="$stream_link?ts=$ts&token=$token"
    elif [ "${stream_link:7:12}" == "news.tvb.com" ] 
    then
        while IFS= read -r line 
        do
            if [[ $line == *"var videoUrl "* ]] 
            then
                line=${line#*= \"}
                stream_link=${line%\"*}
                break
            fi
        done < <(wget --no-check-certificate "$stream_link" -qO- || true)
    fi

    Println "	直播源: $green $stream_link $plain\n"
}

SetIsHls()
{
    Println "是否是 HLS 链接? [y/N]"
    echo -e "$tip 如果直播链接重定向至 .m3u8 地址，请选择 Y\n"
    read -p "(默认: N): " is_hls_yn
    is_hls_yn=${is_hls_yn:-N}
    if [[ $is_hls_yn == [Yy] ]]
    then
        is_hls=1
        is_hls_text="是"
    else
        is_hls=0
        is_hls_text="否"
    fi
    Println "	HLS 链接: $green $is_hls_text $plain\n"
}

SetLive()
{
    Println "是否是无限时长直播源? [Y/n]"
    if [ -z "${kind:-}" ] 
    then
        echo -e "$tip 选择 n 则无法设置切割段数目且无法监控\n"
    else
        echo -e "$tip 选择 n 则无法监控\n"
    fi
    read -p "(默认: Y): " live_yn
    live_yn=${live_yn:-Y}
    if [[ $live_yn == [Yy] ]]
    then
        live="-l"
        live_yn="yes"
        live_text="是"
    else
        live=""
        live_yn="no"
        live_text="否"
    fi
    Println "	无限时长: $green $live_text $plain\n"
}

SetProxy()
{
    Println "请输入 ffmpeg 代理, 比如 http://username:passsword@127.0.0.1:5555"
    echo -e "$tip 可以使用脚本自带的 v2ray 管理面板添加代理, 可以输入 omit 省略此选项\n"
    read -p "(默认: ${d_proxy:-不设置}): " proxy
    proxy=${proxy:-$d_proxy}
    if [ "$proxy" == "omit" ] 
    then
        proxy=""
    fi
    Println "	ffmpeg 代理: $green ${proxy:-不设置} $plain\n"
}

SetUserAgent()
{
    if [ "${xc:-0}" -eq 1 ] 
    then
        Println "	ffmpeg UA: $green ${user_agent:-不设置} $plain\n"
        return 0
    fi
    Println "请输入 ffmpeg 的 user agent"
    echo -e "$tip 可以输入 omit 省略此选项\n"
    read -p "(默认: ${d_user_agent:-不设置}): " user_agent
    user_agent=${user_agent:-$d_user_agent}
    if [ "$user_agent" == "omit" ] 
    then
        user_agent=""
    fi
    Println "	ffmpeg UA: $green ${user_agent:-不设置} $plain\n"
}

SetHeaders()
{
    if [ "${xc:-0}" -eq 1 ] 
    then
        Println "	ffmpeg headers: $green ${headers:-不设置} $plain\n"
        return 0
    fi
    Println "请输入 ffmpeg headers"
    echo -e "$tip 多个 header 用 \\\r\\\n 分隔, 可以输入 omit 省略此选项\n"
    read -p "(默认: ${d_headers:-不设置}): " headers
    headers=${headers:-$d_headers}
    if [ "$headers" == "omit" ] 
    then
        headers=""
    fi
    if [ -n "$headers" ] && [[ ! $headers == *"\r\n" ]] && [[ $headers == *"\r\n"* ]]
    then
        headers="$headers\r\n"
    fi
    Println "	ffmpeg headers: $green ${headers:-不设置} $plain\n"
}

SetCookies()
{
    if [ "${xc:-0}" -eq 1 ] 
    then
        Println "	ffmpeg cookies: $green ${cookies:-不设置} $plain\n"
        return 0
    fi
    Println "请输入 ffmpeg cookies"
    echo -e "$tip 多个 cookies 用 ; 分隔, 可以输入 omit 省略此选项\n"
    read -p "(默认: ${d_cookies:-不设置}): " cookies
    cookies=${cookies:-$d_cookies}
    if [ "$cookies" == "omit" ] 
    then
        cookies=""
    fi
    Println "	ffmpeg cookies: $green ${cookies:-不设置} $plain\n"
}

SetOutputDirName()
{
    Println "请输入频道输出目录名称"
    echo -e "$tip 是名称不是路径\n"
    while read -p "(默认: 随机名称): " output_dir_name
    do
        if [ -z "$output_dir_name" ] 
        then
            while :;do
                output_dir_name=$(RandOutputDirName)
                if [[ -z $($JQ_FILE '.channels[] | select(.output_dir_name=="'"$output_dir_name"'")' "$CHANNELS_FILE") ]] 
                then
                    break 2
                fi
            done
        elif [[ -z $($JQ_FILE '.channels[] | select(.output_dir_name=="'"$output_dir_name"'")' "$CHANNELS_FILE") ]]  
        then
            break
        else
            Println "$error 目录已存在！\n"
        fi
    done
    output_dir_root="$LIVE_ROOT/$output_dir_name"
    Println "	目录名称: $green $output_dir_name $plain\n"
}

SetPlaylistName()
{
    Println "请输入m3u8名称(前缀)"
    read -p "(默认: $d_playlist_name_text): " playlist_name
    if [ -z "$playlist_name" ] 
    then
        playlist_name=${d_playlist_name:-$(RandPlaylistName)}
    fi
    Println "	m3u8名称: $green $playlist_name $plain\n"
}

SetSegDirName()
{
    Println "请输入段所在子目录名称"
    read -p "(默认: $d_seg_dir_name_text): " seg_dir_name
    if [ -z "$seg_dir_name" ] 
    then
        seg_dir_name=$d_seg_dir_name
    fi
    Println "	段子目录名: $green ${seg_dir_name:-不使用} $plain\n"
}

SetSegName()
{
    Println "请输入段名称"
    read -p "(默认: $d_seg_name_text): " seg_name
    if [ -z "$seg_name" ] 
    then
        if [ -z "$d_seg_name" ] 
        then
            if [ -z "${playlist_name:-}" ] 
            then
                playlist_name=$($JQ_FILE -r '.channels[]|select(.pid=='"$chnl_pid"').playlist_name' "$CHANNELS_FILE")
            fi
            seg_name=$playlist_name
        else
            seg_name=$d_seg_name
        fi
    fi
    Println "	段名称: $green $seg_name $plain\n"
}

SetSegLength()
{
    Println "请输入段的时长(单位：s)"
    while read -p "(默认: $d_seg_length): " seg_length
    do
        case "$seg_length" in
            "")
                seg_length=$d_seg_length
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字(大于0) \n"
            ;;
            *)
                if [ "$seg_length" -ge 1 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于0)\n"
                fi
            ;;
        esac
    done
    Println "	段时长: $green ${seg_length} s $plain\n"
}

SetSegCount()
{
    Println "请输入m3u8文件包含的段数目，ffmpeg分割的数目是其2倍"
    echo -e "$tip 如果填0就是无限\n"
    while read -p "(默认: $d_seg_count): " seg_count
    do
        case "$seg_count" in
            "")
                seg_count=$d_seg_count
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字(大于等于0) \n"
            ;;
            *)
                if [ "$seg_count" -ge 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于等于0)\n"
                fi
            ;;
        esac
    done
    Println "	段数目: $green $seg_count $plain\n"
}

SetVideoCodec()
{
    Println "请输入视频编码(不需要转码时输入 copy)"
    read -p "(默认: $d_video_codec): " video_codec
    video_codec=${video_codec:-$d_video_codec}
    Println "	视频编码: $green $video_codec $plain\n"
}

SetAudioCodec()
{
    Println "请输入音频编码(不需要转码时输入 copy)"
    read -p "(默认: $d_audio_codec): " audio_codec
    audio_codec=${audio_codec:-$d_audio_codec}
    Println "	音频编码: $green $audio_codec $plain\n"
}

SetQuality()
{
    Println "请输入输出视频质量[0-63]"
    echo -e "$tip 改变CRF，数字越大越视频质量越差，如果设置CRF则无法用比特率控制视频质量\n"
    while read -p "(默认: ${d_quality:-不设置}): " quality
    do
        case "$quality" in
            "")
                quality=$d_quality
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字(大于等于0,小于等于63)或直接回车 \n"
            ;;
            *)
                if [ "$quality" -ge 0 ] && [ "$quality" -lt 63 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于等于0,小于等于63)或直接回车 \n"
                fi
            ;;
        esac
    done
    Println "	crf视频质量: $green ${quality:-不设置} $plain\n"
}

SetBitrates()
{
    Println "请输入比特率(kb/s), 可以输入 omit 省略此选项"

    if [ -z "$quality" ] 
    then
        echo -e "$tip 用于指定输出视频比特率，同时可以指定输出的分辨率"
    else
        echo -e "$tip 用于 -maxrate 和 -bufsize，同时可以指定输出的分辨率"
    fi
    
    if [ -z "${kind:-}" ] 
    then
        echo -e "$tip 多个比特率用逗号分隔(生成自适应码流)
    同时可以指定输出的分辨率(比如：600-600x400,900-1280x720)"
    fi

    echo && read -p "(默认: ${d_bitrates:-不设置}): " bitrates
    bitrates=${bitrates:-$d_bitrates}
    if [ "$bitrates" == "omit" ] 
    then
        bitrates=""
    fi
    Println "	比特率: $green ${bitrates:-不设置} $plain\n"
}

SetConst()
{
    Println "是否使用固定码率[y/N]"
    read -p "(默认: $d_const_text): " const_yn
    const_yn=${const_yn:-$d_const_text}
    if [[ $const_yn == [Yy] ]]
    then
        const="-C"
        const_yn="yes"
        const_text="是"
    else
        const=""
        const_yn="no"
        const_text="否"
    fi
    Println "	固定码率: $green $const_text $plain\n"
}

SetEncrypt()
{
    Println "是否加密段[y/N]"
    read -p "(默认: $d_encrypt_text): " encrypt_yn
    encrypt_yn=${encrypt_yn:-$d_encrypt_text}
    if [[ $encrypt_yn == [Yy] ]]
    then
        encrypt="-e"
        encrypt_yn="yes"
        encrypt_text="是"
        if [ "${live_yn:-}" == "yes" ] && [[ ! -x $(command -v openssl) ]]
        then
            Println "是否安装 openssl ? [Y/n]"
            read -p "(默认: Y): " openssl_install_yn
            openssl_install_yn=${openssl_install_yn:-Y}
            if [[ $openssl_install_yn == [Yy] ]]
            then
                echo
                Progress &
                progress_pid=$!
                CheckRelease
                if [ "$release" == "rpm" ] 
                then
                    yum -y install openssl openssl-devel >/dev/null 2>&1
                else
                    apt-get -y install openssl libssl-dev >/dev/null 2>&1
                fi
                kill $progress_pid
                echo -n "...100%" && Println "$info openssl 安装完成"
            else
                encrypt=""
                encrypt_yn="no"
                encrypt_text="否"
            fi
        fi

        if [ "$d_encrypt_session_yn" == "no" ] 
        then
            d_encrypt_session_text="N"
        else
            d_encrypt_session_text="Y"
        fi
        Println "是否加密 session ? [y/N]"
        echo -e "$tip 加密后只能通过网页浏览\n"
        read -p "(默认: $d_encrypt_session_text): " encrypt_session_yn
        encrypt_session_yn=${encrypt_session_yn:-$d_encrypt_session_text}
        if [[ $encrypt_session_yn == [Yy] ]]
        then
            encrypt_session_yn="yes"
            encrypt_session_text="是"

            if [ ! -e "/usr/local/nginx" ] 
            then
                Println "需安装 nginx，耗时会很长，是否继续？[y/N]"
                read -p "(默认: N): " nginx_install_yn
                nginx_install_yn=${nginx_install_yn:-N}
                if [[ $nginx_install_yn == [Yy] ]] 
                then
                    InstallNginx
                    Println "$info Nginx 安装完成"
                else
                    encrypt_session_yn="no"
                    encrypt_session_text="否"
                fi
            fi

            if [ ! -e "/usr/local/nginx" ] 
            then
                encrypt_session_yn="no"
                encrypt_session_text="否"
            elif [[ ! -x $(command -v node) ]] || [[ ! -x $(command -v npm) ]]
            then
                Println "需安装配置 nodejs, 是否继续 ? [Y/n]"
                read -p "(默认: Y): " nodejs_install_yn
                nodejs_install_yn=${nodejs_install_yn:-Y}
                if [[ $nodejs_install_yn == [Yy] ]] 
                then
                    InstallNodejs
                    if [[ -x $(command -v node) ]] && [[ -x $(command -v npm) ]] 
                    then
                        if [ ! -e "$NODE_ROOT/index.js" ] 
                        then
                            NodejsConfig
                        fi
                    else
                        Println "$error nodejs 安装发生错误"
                        encrypt_session_yn="no"
                        encrypt_session_text="否"
                    fi
                else
                    encrypt_session_yn="no"
                    encrypt_session_text="否"
                fi
            elif [ ! -e "$NODE_ROOT/index.js" ] 
            then
                NodejsConfig
            fi
        else
            encrypt_session_yn="no"
            encrypt_session_text="否"
        fi
        Println "	加密 session: $green $encrypt_session_text $plain"
    else
        encrypt=""
        encrypt_yn="no"
        encrypt_text="否"
        encrypt_session_yn="no"
    fi
    Println "	加密段: $green $encrypt_text $plain\n"
}

SetKeyInfoName()
{
    Println "请输入 keyinfo 名称"
    read -p "(默认: ${d_keyinfo_name:-随机}): " keyinfo_name
    keyinfo_name=${keyinfo_name:-$d_keyinfo_name}
    keyinfo_name=${keyinfo_name:-$(RandStr)}
    Println "	keyinfo 名称: $green $keyinfo_name $plain\n"
}

SetKeyName()
{
    Println "请输入 key 名称"
    read -p "(默认: ${d_key_name:-随机}): " key_name
    key_name=${key_name:-$d_key_name}
    key_name=${key_name:-$(RandStr)}
    Println "	key 名称: $green $key_name $plain\n"
}

SetInputFlags()
{
    if [[ ${stream_link:-} == *".m3u8"* ]] || [ "${is_hls:-0}" -eq 1 ]
    then
        d_input_flags=${d_input_flags//-reconnect_at_eof 1/}
    elif [ "${stream_link:0:4}" == "rtmp" ] || [ "${is_local:-0}" -eq 1 ]
    then
        d_input_flags=${d_input_flags//-timeout 2000000000/}
        d_input_flags=${d_input_flags//-reconnect 1/}
        d_input_flags=${d_input_flags//-reconnect_at_eof 1/}
        d_input_flags=${d_input_flags//-reconnect_streamed 1/}
        d_input_flags=${d_input_flags//-reconnect_delay_max 2000/}
        lead=${d_input_flags%%[^[:blank:]]*}
        d_input_flags=${d_input_flags#${lead}}
    fi
    Println "请输入额外的输入参数"
    read -p "(默认: $d_input_flags): " input_flags
    input_flags=${input_flags:-$d_input_flags}
    Println "	输入参数: $green ${input_flags:-无} $plain\n"
}

SetOutputFlags()
{
    if [ -n "${kind:-}" ] 
    then
        d_output_flags=${d_output_flags//-sc_threshold 0/}
    fi
    Println "请输入额外的输出参数, 可以输入 omit 省略此选项"
    read -p "(默认: ${d_output_flags:-不设置}): " output_flags
    output_flags=${output_flags:-$d_output_flags}
    if [ "$output_flags" == "omit" ] 
    then
        output_flags=""
    fi
    Println "	输出参数: $green ${output_flags:-不设置} $plain\n"
}

SetVideoAudioShift()
{
    Println "画面或声音延迟？
    ${green}1.$plain 设置 画面延迟
    ${green}2.$plain 设置 声音延迟
    ${green}3.$plain 不设置
    "
    while read -p "(默认: $d_video_audio_shift_text): " video_audio_shift_num
    do
        case $video_audio_shift_num in
            "") 
                if [ -n "${d_video_shift:-}" ] 
                then
                    video_shift=$d_video_shift
                elif [ -n "${d_audio_shift:-}" ] 
                then
                    audio_shift=$d_audio_shift
                fi

                video_audio_shift=""
                video_audio_shift_text=$d_video_audio_shift_text
                break
            ;;
            1) 
                Println "请输入延迟时间（比如 0.5）"
                read -p "(默认: 返回上级选项): " video_shift
                if [ -n "$video_shift" ] 
                then
                    video_audio_shift="v_$video_shift"
                    video_audio_shift_text="画面延迟 $video_shift 秒"
                    break
                else
                    echo
                fi
            ;;
            2) 
                Println "请输入延迟时间（比如 0.5）"
                read -p "(默认: 返回上级选项): " audio_shift
                if [ -n "$audio_shift" ] 
                then
                    video_audio_shift="a_$audio_shift"
                    video_audio_shift_text="声音延迟 $audio_shift 秒"
                    break
                else
                    echo
                fi
            ;;
            3) 
                video_audio_shift_text="不设置"
                break
            ;;
            *) Println "$error 请输入正确序号(1、2、3)或直接回车 \n"
            ;;
        esac
    done

    Println "	延迟: $green $video_audio_shift_text $plain\n"
}

SetChannelName()
{
    Println "请输入频道名称(可以是中文)"
    read -p "(默认: 跟m3u8名称相同): " channel_name
    if [ -z "${playlist_name:-}" ] 
    then
        playlist_name=$($JQ_FILE -r '.channels[]|select(.pid=='"$chnl_pid"').playlist_name' "$CHANNELS_FILE")
    fi
    channel_name=${channel_name:-$playlist_name}
    Println "	频道名称: $green $channel_name $plain\n"
}

SetSync()
{
    Println "是否启用 sync ? [Y/n]"
    read -p "(默认: $d_sync_text): " sync_yn
    sync_yn=${sync_yn:-$d_sync_text}
    if [[ $sync_yn == [Yy] ]]
    then
        sync_yn="yes"
        sync_text="$green启用$plain"
    else
        sync_yn="no"
        sync_text="$red禁用$plain"
    fi
    Println "	sync: $sync_text\n"
}

SetSyncFile()
{
    Println "设置单独的 sync_file"
    echo -e "$tip 多个文件用空格分隔\n"
    read -p "(默认: ${d_sync_file:-不设置}): " sync_file
    sync_file_text=${sync_file:-$d_sync_file}
    Println "	单独的 sync_file: $green ${sync_file_text:-不设置} $plain\n"
}

SetSyncIndex()
{
    Println "设置单独的 sync_index"
    echo -e "$tip 多个 sync_index 用空格分隔\n"
    read -p "(默认: ${d_sync_index:-不设置}): " sync_index
    sync_index_text=${sync_index:-$d_sync_index}
    Println "	单独的 sync_index: $green ${sync_index_text:-不设置} $plain\n"
}

SetSyncPairs()
{
    Println "设置单独的 sync_pairs"
    read -p "(默认: ${d_sync_pairs:-不设置}): " sync_pairs
    sync_pairs_text=${sync_pairs:-$d_sync_pairs}
    Println "	单独的 sync_pairs: $green ${sync_pairs_text:-不设置} $plain\n"
}

SetFlvPushLink()
{
    Println "请输入推流地址(比如 rtmp://127.0.0.1/flv/xxx )"
    while read -p "(默认: 取消): " flv_push_link
    do
        [ -z "$flv_push_link" ] && Println "已取消...\n" && exit 1
        if [[ -z $($JQ_FILE '.channels[] | select(.flv_push_link=="'"$flv_push_link"'")' "$CHANNELS_FILE") ]]
        then
            break
        else
            Println "$error 推流地址已存在！请重新输入\n"
        fi
    done
    Println "	推流地址: $green $flv_push_link $plain\n"
}

SetFlvPullLink()
{
    Println "请输入拉流(播放)地址, 如 http://domain.com/flv?app=flv&stream=xxx"
    echo -e "$tip 监控会验证此链接来确定是否重启频道，如果不确定可以先留空\n"
    read -p "(默认: 不设置): " flv_pull_link
    Println "	拉流地址: $green ${flv_pull_link:-不设置} $plain\n"
}

PrepTerm()
{
    unset term_child_pid
    unset term_kill_needed
    trap 'HandleTerm' TERM
}

HandleTerm()
{
    if [ -n "${term_child_pid:-}" ]
    then
        if [ "$force_exit" -eq 1 ] 
        then
            kill -9 "$term_child_pid" > /dev/null 2>> "$MONITOR_LOG" || true
        else
            kill -TERM "$term_child_pid" > /dev/null 2>> "$MONITOR_LOG" || true
        fi
    else
        term_kill_needed="yes"
    fi
}

WaitTerm()
{
    term_child_pid=$!
    if [ -n "${term_kill_needed:-}" ]
    then
        if [ "$force_exit" -eq 1 ] 
        then
            kill -9 "$term_child_pid" > /dev/null 2>> "$MONITOR_LOG" || true
        else
            kill -TERM "$term_child_pid" > /dev/null 2>> "$MONITOR_LOG" || true
        fi
    fi
    wait $term_child_pid || true
    trap - TERM
    wait $term_child_pid || true
}

FlvStreamCreatorWithShift()
{
    trap '' HUP INT
    pid="$BASHPID"
    force_exit=1
    mkdir -p "/tmp/flv.lockdir"
    echo > "/tmp/flv.lockdir/$pid"
    if [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$pid"')' "$CHANNELS_FILE") ]] 
    then
        true &
        rand_pid=$!
        while [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$rand_pid"')' "$CHANNELS_FILE") ]] 
        do
            true &
            rand_pid=$!
        done
        JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$pid"')|.pid)='"$rand_pid"''
    fi
    case $from in
        "AddChannel") 
            new_channel=$(
            $JQ_FILE -n --arg pid "$pid" --arg status "off" \
                --arg stream_link "$stream_links_input" --arg live "$live_yn" \
                --arg proxy "$proxy" --arg user_agent "$user_agent" \
                --arg headers "$headers" --arg cookies "$cookies" \
                --arg output_dir_name "$output_dir_name" --arg playlist_name "$playlist_name" \
                --arg seg_dir_name "$SEGMENT_DIRECTORY" --arg seg_name "$seg_name" \
                --arg seg_length "$seg_length" --arg seg_count "$seg_count" \
                --arg video_codec "$VIDEO_CODEC" --arg audio_codec "$AUDIO_CODEC" \
                --arg video_audio_shift "$video_audio_shift" --arg quality "$quality" \
                --arg bitrates "$bitrates" --arg const "$const_yn" \
                --arg encrypt "$encrypt_yn" --arg encrypt_session "$encrypt_session_yn" \
                --arg keyinfo_name "$keyinfo_name" --arg key_name "$key_name" \
                --arg input_flags "$FFMPEG_INPUT_FLAGS" --arg output_flags "$FFMPEG_FLAGS" \
                --arg channel_name "$channel_name" --arg sync "$sync_yn" \
                --arg sync_file "$sync_file" --arg sync_index "$sync_index" \
                --arg sync_pairs "$sync_pairs" --arg flv_status "on" \
                --arg flv_push_link "$flv_push_link" --arg flv_pull_link "$flv_pull_link" \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    user_agent: $user_agent,
                    headers: $headers,
                    cookies: $cookies,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: now|strftime("%s")|tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: now|strftime("%s")|tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )
            JQ add "$CHANNELS_FILE" channels "[$new_channel]"

            action="add"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$pid)|.flv_status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $channel_name FLV 关闭" >> "$MONITOR_LOG"
                chnl_pid=$pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                rm -f "/tmp/flv.lockdir/$pid"
            ' EXIT

            resolution=""

            if [ -z "$quality" ]
            then
                if [ -n "$bitrates" ] 
                then
                    bitrates=${bitrates%%,*}
                    if [[ $bitrates == *"-"* ]] 
                    then
                        resolution=${bitrates#*-}
                        resolution="-vf scale=${resolution//x/:}"
                        bitrates=${bitrates%-*}
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                    elif [[ $bitrates == *"x"* ]] 
                    then
                        resolution=$bitrates
                        resolution="-vf scale=${resolution//x/:}"
                    else
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                    fi
                fi
            elif [ -n "$bitrates" ] 
            then
                bitrates=${bitrates%%,*}
                if [[ $bitrates == *"-"* ]] 
                then
                    resolution=${bitrates#*-}
                    resolution="-vf scale=${resolution//x/:}"
                    bitrates=${bitrates%-*}
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                elif [[ $bitrates == *"x"* ]] 
                then
                    resolution=$bitrates
                    resolution="-vf scale=${resolution//x/:}"
                    quality_command="-crf $quality"
                else
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                fi
            else
                quality_command="-crf $quality"
            fi

            if [ -n "${video_shift:-}" ] 
            then
                map_command="-itsoffset $video_shift -i $stream_link -map 0:v -map 1:a"
            elif [ -n "${audio_shift:-}" ] 
            then
                map_command="-itsoffset $audio_shift -i $stream_link -map 0:a -map 1:v"
            else
                map_command=""
            fi

            if [[ $FFMPEG_FLAGS == *"-vf "* ]] && [ -n "$resolution" ]
            then
                FFMPEG_FLAGS_A=${FFMPEG_FLAGS%-vf *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS#*-vf }
                FFMPEG_FLAGS_C=${FFMPEG_FLAGS_B%% *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS_B#* }
                FFMPEG_FLAGS="$FFMPEG_FLAGS_A $FFMPEG_FLAGS_B"
                resolution="-vf $FFMPEG_FLAGS_C,${resolution#*-vf }"
            fi

            if [ "${stream_link:0:4}" == "http" ] 
            then
                PrepTerm
                $FFMPEG $proxy_command -user_agent "$user_agent" -headers $"$headers" -cookies "$cookies" $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command \
                -y -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                $FFMPEG_FLAGS -f flv "$flv_push_link" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                WaitTerm
            else
                PrepTerm
                $FFMPEG $proxy_command $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command \
                -y -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                $FFMPEG_FLAGS -f flv "$flv_push_link" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                WaitTerm
            fi
        ;;
        "StartChannel") 
            new_pid=$pid
            JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.pid)='"$new_pid"'
            |(.channels[]|select(.pid=='"$new_pid"')|.flv_status)="on"
            |(.channels[]|select(.pid=='"$new_pid"')|.stream_link)="'"$chnl_stream_links"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.user_agent)="'"$chnl_user_agent"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.headers)="'"$chnl_headers"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.cookies)="'"$chnl_cookies"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.flv_push_link)="'"$chnl_flv_push_link"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.flv_pull_link)="'"$chnl_flv_pull_link"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.channel_time)='"$chnl_channel_time"''
            action="start"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$new_pid)|.flv_status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $chnl_channel_name FLV 关闭" >> "$MONITOR_LOG"
                chnl_pid=$new_pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                rm -f "/tmp/flv.lockdir/$chnl_pid"
            ' EXIT

            resolution=""

            if [ -z "$chnl_quality" ]
            then
                if [ -n "$chnl_bitrates" ] 
                then
                    chnl_bitrates=${chnl_bitrates%%,*}
                    if [[ $chnl_bitrates == *"-"* ]] 
                    then
                        resolution=${chnl_bitrates#*-}
                        resolution="-vf scale=${resolution//x/:}"
                        chnl_bitrates=${chnl_bitrates%-*}
                        if [ -n "$chnl_const" ] 
                        then
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k -bufsize ${chnl_bitrates}k -minrate ${chnl_bitrates}k -maxrate ${chnl_bitrates}k"
                        else
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k"
                        fi
                    elif [[ $chnl_bitrates == *"x"* ]] 
                    then
                        resolution=$chnl_bitrates
                        resolution="-vf scale=${resolution//x/:}"
                    else
                        if [ -n "$chnl_const" ] 
                        then
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k -bufsize ${chnl_bitrates}k -minrate ${chnl_bitrates}k -maxrate ${chnl_bitrates}k"
                        else
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k"
                        fi
                    fi
                fi
            elif [ -n "$chnl_bitrates" ] 
            then
                chnl_bitrates=${chnl_bitrates%%,*}
                if [[ $chnl_bitrates == *"-"* ]] 
                then
                    resolution=${chnl_bitrates#*-}
                    resolution="-vf scale=${resolution//x/:}"
                    chnl_bitrates=${chnl_bitrates%-*}
                    chnl_quality_command="-crf $chnl_quality -maxrate ${chnl_bitrates}k -bufsize ${chnl_bitrates}k"
                    if [ "$chnl_video_codec" == "libx265" ]
                    then
                    chnl_quality_command="$chnl_quality_command -x265-params --vbv-maxrate ${chnl_bitrates}k --vbv-bufsize ${chnl_bitrates}k"
                    fi
                elif [[ $chnl_bitrates == *"x"* ]] 
                then
                    resolution=$chnl_bitrates
                    resolution="-vf scale=${resolution//x/:}"
                    chnl_quality_command="-crf $chnl_quality"
                else
                    chnl_quality_command="-crf $chnl_quality -maxrate ${chnl_bitrates}k -bufsize ${chnl_bitrates}k"
                    if [ "$chnl_video_codec" == "libx265" ]
                    then
                    chnl_quality_command="$chnl_quality_command -x265-params --vbv-maxrate ${chnl_bitrates}k --vbv-bufsize ${chnl_bitrates}k"
                    fi
                fi
            else
                chnl_quality_command="-crf $chnl_quality"
            fi

            if [ -n "${chnl_video_shift:-}" ] 
            then
                map_command="-itsoffset $chnl_video_shift -i $chnl_stream_link -map 0:v -map 1:a"
            elif [ -n "${chnl_audio_shift:-}" ] 
            then
                map_command="-itsoffset $chnl_audio_shift -i $chnl_stream_link -map 0:a -map 1:v"
            else
                map_command=""
            fi

            if [[ $FFMPEG_FLAGS == *"-vf "* ]] && [ -n "$resolution" ]
            then
                FFMPEG_FLAGS_A=${FFMPEG_FLAGS%-vf *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS#*-vf }
                FFMPEG_FLAGS_C=${FFMPEG_FLAGS_B%% *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS_B#* }
                FFMPEG_FLAGS="$FFMPEG_FLAGS_A $FFMPEG_FLAGS_B"
                resolution="-vf $FFMPEG_FLAGS_C,${resolution#*-vf }"
            fi

            if [ "${chnl_stream_link:0:4}" == "http" ] 
            then
                PrepTerm
                $FFMPEG $chnl_proxy_command -user_agent "$chnl_user_agent" -headers $"$chnl_headers" -cookies "$chnl_cookies" $FFMPEG_INPUT_FLAGS -i "$chnl_stream_link" $map_command \
                -y -vcodec "$chnl_video_codec" -acodec "$chnl_audio_codec" $chnl_quality_command $chnl_bitrates_command $resolution \
                $FFMPEG_FLAGS -f flv "$chnl_flv_push_link" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
                WaitTerm
            else
                PrepTerm
                $FFMPEG $chnl_proxy_command $FFMPEG_INPUT_FLAGS -i "$chnl_stream_link" $map_command \
                -y -vcodec "$chnl_video_codec" -acodec "$chnl_audio_codec" $chnl_quality_command $chnl_bitrates_command $resolution \
                $FFMPEG_FLAGS -f flv "$chnl_flv_push_link" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
                WaitTerm
            fi
        ;;
        "command") 
            new_channel=$(
            $JQ_FILE -n --arg pid "$pid" --arg status "off" \
                --arg stream_link "$stream_link" --arg live "$live_yn" \
                --arg proxy "$proxy" \
                --arg output_dir_name "$output_dir_name" --arg playlist_name "$playlist_name" \
                --arg seg_dir_name "$SEGMENT_DIRECTORY" --arg seg_name "$seg_name" \
                --arg seg_length "$seg_length" --arg seg_count "$seg_count" \
                --arg video_codec "$VIDEO_CODEC" --arg audio_codec "$AUDIO_CODEC" \
                --arg video_audio_shift "$video_audio_shift" --arg quality "$quality" \
                --arg bitrates "$bitrates" --arg const "$const_yn" \
                --arg encrypt "$encrypt_yn" --arg encrypt_session "$encrypt_session_yn" \
                --arg keyinfo_name "$keyinfo_name" --arg key_name "$key_name" \
                --arg input_flags "$FFMPEG_INPUT_FLAGS" --arg output_flags "$FFMPEG_FLAGS" \
                --arg channel_name "$channel_name" --arg sync "$sync_yn" \
                --arg sync_file '' --arg sync_index '' \
                --arg sync_pairs '' --arg flv_status "on" \
                --arg flv_push_link "$flv_push_link" --arg flv_pull_link "$flv_pull_link" \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: now|strftime("%s")|tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: now|strftime("%s")|tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )

            JQ add "$CHANNELS_FILE" channels "[$new_channel]"

            action="add"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$pid)|.flv_status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $channel_name FLV 关闭" >> "$MONITOR_LOG"
                chnl_pid=$pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                rm -f "/tmp/flv.lockdir/$pid"
            ' EXIT

            resolution=""

            if [ -z "$quality" ]
            then
                if [ -n "$bitrates" ] 
                then
                    bitrates=${bitrates%%,*}
                    if [[ $bitrates == *"-"* ]] 
                    then
                        resolution=${bitrates#*-}
                        resolution="-vf scale=${resolution//x/:}"
                        bitrates=${bitrates%-*}
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                    elif [[ $bitrates == *"x"* ]] 
                    then
                        resolution=$bitrates
                        resolution="-vf scale=${resolution//x/:}"
                    else
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                    fi
                fi
            elif [ -n "$bitrates" ] 
            then
                bitrates=${bitrates%%,*}
                if [[ $bitrates == *"-"* ]] 
                then
                    resolution=${bitrates#*-}
                    resolution="-vf scale=${resolution//x/:}"
                    bitrates=${bitrates%-*}
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                elif [[ $bitrates == *"x"* ]] 
                then
                    resolution=$bitrates
                    resolution="-vf scale=${resolution//x/:}"
                    quality_command="-crf $quality"
                else
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                fi
            else
                quality_command="-crf $quality"
            fi

            if [ -n "${video_shift:-}" ] 
            then
                map_command="-itsoffset $video_shift -i $stream_link -map 0:v -map 1:a"
            elif [ -n "${audio_shift:-}" ] 
            then
                map_command="-itsoffset $audio_shift -i $stream_link -map 0:a -map 1:v"
            else
                map_command=""
            fi

            if [[ $FFMPEG_FLAGS == *"-vf "* ]] && [ -n "$resolution" ]
            then
                FFMPEG_FLAGS_A=${FFMPEG_FLAGS%-vf *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS#*-vf }
                FFMPEG_FLAGS_C=${FFMPEG_FLAGS_B%% *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS_B#* }
                FFMPEG_FLAGS="$FFMPEG_FLAGS_A $FFMPEG_FLAGS_B"
                resolution="-vf $FFMPEG_FLAGS_C,${resolution#*-vf }"
            fi

            if [ "${stream_link:0:4}" == "http" ] 
            then
                PrepTerm
                $FFMPEG $proxy_command -user_agent "$user_agent" -headers $"$headers" -cookies "$cookies" $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                $FFMPEG_FLAGS -f flv "$flv_push_link" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                WaitTerm
            else
                PrepTerm
                $FFMPEG $proxy_command $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                $FFMPEG_FLAGS -f flv "$flv_push_link" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                WaitTerm
            fi
        ;;
    esac
}

HlsStreamCreatorPlus()
{
    trap '' HUP INT
    force_exit=1
    pid="$BASHPID"
    if [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$pid"')' "$CHANNELS_FILE") ]] 
    then
        true &
        rand_pid=$!
        while [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$rand_pid"')' "$CHANNELS_FILE") ]] 
        do
            true &
            rand_pid=$!
        done

        JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$pid"')|.pid)='"$rand_pid"''
    fi
    case $from in
        "AddChannel") 
            mkdir -p "$output_dir_root"
            new_channel=$(
            $JQ_FILE -n --arg pid "$pid" --arg status "on" \
                --arg stream_link "$stream_links_input" --arg live "$live_yn" \
                --arg proxy "$proxy" --arg user_agent "$user_agent" \
                --arg headers "$headers" --arg cookies "$cookies" \
                --arg output_dir_name "$output_dir_name" --arg playlist_name "$playlist_name" \
                --arg seg_dir_name "$SEGMENT_DIRECTORY" --arg seg_name "$seg_name" \
                --arg seg_length "$seg_length" --arg seg_count "$seg_count" \
                --arg video_codec "$VIDEO_CODEC" --arg audio_codec "$AUDIO_CODEC" \
                --arg video_audio_shift "$video_audio_shift" --arg quality "$quality" \
                --arg bitrates "$bitrates" --arg const "$const_yn" \
                --arg encrypt "$encrypt_yn" --arg encrypt_session "$encrypt_session_yn" \
                --arg keyinfo_name "$keyinfo_name" --arg key_name "$key_name" \
                --arg input_flags "$FFMPEG_INPUT_FLAGS" --arg output_flags "$FFMPEG_FLAGS" \
                --arg channel_name "$channel_name" --arg sync "$sync_yn" \
                --arg sync_file "$sync_file" --arg sync_index "$sync_index" \
                --arg sync_pairs "$sync_pairs" --arg flv_status "off" \
                --arg flv_push_link '' --arg flv_pull_link '' \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    user_agent: $user_agent,
                    headers: $headers,
                    cookies: $cookies,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: now|strftime("%s")|tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: now|strftime("%s")|tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )

            JQ add "$CHANNELS_FILE" channels "[$new_channel]"

            action="add"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$pid)|.status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $channel_name HLS 关闭" >> "$MONITOR_LOG"
                chnl_pid=$pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                until [ ! -d "$output_dir_root" ]
                do
                    rm -rf "$output_dir_root"
                done
            ' EXIT

            resolution=""
            output_name="${seg_name}_%05d"

            if [ -z "$quality" ]
            then
                if [ -n "$bitrates" ] 
                then
                    bitrates=${bitrates%%,*}
                    if [[ $bitrates == *"-"* ]] 
                    then
                        resolution=${bitrates#*-}
                        resolution="-vf scale=${resolution//x/:}"
                        bitrates=${bitrates%-*}
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                        output_name="${seg_name}_${bitrates}_%05d"
                    elif [[ $bitrates == *"x"* ]] 
                    then
                        resolution=$bitrates
                        resolution="-vf scale=${resolution//x/:}"
                    else
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                        output_name="${seg_name}_${bitrates}_%05d"
                    fi
                fi
            elif [ -n "$bitrates" ] 
            then
                bitrates=${bitrates%%,*}
                if [[ $bitrates == *"-"* ]] 
                then
                    resolution=${bitrates#*-}
                    resolution="-vf scale=${resolution//x/:}"
                    bitrates=${bitrates%-*}
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                    output_name="${seg_name}_${bitrates}_%05d"
                elif [[ $bitrates == *"x"* ]] 
                then
                    resolution=$bitrates
                    resolution="-vf scale=${resolution//x/:}"
                    quality_command="-crf $quality"
                else
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                    output_name="${seg_name}_${bitrates}_%05d"
                fi
            else
                quality_command="-crf $quality"
            fi

            if [ -n "${video_shift:-}" ] 
            then
                map_command="-itsoffset $video_shift -i $stream_link -map 0:v -map 1:a"
            elif [ -n "${audio_shift:-}" ] 
            then
                map_command="-itsoffset $audio_shift -i $stream_link -map 0:a -map 1:v"
            else
                map_command=""
            fi

            if [[ $FFMPEG_FLAGS == *"-vf "* ]] && [ -n "$resolution" ]
            then
                FFMPEG_FLAGS_A=${FFMPEG_FLAGS%-vf *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS#*-vf }
                FFMPEG_FLAGS_C=${FFMPEG_FLAGS_B%% *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS_B#* }
                FFMPEG_FLAGS="$FFMPEG_FLAGS_A $FFMPEG_FLAGS_B"
                resolution="-vf $FFMPEG_FLAGS_C,${resolution#*-vf }"
            fi

            if [ "$live_yn" == "yes" ] 
            then
                live_command="-segment_list_flags +live"
                seg_count_command="-segment_list_size $seg_count -segment_wrap $((seg_count * 2))"
                hls_flags_command="-hls_flags periodic_rekey+delete_segments"
            else
                live_command=""
                seg_count_command=""
                hls_flags_command="-hls_flags periodic_rekey"
            fi

            if [ -z "$seg_dir_name" ] 
            then
                seg_dir_path=""
            else
                seg_dir_path="$seg_dir_name/"
            fi

            if [ "$encrypt_yn" == "yes" ]
            then
                openssl rand 16 > "$output_dir_root/$key_name.key"
                if [ "$encrypt_session_yn" == "yes" ] 
                then
                    echo -e "/keys?key=$key_name&channel=$output_dir_name\n$output_dir_root/$key_name.key\n$(openssl rand -hex 16)" > "$output_dir_root/$keyinfo_name.keyinfo"
                else
                    echo -e "$key_name.key\n$output_dir_root/$key_name.key\n$(openssl rand -hex 16)" > "$output_dir_root/$keyinfo_name.keyinfo"
                fi
                if [ "${stream_link:0:4}" == "http" ] 
                then
                    PrepTerm
                    $FFMPEG $proxy_command -user_agent "$user_agent" -headers $"$headers" -cookies "$cookies" $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header $FFMPEG_FLAGS -f hls -hls_time "$seg_length" \
                    -hls_list_size $seg_count -hls_delete_threshold $seg_count -hls_key_info_file "$output_dir_root/$keyinfo_name.keyinfo" \
                    $hls_flags_command -hls_segment_filename "$output_dir_root/$seg_dir_path$output_name.ts" "$output_dir_root/$playlist_name.m3u8" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                else
                    PrepTerm
                    $FFMPEG $proxy_command $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header $FFMPEG_FLAGS -f hls -hls_time "$seg_length" \
                    -hls_list_size $seg_count -hls_delete_threshold $seg_count -hls_key_info_file "$output_dir_root/$keyinfo_name.keyinfo" \
                    $hls_flags_command -hls_segment_filename "$output_dir_root/$seg_dir_path$output_name.ts" "$output_dir_root/$playlist_name.m3u8" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                fi
            else
                if [ "${stream_link:0:4}" == "http" ] 
                then
                    PrepTerm
                    $FFMPEG $proxy_command -user_agent "$user_agent" -headers $"$headers" -cookies "$cookies" $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header -f segment -segment_list "$output_dir_root/$playlist_name.m3u8" \
                    -segment_time "$seg_length" -segment_format mpeg_ts $live_command \
                    $seg_count_command $FFMPEG_FLAGS "$output_dir_root/$seg_dir_path$output_name.ts" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                else
                    PrepTerm
                    $FFMPEG $proxy_command $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header -f segment -segment_list "$output_dir_root/$playlist_name.m3u8" \
                    -segment_time "$seg_length" -segment_format mpeg_ts $live_command \
                    $seg_count_command $FFMPEG_FLAGS "$output_dir_root/$seg_dir_path$output_name.ts" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                fi
            fi
        ;;
        "StartChannel") 
            mkdir -p "$chnl_output_dir_root"
            new_pid=$pid
            JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.pid)='"$new_pid"'
            |(.channels[]|select(.pid=='"$new_pid"')|.status)="on"
            |(.channels[]|select(.pid=='"$new_pid"')|.stream_link)="'"$chnl_stream_links"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.user_agent)="'"$chnl_user_agent"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.headers)="'"$chnl_headers"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.cookies)="'"$chnl_cookies"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.playlist_name)="'"$chnl_playlist_name"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.seg_name)="'"$chnl_seg_name"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.key_name)="'"$chnl_key_name"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.key_time)='"$chnl_key_time"'
            |(.channels[]|select(.pid=='"$new_pid"')|.channel_time)='"$chnl_channel_time"''
            action="start"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$new_pid)|.status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $chnl_channel_name HLS 关闭" >> "$MONITOR_LOG"
                chnl_pid=$new_pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                until [ ! -d "$chnl_output_dir_root" ]
                do
                    rm -rf "$chnl_output_dir_root"
                done
            ' EXIT

            resolution=""
            output_name="${chnl_seg_name}_%05d"

            if [ -z "$chnl_quality" ]
            then
                if [ -n "$chnl_bitrates" ] 
                then
                    chnl_bitrates=${chnl_bitrates%%,*}
                    if [[ $chnl_bitrates == *"-"* ]] 
                    then
                        resolution=${chnl_bitrates#*-}
                        resolution="-vf scale=${resolution//x/:}"
                        chnl_bitrates=${chnl_bitrates%-*}
                        if [ -n "$chnl_const" ] 
                        then
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k -bufsize ${chnl_bitrates}k -minrate ${chnl_bitrates}k -maxrate ${chnl_bitrates}k"
                        else
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k"
                        fi
                        output_name="${chnl_seg_name}_${chnl_bitrates}_%05d"
                    elif [[ $chnl_bitrates == *"x"* ]] 
                    then
                        resolution=$chnl_bitrates
                        resolution="-vf scale=${resolution//x/:}"
                    else
                        if [ -n "$chnl_const" ] 
                        then
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k -bufsize ${chnl_bitrates}k -minrate ${chnl_bitrates}k -maxrate ${chnl_bitrates}k"
                        else
                            chnl_bitrates_command="-b:v ${chnl_bitrates}k"
                        fi
                        output_name="${chnl_seg_name}_${chnl_bitrates}_%05d"
                    fi
                fi
            elif [ -n "$chnl_bitrates" ] 
            then
                chnl_bitrates=${chnl_bitrates%%,*}
                if [[ $chnl_bitrates == *"-"* ]] 
                then
                    resolution=${chnl_bitrates#*-}
                    resolution="-vf scale=${resolution//x/:}"
                    chnl_bitrates=${chnl_bitrates%-*}
                    chnl_quality_command="-crf $chnl_quality -maxrate ${chnl_bitrates}k -bufsize ${chnl_bitrates}k"
                    if [ "$chnl_video_codec" == "libx265" ]
                    then
                    chnl_quality_command="$chnl_quality_command -x265-params --vbv-maxrate ${chnl_bitrates}k --vbv-bufsize ${chnl_bitrates}k"
                    fi
                    output_name="${chnl_seg_name}_${chnl_bitrates}_%05d"
                elif [[ $chnl_bitrates == *"x"* ]] 
                then
                    resolution=$chnl_bitrates
                    resolution="-vf scale=${resolution//x/:}"
                    chnl_quality_command="-crf $chnl_quality"
                else
                    chnl_quality_command="-crf $chnl_quality -maxrate ${chnl_bitrates}k -bufsize ${chnl_bitrates}k"
                    if [ "$chnl_video_codec" == "libx265" ]
                    then
                    chnl_quality_command="$chnl_quality_command -x265-params --vbv-maxrate ${chnl_bitrates}k --vbv-bufsize ${chnl_bitrates}k"
                    fi
                    output_name="${chnl_seg_name}_${chnl_bitrates}_%05d"
                fi
            else
                chnl_quality_command="-crf $chnl_quality"
            fi

            if [ -n "${chnl_video_shift:-}" ] 
            then
                map_command="-itsoffset $chnl_video_shift -i $chnl_stream_link -map 0:v -map 1:a"
            elif [ -n "${chnl_audio_shift:-}" ] 
            then
                map_command="-itsoffset $chnl_audio_shift -i $chnl_stream_link -map 0:a -map 1:v"
            else
                map_command=""
            fi

            if [ -n "$chnl_live" ] 
            then
                chnl_live_command="-segment_list_flags +live"
                chnl_seg_count_command="-segment_list_size $chnl_seg_count -segment_wrap $((chnl_seg_count * 2))"
                chnl_hls_flags_command="-hls_flags periodic_rekey+delete_segments"
            else
                chnl_live_command=""
                chnl_seg_count_command=""
                chnl_hls_flags_command="-hls_flags periodic_rekey"
            fi

            if [[ $FFMPEG_FLAGS == *"-vf "* ]] && [ -n "$resolution" ]
            then
                FFMPEG_FLAGS_A=${FFMPEG_FLAGS%-vf *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS#*-vf }
                FFMPEG_FLAGS_C=${FFMPEG_FLAGS_B%% *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS_B#* }
                FFMPEG_FLAGS="$FFMPEG_FLAGS_A $FFMPEG_FLAGS_B"
                resolution="-vf $FFMPEG_FLAGS_C,${resolution#*-vf }"
            fi

            if [ -z "$chnl_seg_dir_name" ] 
            then
                chnl_seg_dir_path=""
            else
                chnl_seg_dir_path="$chnl_seg_dir_name/"
            fi

            if [ "$chnl_encrypt_yn" == "yes" ] 
            then
                openssl rand 16 > "$chnl_output_dir_root/$chnl_key_name.key"
                if [ "$chnl_encrypt_session_yn" == "yes" ] 
                then
                    echo -e "/keys?key=$chnl_key_name&channel=$chnl_output_dir_name\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                else
                    echo -e "$chnl_key_name.key\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                fi
                if [ "${chnl_stream_link:0:4}" == "http" ] 
                then
                    PrepTerm
                    $FFMPEG $chnl_proxy_command -user_agent "$chnl_user_agent" -headers $"$chnl_headers" -cookies "$chnl_cookies" $FFMPEG_INPUT_FLAGS -i "$chnl_stream_link" $map_command -y \
                    -vcodec "$chnl_video_codec" -acodec "$chnl_audio_codec" $chnl_quality_command $chnl_bitrates_command $resolution \
                    -threads 0 -flags -global_header $FFMPEG_FLAGS -f hls -hls_time "$chnl_seg_length" \
                    -hls_list_size $chnl_seg_count -hls_delete_threshold $chnl_seg_count -hls_key_info_file "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo" \
                    $chnl_hls_flags_command -hls_segment_filename "$chnl_output_dir_root/$chnl_seg_dir_path$output_name.ts" "$chnl_output_dir_root/$chnl_playlist_name.m3u8" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
                    WaitTerm
                else
                    PrepTerm
                    $FFMPEG $chnl_proxy_command $FFMPEG_INPUT_FLAGS -i "$chnl_stream_link" $map_command -y \
                    -vcodec "$chnl_video_codec" -acodec "$chnl_audio_codec" $chnl_quality_command $chnl_bitrates_command $resolution \
                    -threads 0 -flags -global_header $FFMPEG_FLAGS -f hls -hls_time "$chnl_seg_length" \
                    -hls_list_size $chnl_seg_count -hls_delete_threshold $chnl_seg_count -hls_key_info_file "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo" \
                    $chnl_hls_flags_command -hls_segment_filename "$chnl_output_dir_root/$chnl_seg_dir_path$output_name.ts" "$chnl_output_dir_root/$chnl_playlist_name.m3u8" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
                    WaitTerm
                fi
            else
                if [ "${chnl_stream_link:0:4}" == "http" ] 
                then
                    PrepTerm
                    $FFMPEG $chnl_proxy_command -user_agent "$chnl_user_agent" -headers $"$chnl_headers" -cookies "$chnl_cookies" $FFMPEG_INPUT_FLAGS -i "$chnl_stream_link" $map_command -y \
                    -vcodec "$chnl_video_codec" -acodec "$chnl_audio_codec" $chnl_quality_command $chnl_bitrates_command $resolution \
                    -threads 0 -flags -global_header -f segment -segment_list "$chnl_output_dir_root/$chnl_playlist_name.m3u8" \
                    -segment_time "$chnl_seg_length" -segment_format mpeg_ts $chnl_live_command \
                    $chnl_seg_count_command $FFMPEG_FLAGS "$chnl_output_dir_root/$chnl_seg_dir_path$output_name.ts" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
                    WaitTerm
                else
                    PrepTerm
                    $FFMPEG $chnl_proxy_command $FFMPEG_INPUT_FLAGS -i "$chnl_stream_link" $map_command -y \
                    -vcodec "$chnl_video_codec" -acodec "$chnl_audio_codec" $chnl_quality_command $chnl_bitrates_command $resolution \
                    -threads 0 -flags -global_header -f segment -segment_list "$chnl_output_dir_root/$chnl_playlist_name.m3u8" \
                    -segment_time "$chnl_seg_length" -segment_format mpeg_ts $chnl_live_command \
                    $chnl_seg_count_command $FFMPEG_FLAGS "$chnl_output_dir_root/$chnl_seg_dir_path$output_name.ts" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
                    WaitTerm
                fi
            fi
        ;;
        "command") 
            mkdir -p "$output_dir_root"
            new_channel=$(
            $JQ_FILE -n --arg pid "$pid" --arg status "on" \
                --arg stream_link "$stream_link" --arg live "$live_yn" \
                --arg proxy "$proxy" \
                --arg output_dir_name "$output_dir_name" --arg playlist_name "$playlist_name" \
                --arg seg_dir_name "$SEGMENT_DIRECTORY" --arg seg_name "$seg_name" \
                --arg seg_length "$seg_length" --arg seg_count "$seg_count" \
                --arg video_codec "$VIDEO_CODEC" --arg audio_codec "$AUDIO_CODEC" \
                --arg video_audio_shift "$video_audio_shift" --arg quality "$quality" \
                --arg bitrates "$bitrates" --arg const "$const_yn" \
                --arg encrypt "$encrypt_yn" --arg encrypt_session "$encrypt_session_yn" \
                --arg keyinfo_name "$keyinfo_name" --arg key_name "$key_name" \
                --arg input_flags "$FFMPEG_INPUT_FLAGS" --arg output_flags "$FFMPEG_FLAGS" \
                --arg channel_name "$channel_name" --arg sync "$sync_yn" \
                --arg sync_file '' --arg sync_index '' \
                --arg sync_pairs '' --arg flv_status "off" \
                --arg flv_push_link "$flv_push_link" --arg flv_pull_link "$flv_pull_link" \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: now|strftime("%s")|tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: now|strftime("%s")|tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )

            JQ add "$CHANNELS_FILE" channels "[$new_channel]"

            action="add"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$pid)|.status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $channel_name HLS 关闭" >> "$MONITOR_LOG"
                chnl_pid=$pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                until [ ! -d "$output_dir_root" ]
                do
                    rm -rf "$output_dir_root"
                done
            ' EXIT

            resolution=""
            output_name="${seg_name}_%05d"

            if [ -z "$quality" ]
            then
                if [ -n "$bitrates" ] 
                then
                    bitrates=${bitrates%%,*}
                    if [[ $bitrates == *"-"* ]] 
                    then
                        resolution=${bitrates#*-}
                        resolution="-vf scale=${resolution//x/:}"
                        bitrates=${bitrates%-*}
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                        output_name="${seg_name}_${bitrates}_%05d"
                    elif [[ $bitrates == *"x"* ]] 
                    then
                        resolution=$bitrates
                        resolution="-vf scale=${resolution//x/:}"
                    else
                        if [ -n "$const" ] 
                        then
                            bitrates_command="-b:v ${bitrates}k -bufsize ${bitrates}k -minrate ${bitrates}k -maxrate ${bitrates}k"
                        else
                            bitrates_command="-b:v ${bitrates}k"
                        fi
                        output_name="${seg_name}_${bitrates}_%05d"
                    fi
                fi
            elif [ -n "$bitrates" ] 
            then
                bitrates=${bitrates%%,*}
                if [[ $bitrates == *"-"* ]] 
                then
                    resolution=${bitrates#*-}
                    resolution="-vf scale=${resolution//x/:}"
                    bitrates=${bitrates%-*}
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                    output_name="${seg_name}_${bitrates}_%05d"
                elif [[ $bitrates == *"x"* ]] 
                then
                    resolution=$bitrates
                    resolution="-vf scale=${resolution//x/:}"
                    quality_command="-crf $quality"
                else
                    quality_command="-crf $quality -maxrate ${bitrates}k -bufsize ${bitrates}k"
                    if [ "$VIDEO_CODEC" == "libx265" ]
                    then
                    quality_command="$quality_command -x265-params --vbv-maxrate ${bitrates}k --vbv-bufsize ${bitrates}k"
                    fi
                    output_name="${seg_name}_${bitrates}_%05d"
                fi
            else
                quality_command="-crf $quality"
            fi
            
            if [ -n "${video_shift:-}" ] 
            then
                map_command="-itsoffset $video_shift -i $stream_link -map 0:v -map 1:a"
            elif [ -n "${audio_shift:-}" ] 
            then
                map_command="-itsoffset $audio_shift -i $stream_link -map 0:a -map 1:v"
            else
                map_command=""
            fi

            if [[ $FFMPEG_FLAGS == *"-vf "* ]] && [ -n "$resolution" ]
            then
                FFMPEG_FLAGS_A=${FFMPEG_FLAGS%-vf *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS#*-vf }
                FFMPEG_FLAGS_C=${FFMPEG_FLAGS_B%% *}
                FFMPEG_FLAGS_B=${FFMPEG_FLAGS_B#* }
                FFMPEG_FLAGS="$FFMPEG_FLAGS_A $FFMPEG_FLAGS_B"
                resolution="-vf $FFMPEG_FLAGS_C,${resolution#*-vf }"
            fi

            if [ "$live_yn" == "yes" ] 
            then
                live_command="-segment_list_flags +live"
                seg_count_command="-segment_list_size $seg_count -segment_wrap $((seg_count * 2))"
                hls_flags_command="-hls_flags periodic_rekey+delete_segments"
            else
                live_command=""
                seg_count_command=""
                hls_flags_command="-hls_flags periodic_rekey"
            fi

            if [ -z "$seg_dir_name" ] 
            then
                seg_dir_path=""
            else
                seg_dir_path="$seg_dir_name/"
            fi

            if [ "$encrypt_yn" == "yes" ]
            then
                openssl rand 16 > "$output_dir_root/$key_name.key"
                if [ "$encrypt_session_yn" == "yes" ] 
                then
                    echo -e "/keys?key=$key_name&channel=$output_dir_name\n$output_dir_root/$key_name.key\n$(openssl rand -hex 16)" > "$output_dir_root/$keyinfo_name.keyinfo"
                else
                    echo -e "$key_name.key\n$output_dir_root/$key_name.key\n$(openssl rand -hex 16)" > "$output_dir_root/$keyinfo_name.keyinfo"
                fi
                if [ "${stream_link:0:4}" == "http" ] 
                then
                    PrepTerm
                    $FFMPEG $proxy_command -user_agent "$user_agent" -headers $"$headers" -cookies "$cookies" $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header $FFMPEG_FLAGS -f hls -hls_time "$seg_length" \
                    -hls_list_size $seg_count -hls_delete_threshold $seg_count -hls_key_info_file "$output_dir_root/$keyinfo_name.keyinfo" \
                    $hls_flags_command -hls_segment_filename "$output_dir_root/$seg_dir_path$output_name.ts" "$output_dir_root/$playlist_name.m3u8" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                else
                    PrepTerm
                    $FFMPEG $proxy_command $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header $FFMPEG_FLAGS -f hls -hls_time "$seg_length" \
                    -hls_list_size $seg_count -hls_delete_threshold $seg_count -hls_key_info_file "$output_dir_root/$keyinfo_name.keyinfo" \
                    $hls_flags_command -hls_segment_filename "$output_dir_root/$seg_dir_path$output_name.ts" "$output_dir_root/$playlist_name.m3u8" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                fi
            else
                if [ "${stream_link:0:4}" == "http" ] 
                then
                    PrepTerm
                    $FFMPEG $proxy_command -user_agent "$user_agent" -headers $"$headers" -cookies "$cookies" $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header -f segment -segment_list "$output_dir_root/$playlist_name.m3u8" \
                    -segment_time "$seg_length" -segment_format mpeg_ts $live_command \
                    $seg_count_command $FFMPEG_FLAGS "$output_dir_root/$seg_dir_path$output_name.ts" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                else
                    PrepTerm
                    $FFMPEG $proxy_command $FFMPEG_INPUT_FLAGS -i "$stream_link" $map_command -y \
                    -vcodec "$VIDEO_CODEC" -acodec "$AUDIO_CODEC" $quality_command $bitrates_command $resolution \
                    -threads 0 -flags -global_header -f segment -segment_list "$output_dir_root/$playlist_name.m3u8" \
                    -segment_time "$seg_length" -segment_format mpeg_ts $live_command \
                    $seg_count_command $FFMPEG_FLAGS "$output_dir_root/$seg_dir_path$output_name.ts" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
                    WaitTerm
                fi
            fi
        ;;
    esac
}

HlsStreamCreator()
{
    force_exit=0
    trap '' HUP INT
    pid="$BASHPID"
    if [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$pid"')' "$CHANNELS_FILE") ]] 
    then
        true &
        rand_pid=$!
        while [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$rand_pid"')' "$CHANNELS_FILE") ]] 
        do
            true &
            rand_pid=$!
        done

        JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$pid"')|.pid)='"$rand_pid"''
    fi
    case $from in
        "AddChannel") 
            mkdir -p "$output_dir_root"
            new_channel=$(
            $JQ_FILE -n --arg pid "$pid" --arg status "on" \
                --arg stream_link "$stream_links_input" --arg live "$live_yn" \
                --arg proxy "$proxy" --arg user_agent "$user_agent" \
                --arg headers "$headers" --arg cookies "$cookies" \
                --arg output_dir_name "$output_dir_name" --arg playlist_name "$playlist_name" \
                --arg seg_dir_name "$SEGMENT_DIRECTORY" --arg seg_name "$seg_name" \
                --arg seg_length "$seg_length" --arg seg_count "$seg_count" \
                --arg video_codec "$VIDEO_CODEC" --arg audio_codec "$AUDIO_CODEC" \
                --arg video_audio_shift "$video_audio_shift" --arg quality "$quality" \
                --arg bitrates "$bitrates" --arg const "$const_yn" \
                --arg encrypt "$encrypt_yn" --arg encrypt_session "$encrypt_session_yn" \
                --arg keyinfo_name "$keyinfo_name" --arg key_name "$key_name" \
                --arg input_flags "$FFMPEG_INPUT_FLAGS" --arg output_flags "$FFMPEG_FLAGS" \
                --arg channel_name "$channel_name" --arg sync "$sync_yn" \
                --arg sync_file "$sync_file" --arg sync_index "$sync_index" \
                --arg sync_pairs "$sync_pairs" --arg flv_status "off" \
                --arg flv_push_link '' --arg flv_pull_link '' \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    user_agent: $user_agent,
                    headers: $headers,
                    cookies: $cookies,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: now|strftime("%s")|tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: now|strftime("%s")|tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )

            JQ add "$CHANNELS_FILE" channels "[$new_channel]"

            action="add"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$pid)|.status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $channel_name HLS 关闭" >> "$MONITOR_LOG"
                chnl_pid=$pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                until [ ! -d "$output_dir_root" ]
                do
                    rm -rf "$output_dir_root"
                done
            ' EXIT

            if [ -n "$quality" ] 
            then
                quality_command="-q $quality"
            fi

            if [ -n "$bitrates" ] 
            then
                bitrates_command="-b $bitrates"
            fi

            export http_proxy="$proxy"

            PrepTerm
            $CREATOR_FILE $live -i "$stream_link" -s "$seg_length" \
            -o "$output_dir_root" $seg_count_command $bitrates_command \
            -p "$playlist_name" -t "$seg_name" $key_name_command $quality_command \
            "$const" "$encrypt" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
            WaitTerm
        ;;
        "StartChannel") 
            mkdir -p "$chnl_output_dir_root"
            new_pid=$pid
            JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.pid)='"$new_pid"'
            |(.channels[]|select(.pid=='"$new_pid"')|.status)="on"
            |(.channels[]|select(.pid=='"$new_pid"')|.stream_link)="'"$chnl_stream_links"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.user_agent)="'"$chnl_user_agent"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.headers)="'"$chnl_headers"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.cookies)="'"$chnl_cookies"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.playlist_name)="'"$chnl_playlist_name"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.seg_name)="'"$chnl_seg_name"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.key_name)="'"$chnl_key_name"'"
            |(.channels[]|select(.pid=='"$new_pid"')|.key_time)='"$chnl_key_time"'
            |(.channels[]|select(.pid=='"$new_pid"')|.channel_time)='"$chnl_channel_time"''
            action="start"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$new_pid)|.status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $chnl_channel_name HLS 关闭" >> "$MONITOR_LOG"
                chnl_pid=$new_pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                until [ ! -d "$chnl_output_dir_root" ]
                do
                    rm -rf "$chnl_output_dir_root"
                done
            ' EXIT

            if [ -n "$chnl_quality" ] 
            then
                chnl_quality_command="-q $chnl_quality"
            fi

            if [ -n "$chnl_bitrates" ] 
            then
                chnl_bitrates_command="-b $chnl_bitrates"
            fi

            export http_proxy="$chnl_proxy"

            PrepTerm
            $CREATOR_FILE $chnl_live -i "$chnl_stream_link" -s "$chnl_seg_length" \
            -o "$chnl_output_dir_root" $chnl_seg_count_command $chnl_bitrates_command \
            -p "$chnl_playlist_name" -t "$chnl_seg_name" $chnl_key_name_command $chnl_quality_command \
            "$chnl_const" "$chnl_encrypt" > "$FFMPEG_LOG_ROOT/$new_pid.log" 2> "$FFMPEG_LOG_ROOT/$new_pid.err" &
            WaitTerm
        ;;
        "command") 
            mkdir -p "$output_dir_root"
            new_channel=$(
            $JQ_FILE -n --arg pid "$pid" --arg status "on" \
                --arg stream_link "$stream_link" --arg live "$live_yn" \
                --arg proxy "$proxy" \
                --arg output_dir_name "$output_dir_name" --arg playlist_name "$playlist_name" \
                --arg seg_dir_name "$SEGMENT_DIRECTORY" --arg seg_name "$seg_name" \
                --arg seg_length "$seg_length" --arg seg_count "$seg_count" \
                --arg video_codec "$VIDEO_CODEC" --arg audio_codec "$AUDIO_CODEC" \
                --arg video_audio_shift '' --arg quality "$quality" \
                --arg bitrates "$bitrates" --arg const "$const_yn" \
                --arg encrypt "$encrypt_yn" --arg encrypt_session "$encrypt_session_yn" \
                --arg keyinfo_name "$keyinfo_name" --arg key_name "$key_name" \
                --arg input_flags "$FFMPEG_INPUT_FLAGS" --arg output_flags "$FFMPEG_FLAGS" \
                --arg channel_name "$channel_name" --arg sync "$sync_yn" \
                --arg sync_file '' --arg sync_index '' \
                --arg sync_pairs '' --arg flv_status "off" \
                --arg flv_push_link "$flv_push_link" --arg flv_pull_link "$flv_pull_link" \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: now|strftime("%s")|tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: now|strftime("%s")|tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )

            JQ add "$CHANNELS_FILE" channels "[$new_channel]"

            action="add"
            SyncFile

            trap '
                JQ update "$CHANNELS_FILE" "(.channels[]|select(.pid==$pid)|.status)=\"off\""
                printf -v date_now "%(%m-%d %H:%M:%S)T"
                printf "%s\n" "$date_now $channel_name HLS 关闭" >> "$MONITOR_LOG"
                chnl_pid=$pid
                action="stop"
                SyncFile > /dev/null 2>> "$MONITOR_LOG"
                until [ ! -d "$output_dir_root" ]
                do
                    rm -rf "$output_dir_root"
                done
            ' EXIT

            if [ -n "$quality" ] 
            then
                quality_command="-q $quality"
            fi

            if [ -n "$bitrates" ] 
            then
                bitrates_command="-b $bitrates"
            fi

            export http_proxy="$proxy"

            PrepTerm
            $CREATOR_FILE -l -i "$stream_link" -s "$seg_length" \
            -o "$output_dir_root" -c "$seg_count" $bitrates_command \
            -p "$playlist_name" -t "$seg_name" -K "$key_name" $quality_command \
            "$const" "$encrypt" > "$FFMPEG_LOG_ROOT/$pid.log" 2> "$FFMPEG_LOG_ROOT/$pid.err" &
            WaitTerm
        ;;
    esac
}

AddChannel()
{
    [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !\n" && exit 1
    GetDefault
    SetStreamLink

    if [ "${stream_link:0:1}" == "/" ] 
    then
        is_local=1
    else
        is_local=0
    fi

    if [[ $stream_link == *".m3u8"* ]] 
    then
        is_hls=1
    elif [[ $stream_link == *".flv"* ]] || [[ $stream_link == *".ts"* ]]
    then
        is_hls=0
    else
        SetIsHls
    fi

    SetLive

    if [ "${stream_link:0:4}" == "http" ] 
    then
        SetProxy
        SetUserAgent
        SetHeaders
        SetCookies
    else
        proxy=""
        user_agent=""
        headers=""
        cookies=""
    fi

    if [ -n "$proxy" ] 
    then
        proxy_command="-http_proxy $proxy"
    else
        proxy_command=""
    fi

    SetVideoCodec
    SetAudioCodec
    SetVideoAudioShift

    quality_command=""
    bitrates_command=""

    if [ -z "${kind:-}" ] && [ "$video_codec" == "copy" ] && [ "$video_codec" == "copy" ]
    then
        quality=""
        bitrates=""
        const=""
        const_yn="no"
        master=0
    else
        SetQuality
        SetBitrates

        if [ -n "$bitrates" ] 
        then
            if [[ $bitrates != *"-"* ]] && [[ $bitrates == *"x"* ]]
            then
                master=0
            else
                master=1
            fi
        else
            master=0
        fi

        if [ -z "$quality" ] && [ -n "$bitrates" ] 
        then
            SetConst
        else
            const=""
            const_yn="no"
        fi
    fi

    if [ "${kind:-}" == "flv" ] 
    then
        SetFlvPushLink
        SetFlvPullLink
        output_dir_name=$(RandOutputDirName)
        playlist_name=$(RandPlaylistName)
        seg_dir_name=$d_seg_dir_name
        seg_name=$playlist_name
        seg_length=$d_seg_length
        seg_count=$d_seg_count
        encrypt=""
        encrypt_yn="no"
        encrypt_session_yn="no"
        keyinfo_name=$(RandStr)
        key_name=$(RandStr)
    else
        SetOutputDirName
        SetPlaylistName
        SetSegDirName
        SetSegName
        SetSegLength
        if [ -n "$live" ] 
        then
            SetSegCount
            seg_count_command="-c $seg_count"
        else
            seg_count=$d_seg_count
            seg_count_command=""
        fi
        SetEncrypt
        if [ -n "$encrypt" ] 
        then
            SetKeyInfoName
            SetKeyName
            key_name_command="-K $key_name"
        else
            keyinfo_name=$(RandStr)
            key_name=$(RandStr)
            key_name_command=""
        fi
    fi

    SetInputFlags
    SetOutputFlags
    SetChannelName
    SetSync

    if [ "$sync_yn" == "yes" ]
    then
        SetSyncFile
        SetSyncIndex
        SetSyncPairs
    else
        sync_file=""
        sync_index=""
        sync_pairs=""
    fi

    FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
    FFMPEG="$FFMPEG_ROOT/ffmpeg"
    export FFMPEG
    AUDIO_CODEC=$audio_codec
    VIDEO_CODEC=$video_codec
    SEGMENT_DIRECTORY=$seg_dir_name
    if [[ ${input_flags:0:1} == "'" ]] 
    then
        input_flags=${input_flags%\'}
        input_flags=${input_flags#\'}
    fi
    if [[ ${output_flags:0:1} == "'" ]] 
    then
        output_flags=${output_flags%\'}
        output_flags=${output_flags#\'}
    fi
    export AUDIO_CODEC
    export VIDEO_CODEC
    export SEGMENT_DIRECTORY
    export FFMPEG_INPUT_FLAGS=$input_flags
    export FFMPEG_FLAGS=$output_flags

    [ ! -e $FFMPEG_LOG_ROOT ] && mkdir $FFMPEG_LOG_ROOT
    from="AddChannel"

    if [ -n "${kind:-}" ] 
    then
        if [ "$kind" == "flv" ] 
        then
            if [ "$sh_debug" -eq 1 ] 
            then
                ( FlvStreamCreatorWithShift ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
            else
                ( FlvStreamCreatorWithShift ) > /dev/null 2> /dev/null < /dev/null &
            fi
        else
            Println "$error 暂不支持输出 $kind ...\n" && exit 1
        fi
    elif [ -n "${video_audio_shift:-}" ] || { [ "$encrypt_yn" == "yes" ] && [ "$live_yn" == "yes" ]; }
    then
        if [ "$sh_debug" -eq 1 ] 
        then
            ( HlsStreamCreatorPlus ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
        else
            ( HlsStreamCreatorPlus ) > /dev/null 2> /dev/null < /dev/null &
        fi
    else
        if [ "$sh_debug" -eq 1 ] 
        then
            ( HlsStreamCreator ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
        else
            ( HlsStreamCreator ) > /dev/null 2> /dev/null < /dev/null &
        fi
    fi

    Println "$info 频道添加成功 !\n"
}

EditStreamLink()
{
    SetStreamLink
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.stream_link)="'"$stream_links_input"'"'
    Println "$info 直播源修改成功 !\n"
}

EditLive()
{
    SetLive
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.live)="'"$live_yn"'"'
    Println "$info 无限时长直播修改成功 !\n"
}

EditProxy()
{
    SetProxy
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.proxy)="'"$proxy"'"'
    Println "$info 代理修改成功 !\n"
}

EditUserAgent()
{
    SetUserAgent
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.user_agent)="'"$user_agent"'"'
    Println "$info user agent 修改成功 !\n"
}

EditHeaders()
{
    SetHeaders
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.headers)="'"$headers"'"'
    Println "$info headers 修改成功 !\n"
}

EditCookies()
{
    SetCookies
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.cookies)="'"$cookies"'"'
    Println "$info cookies 修改成功 !\n"
}

EditOutputDirName()
{
    if [ "$chnl_status" == "on" ]
    then
        Println "$error 检测到频道正在运行，是否现在关闭？[y/N]"
        read -p "(默认: N): " stop_channel_yn
        stop_channel_yn=${stop_channel_yn:-n}
        if [[ $stop_channel_yn == [Yy] ]]
        then
            StopChannel
            echo && echo
        else
            Println "已取消...\n" && exit 1
        fi
    fi
    SetOutputDirName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.output_dir_name)="'"$output_dir_name"'"'
    Println "$info 输出目录名称修改成功 !\n"
}

EditPlaylistName()
{
    SetPlaylistName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.playlist_name)="'"$playlist_name"'"'
    Println "$info m3u8名称修改成功 !\n"
}

EditSegDirName()
{
    SetSegDirName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.seg_dir_name)="'"$seg_dir_name"'"'
    Println "$info 段所在子目录名称修改成功 !\n"
}

EditSegName()
{
    SetSegName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.seg_name)="'"$seg_name"'"'
    Println "$info 段名称修改成功 !\n"
}

EditSegLength()
{
    SetSegLength
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.seg_length)='"$seg_length"''
    Println "$info 段时长修改成功 !\n"
}

EditSegCount()
{
    SetSegCount
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.seg_count)='"$seg_count"''
    Println "$info 段数目修改成功 !\n"
}

EditVideoCodec()
{
    SetVideoCodec
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.video_codec)="'"$video_codec"'"'
    Println "$info 视频编码修改成功 !\n"
}

EditAudioCodec()
{
    SetAudioCodec
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.audio_codec)="'"$audio_codec"'"'
    Println "$info 音频编码修改成功 !\n"
}

EditQuality()
{
    SetQuality
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.quality)="'"$quality"'"'
    Println "$info crf质量值修改成功 !\n"
}

EditBitrates()
{
    SetBitrates
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.bitrates)="'"$bitrates"'"'
    Println "$info 比特率修改成功 !\n"
}

EditConst()
{
    SetConst
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.const)="'"$const_yn"'"'
    Println "$info 是否固定码率修改成功 !\n"
}

EditEncrypt()
{
    SetEncrypt
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.encrypt)="'"$encrypt"'"'
    Println "$info 是否加密修改成功 !\n"
}

EditKeyName()
{
    SetKeyName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.key_name)="'"$key_name"'"'
    Println "$info key名称修改成功 !\n"
}

EditInputFlags()
{
    SetInputFlags
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.input_flags)="'"$input_flags"'"'
    Println "$info 输入参数修改成功 !\n"
}

EditOutputFlags()
{
    SetOutputFlags
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.output_flags)="'"$output_flags"'"'
    Println "$info 输出参数修改成功 !\n"
}

EditChannelName()
{
    SetChannelName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.channel_name)="'"$channel_name"'"'
    Println "$info 频道名称修改成功 !\n"
}

EditSync()
{
    SetSync
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.sync)="'"$sync_yn"'"'
    Println "$info 是否开启 sync 修改成功 !\n"
}

EditSyncFile()
{
    SetSyncFile
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.sync_file)="'"$sync_file"'"'
    Println "$info sync_file 修改成功 !\n"
}

EditSyncIndex()
{
    SetSyncIndex
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.sync_index)="'"$sync_index"'"'
    Println "$info sync_index 修改成功 !\n"
}

EditSyncPairs()
{
    SetSyncPairs
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.sync_pairs)="'"$sync_pairs"'"'
    Println "$info sync_pairs 修改成功 !\n"
}

EditFlvPushLink()
{
    SetFlvPushLink
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.flv_push_link)="'"$flv_push_link"'"'
    Println "$info 推流地址修改成功 !\n"
}

EditFlvPullLink()
{
    SetFlvPullLink
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.flv_pull_link)="'"$flv_pull_link"'"'
    Println "$info 拉流地址修改成功 !\n"
}

EditChannelAll()
{
    if [ "$chnl_flv_status" == "on" ] 
    then
        kind="flv"
        Println "$error 检测到频道正在运行，是否现在关闭？[y/N]"
        read -p "(默认: N): " stop_channel_yn
        stop_channel_yn=${stop_channel_yn:-n}
        if [[ $stop_channel_yn == [Yy] ]]
        then
            StopChannel
            echo && echo
        else
            Println "已取消...\n" && exit 1
        fi
    elif [ "$chnl_status" == "on" ]
    then
        kind=""
        Println "$error 检测到频道正在运行，是否现在关闭？[y/N]"
        read -p "(默认: N): " stop_channel_yn
        stop_channel_yn=${stop_channel_yn:-n}
        if [[ $stop_channel_yn == [Yy] ]]
        then
            StopChannel
            echo && echo
        else
            Println "已取消...\n" && exit 1
        fi
    fi

    SetStreamLink

    if [ "${stream_link:0:1}" == "/" ] 
    then
        is_local=1
    else
        is_local=0
    fi

    if [[ $stream_link == *".m3u8"* ]] 
    then
        is_hls=1
    elif [[ $stream_link == *".flv"* ]] || [[ $stream_link == *".ts"* ]]
    then
        is_hls=0
    else
        SetIsHls
    fi

    SetLive

    if [ "${stream_link:0:4}" == "http" ] 
    then
        SetProxy
        SetUserAgent
        SetHeaders
        SetCookies
    else
        proxy=""
        user_agent=""
        headers=""
        cookies=""
    fi

    SetOutputDirName
    SetPlaylistName
    SetSegDirName
    SetSegName
    SetSegLength

    if [ -n "$live" ] 
    then
        SetSegCount
    else
        seg_count=$d_seg_count
    fi

    SetVideoCodec
    SetAudioCodec
    SetVideoAudioShift

    if [ -z "${kind:-}" ] && [ "$video_codec" == "copy" ] && [ "$video_codec" == "copy" ]
    then
        quality=""
        bitrates=""
        const=""
        const_yn="no"
    else
        SetQuality
        SetBitrates

        if [ -z "$quality" ] && [ -n "$bitrates" ] 
        then
            SetConst
        else
            const=""
            const_yn="no"
        fi
    fi

    if [ "${kind:-}" == "flv" ] 
    then
        SetFlvPushLink
        SetFlvPullLink
        output_dir_name=$(RandOutputDirName)
        playlist_name=$(RandPlaylistName)
        seg_dir_name=$d_seg_dir_name
        seg_name=$playlist_name
        seg_length=$d_seg_length
        seg_count=$d_seg_count
        encrypt=""
        encrypt_yn="no"
        keyinfo_name=$(RandStr)
        key_name=$(RandStr)
    else
        SetOutputDirName
        SetPlaylistName
        SetSegDirName
        SetSegName
        SetSegLength
        if [ -n "$live" ] 
        then
            SetSegCount
        else
            seg_count=$d_seg_count
        fi
        SetEncrypt
        if [ -n "$encrypt" ] 
        then
            SetKeyInfoName
            SetKeyName
        else
            keyinfo_name=$(RandStr)
            key_name=$(RandStr)
        fi
    fi

    SetInputFlags
    SetOutputFlags
    SetChannelName
    SetSync

    if [ "$sync_yn" == "yes" ]
    then
        SetSyncFile
        SetSyncIndex
        SetSyncPairs
    else
        sync_file=""
        sync_index=""
        sync_pairs=""
    fi

    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.stream_link)="'"$stream_links_input"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.live)="'"$live_yn"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.proxy)="'"$proxy"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.user_agent)="'"$user_agent"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.headers)="'"$headers"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.cookies)="'"$cookies"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.output_dir_name)="'"$output_dir_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.playlist_name)="'"$playlist_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.seg_dir_name)="'"$seg_dir_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.seg_name)="'"$seg_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.seg_length)='"$seg_length"'
    |(.channels[]|select(.pid=='"$chnl_pid"')|.seg_count)='"$seg_count"'
    |(.channels[]|select(.pid=='"$chnl_pid"')|.video_codec)="'"$video_codec"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.audio_codec)="'"$audio_codec"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.video_audio_shift)="'"$video_audio_shift"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.quality)="'"$quality"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.bitrates)="'"$bitrates"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.const)="'"$const_yn"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.encrypt)="'"$encrypt_yn"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.keyinfo_name)="'"$keyinfo_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.key_name)="'"$key_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.input_flags)="'"$input_flags"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.output_flags)="'"$output_flags"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.channel_name)="'"$channel_name"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.sync)="'"$sync_yn"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.sync_file)="'"$sync_file"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.sync_index)="'"$sync_index"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.sync_pairs)="'"$sync_pairs"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.flv_push_link)="'"$flv_push_link"'"
    |(.channels[]|select(.pid=='"$chnl_pid"')|.flv_pull_link)="'"$flv_pull_link"'"'

    Println "$info 频道 [ $channel_name ] 修改成功 !\n"
}

EditForSecurity()
{
    SetPlaylistName
    SetSegName
    JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.playlist_name)="'"$playlist_name"'"|(.channels[]|select(.pid=='"$chnl_pid"')|.seg_name)="'"$seg_name"'"'
    Println "$info 段名称、m3u8名称 修改成功 !\n"
}

EditChannelMenu()
{
    ListChannels
    InputChannelsIndex
    for chnl_pid in "${chnls_pid_chosen[@]}"
    do
        GetChannelInfo
        ViewChannelInfo
        Println "你要修改什么？
    ${green}1.$plain 修改 直播源
    ${green}2.$plain 修改 无限时长直播
    ${green}3.$plain 修改 代理
    ${green}4.$plain 修改 user agent
    ${green}5.$plain 修改 headers
    ${green}6.$plain 修改 cookies
    ${green}7.$plain 修改 输出目录名称
    ${green}8.$plain 修改 m3u8名称
    ${green}9.$plain 修改 段所在子目录名称
   ${green}10.$plain 修改 段名称
   ${green}11.$plain 修改 段时长
   ${green}12.$plain 修改 段数目
   ${green}13.$plain 修改 视频编码
   ${green}14.$plain 修改 音频编码
   ${green}15.$plain 修改 crf质量值
   ${green}16.$plain 修改 比特率
   ${green}17.$plain 修改 是否固定码率
   ${green}18.$plain 修改 是否加密
   ${green}19.$plain 修改 key名称
   ${green}20.$plain 修改 输入参数
   ${green}21.$plain 修改 输出参数
   ${green}22.$plain 修改 频道名称
   ${green}23.$plain 修改 是否开启 sync
   ${green}24.$plain 修改 sync file
   ${green}25.$plain 修改 sync index
   ${green}26.$plain 修改 sync pairs
   ${green}27.$plain 修改 推流地址
   ${green}28.$plain 修改 拉流地址
   ${green}29.$plain 修改 全部配置
    ————— 组合[常用] —————
   ${green}30.$plain 修改 段名称、m3u8名称 (防盗链/DDoS)
    \n"
        read -p "(默认: 取消): " edit_channel_num
        [ -z "$edit_channel_num" ] && Println "已取消...\n" && exit 1
        case $edit_channel_num in
            1)
                EditStreamLink
            ;;
            2)
                EditLive
            ;;
            3)
                EditProxy
            ;;
            4)
                EditUserAgent
            ;;
            5)
                EditHeaders
            ;;
            6)
                EditCookies
            ;;
            7)
                EditOutputDirName
            ;;
            8)
                EditPlaylistName
            ;;
            9)
                EditSegDirName
            ;;
            10)
                EditSegName
            ;;
            11)
                EditSegLength
            ;;
            12)
                EditSegCount
            ;;
            13)
                EditVideoCodec
            ;;
            14)
                EditAudioCodec
            ;;
            15)
                EditQuality
            ;;
            16)
                EditBitrates
            ;;
            17)
                EditConst
            ;;
            18)
                EditEncrypt
            ;;
            19)
                EditKeyName
            ;;
            20)
                EditInputFlags
            ;;
            21)
                EditOutputFlags
            ;;
            22)
                EditChannelName
            ;;
            23)
                EditSync
            ;;
            24)
                EditSyncFile
            ;;
            25)
                EditSyncIndex
            ;;
            26)
                EditSyncPairs
            ;;
            27)
                EditFlvPushLink
            ;;
            28)
                EditFlvPullLink
            ;;
            29)
                EditChannelAll
            ;;
            30)
                EditForSecurity
            ;;
            *)
                echo "请输入正确序号..." && exit 1
            ;;
        esac

        if [ "$chnl_status" == "on" ] || [ "$chnl_flv_status" == "on" ]
        then
            echo "是否重启此频道？[Y/n]"
            read -p "(默认: Y): " restart_yn
            restart_yn=${restart_yn:-Y}
            if [[ $restart_yn == [Yy] ]] 
            then
                StopChannel
                GetChannelInfo
                StartChannel
                Println "$info 频道重启成功 !\n"
            else
                echo "不重启..."
            fi
        else
            echo "是否启动此频道？[y/N]"
            read -p "(默认: N): " start_yn
            start_yn=${start_yn:-N}
            if [[ $start_yn == [Yy] ]] 
            then
                GetChannelInfo
                StartChannel
                Println "$info 频道启动成功 !\n"
            else
                echo "不启动..."
            fi
        fi
    done
}

TestXtreamCodesLink()
{
    if [ -z "${xtream_codes_domains:-}" ] 
    then
        GetXtreamCodesDomains
    fi

    if [ -z "${FFPROBE:-}" ] 
    then
        FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
        FFPROBE="$FFMPEG_ROOT/ffprobe"
    fi

    to_try=0

    if [[ ${chnl_stream_link##*|} =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
    then
        chnl_domain=${chnl_stream_link%%|*}
        chnl_mac=${chnl_stream_link##*|}
        chnl_cmd=${chnl_stream_link%|*}
        chnl_cmd=${chnl_cmd##*|}

        for xc_domain in "${xtream_codes_domains[@]}"
        do
            if [ "$xc_domain" == "$chnl_domain" ] 
            then
                Println "$info 频道[ $chnl_channel_name ]检测账号中..."
                GetXtreamCodesChnls
                for xc_chnl_mac in "${xc_chnls_mac[@]}"
                do
                    if [ "$xc_chnl_mac" == "$chnl_domain/$chnl_mac" ] 
                    then
                        to_try=1
                        break
                    fi
                done
                break
            fi
        done

        if [ "$to_try" -eq 1 ] 
        then
            to_try=1
            try_success=0
            MonitorTryAccounts
            if [ "$try_success" -eq 0 ] 
            then
                Println "$error 没有可用账号"
            fi
        else
            token=""
            access_token=""
            profile=""
            chnl_user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
            server="http://$chnl_domain"
            mac=$(Urlencode "$chnl_mac")
            timezone=$(Urlencode "Europe/Amsterdam")
            chnl_cookies="mac=$mac; stb_lang=en; timezone=$timezone"
            token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
            profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"
            genres_url="$server/portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml"

            token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                | $JQ_FILE -r '.js.token' || true)
            if [ -z "$token" ] 
            then
                Println "$error 无法连接 $chnl_domain, 请重试!\n" && exit 1
            fi
            access_token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="Authorization: Bearer $token" \
                --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                | $JQ_FILE -r '.js.token' || true)
            if [ -z "$access_token" ] 
            then
                Println "$error 无法连接 $chnl_domain, 请重试!\n" && exit 1
            fi
            chnl_headers="Authorization: Bearer $access_token"
            profile=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="$chnl_headers" \
                --header="Cookie: $chnl_cookies" "$profile_url" -qO- || true)
            if [ -z "$profile" ] 
            then
                Println "$error 无法连接 $chnl_domain, 请重试!\n" && exit 1
            fi

            if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
            then
                to_try=1
                try_success=0
                MonitorTryAccounts
                if [ "$try_success" -eq 0 ] 
                then
                    Println "$error 没有可用账号"
                fi
            else
                create_link_url="$server/portal.php?type=itv&action=create_link&cmd=$chnl_cmd&series=&forced_storage=undefined&disable_ad=0&download=0&JsHttpRequest=1-xml"
                chnl_stream_link=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                    --header="$chnl_headers" \
                    --header="Cookie: $chnl_cookies" "$create_link_url" -qO- \
                    | $JQ_FILE -r '.js.cmd')
                chnl_stream_link=${chnl_stream_link#* }
                IFS="/" read -ra s <<< "$chnl_stream_link"
                if [ "${s[3]}" == "live" ] 
                then
                    chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[5]}/${s[-1]}"
                else
                    chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[-1]}"
                fi
                if [[ $chnl_stream_links == *" "* ]] 
                then
                    chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$chnl_mac ${chnl_stream_links#* }"
                else
                    chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$chnl_mac"
                fi

                audio=0
                video=0
                while IFS= read -r line 
                do
                    if [[ $line == *"codec_type=audio"* ]] 
                    then
                        audio=1
                    elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                    then
                        audio=0
                    elif [[ $line == *"codec_type=video"* ]] 
                    then
                        video=1
                    fi
                done < <($FFPROBE $chnl_proxy_command -user_agent "$chnl_user_agent" -headers $"$chnl_headers" -cookies "$chnl_cookies" -i "$chnl_stream_link" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

                if [ "$audio" -eq 0 ] || [ "$video" -eq 0 ]
                then
                    to_try=1
                    try_success=0
                    MonitorTryAccounts
                    if [ "$try_success" -eq 0 ] 
                    then
                        Println "$error 没有可用账号"
                    fi
                fi
            fi
        fi
    elif [[ $chnl_stream_link =~ http://([^/]+)/([^/]+)/([^/]+)/ ]] 
    then
        chnl_domain=${BASH_REMATCH[1]}

        for xc_domain in "${xtream_codes_domains[@]}"
        do
            if [ "$xc_domain" == "$chnl_domain" ] 
            then
                Println "$info 频道[ $chnl_channel_name ]检测账号中..."
                to_try=1
                break
            fi
        done

        xc_chnl_found=0
        if [ "$to_try" -eq 1 ] 
        then
            if [ "${BASH_REMATCH[2]}" == "live" ] && [[ $chnl_stream_link =~ http://([^/]+)/live/([^/]+)/([^/]+)/ ]] 
            then
                chnl_account="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
            else
                chnl_account="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
            fi
            GetXtreamCodesChnls
            for xc_chnl in "${xc_chnls[@]}"
            do
                if [ "$xc_chnl" == "$chnl_domain/$chnl_account" ] 
                then
                    xc_chnl_found=1
                    break
                fi
            done
        fi

        if [ "$xc_chnl_found" -eq 1 ] 
        then
            to_try=1
            try_success=0
            MonitorTryAccounts
            if [ "$try_success" -eq 0 ] 
            then
                Println "$error 没有可用账号"
            fi
        elif [ "$to_try" -eq 1 ] 
        then
            audio=0
            video=0
            while IFS= read -r line 
            do
                if [[ $line == *"codec_type=audio"* ]] 
                then
                    audio=1
                elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                then
                    audio=0
                elif [[ $line == *"codec_type=video"* ]] 
                then
                    video=1
                fi
            done < <($FFPROBE $chnl_proxy_command -user_agent "$chnl_user_agent" -headers $"$chnl_headers" -cookies "$chnl_cookies" -i "$chnl_stream_link" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

            if [ "$audio" -eq 0 ] || [ "$video" -eq 0 ] 
            then
                try_success=0
                MonitorTryAccounts
                if [ "$try_success" -eq 0 ] 
                then
                    Println "$error 没有可用账号"
                fi
            else
                to_try=0
            fi
        fi
    fi
}

ToggleChannel()
{
    ListChannels
    InputChannelsIndex
    for chnl_pid in "${chnls_pid_chosen[@]}"
    do
        GetChannelInfo

        if [ "${kind:-}" == "flv" ] 
        then
            if [ "$chnl_flv_status" == "on" ] 
            then
                StopChannel
            else
                TestXtreamCodesLink
                if [ "$to_try" -eq 1 ] 
                then
                    continue
                fi
                StartChannel
            fi
        elif [ "$chnl_status" == "on" ] 
        then
            StopChannel
        else
            TestXtreamCodesLink
            if [ "$to_try" -eq 1 ] 
            then
                continue
            fi
            StartChannel
        fi
    done
}

StartChannel()
{
    if [ "${chnl_stream_link:0:23}" == "https://www.youtube.com" ] || [ "${chnl_stream_link:0:19}" == "https://youtube.com" ] 
    then
        if [[ ! -x $(command -v youtube-dl) ]] 
        then
            InstallYoutubeDl
        fi

        Println "$info 解析 youtube 链接..."
        code=${chnl_stream_link#*|}
        chnl_stream_link=${chnl_stream_link%|*}
        chnl_stream_link=$(youtube-dl -f "$code" -g "$chnl_stream_link")
    elif [ "${chnl_stream_link:13:12}" == "fengshows.cn" ] 
    then
        ts=$(date +%s%3N)
        tx_time=$(printf '%X' $((ts/1000+1800)))

        chnl_stream_link=${chnl_stream_link%\?*}

        relative_path=${chnl_stream_link#*//}
        relative_path="/${relative_path#*/}"

        tx_secret=$(printf '%s' "obb9Lxyv5C${relative_path%.*}$tx_time" | md5sum)
        tx_secret=${tx_secret%% *}

        chnl_stream_link="$chnl_stream_link?txSecret=$tx_secret&txTime=$tx_time"
    elif [ "${chnl_stream_link:7:12}" == "news.tvb.com" ] 
    then
        while IFS= read -r line 
        do
            if [[ $line == *"var videoUrl "* ]] 
            then
                line=${line#*= \"}
                chnl_stream_link=${line%\"*}
                break
            fi
        done < <(wget --no-check-certificate "$chnl_stream_link" -qO- || true)
    elif [ "${chnl_stream_link:0:4}" == "rtmp" ] || [ "${chnl_stream_link:0:1}" == "/" ]
    then
        chnl_input_flags=${chnl_input_flags//-timeout 2000000000/}
        chnl_input_flags=${chnl_input_flags//-reconnect 1/}
        chnl_input_flags=${chnl_input_flags//-reconnect_at_eof 1/}
        chnl_input_flags=${chnl_input_flags//-reconnect_streamed 1/}
        chnl_input_flags=${chnl_input_flags//-reconnect_delay_max 2000/}
        lead=${chnl_input_flags%%[^[:blank:]]*}
        chnl_input_flags=${chnl_input_flags#${lead}}
    fi

    if [[ ${chnl_stream_link:-} == *".m3u8"* ]] 
    then
        chnl_input_flags=${chnl_input_flags//-reconnect_at_eof 1/}
    fi

    chnl_quality_command=""
    chnl_bitrates_command=""

    if [ -z "${kind:-}" ] && [ "$chnl_video_codec" == "copy" ] && [ "$chnl_audio_codec" == "copy" ]
    then
        chnl_quality=""
        chnl_bitrates=""
        chnl_const=""
        master=0
    else
        if [ -n "$chnl_quality" ] 
        then
            chnl_const=""
        fi

        if [ -n "$chnl_bitrates" ] 
        then
            if [[ $chnl_bitrates != *"-"* ]] && [[ $chnl_bitrates == *"x"* ]]
            then
                master=0
            else
                master=1
            fi
        else
            master=0
        fi
    fi

    FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
    FFMPEG="$FFMPEG_ROOT/ffmpeg"
    export FFMPEG
    AUDIO_CODEC=$chnl_audio_codec
    VIDEO_CODEC=$chnl_video_codec
    SEGMENT_DIRECTORY=$chnl_seg_dir_name
    if [[ ${chnl_input_flags:0:1} == "'" ]] 
    then
        chnl_input_flags=${chnl_input_flags%\'}
        chnl_input_flags=${chnl_input_flags#\'}
    fi
    if [[ ${chnl_output_flags:0:1} == "'" ]] 
    then
        chnl_output_flags=${chnl_output_flags%\'}
        chnl_output_flags=${chnl_output_flags#\'}
    fi
    export AUDIO_CODEC
    export VIDEO_CODEC
    export SEGMENT_DIRECTORY
    export FFMPEG_INPUT_FLAGS=$chnl_input_flags
    export FFMPEG_FLAGS=$chnl_output_flags

    [ ! -e $FFMPEG_LOG_ROOT ] && mkdir $FFMPEG_LOG_ROOT
    from="StartChannel"

    printf -v start_time '%(%s)T'
    chnl_channel_time=$start_time

    if [ -n "${kind:-}" ] 
    then
        if [ "$chnl_status" == "on" ] 
        then
            Println "$error HLS 频道正开启，走错片场了？\n" && exit 1
        fi
        FFMPEG_FLAGS=${FFMPEG_FLAGS//-sc_threshold 0/}
        if [ "$kind" == "flv" ] 
        then
            rm -f "$FFMPEG_LOG_ROOT/$chnl_pid.log"
            rm -f "$FFMPEG_LOG_ROOT/$chnl_pid.err"
            if [ "$sh_debug" -eq 1 ] 
            then
                ( FlvStreamCreatorWithShift ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
            else
                ( FlvStreamCreatorWithShift ) > /dev/null 2> /dev/null < /dev/null &
            fi
        else
            Println "$error 暂不支持输出 $kind ...\n" && exit 1
        fi
    else
        if [ "$chnl_flv_status" == "on" ] 
        then
            Println "$error FLV 频道正开启，走错片场了？\n" && exit 1
        fi
        rm -f "$FFMPEG_LOG_ROOT/$chnl_pid.log"
        rm -f "$FFMPEG_LOG_ROOT/$chnl_pid.err"
        if [ -n "${chnl_video_audio_shift:-}" ] || { [ "$chnl_encrypt_yn" == "yes" ] && [ "$chnl_live_yn" == "yes" ]; }
        then
            if [ "$sh_debug" -eq 1 ] 
            then
                ( HlsStreamCreatorPlus ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
            else
                ( HlsStreamCreatorPlus ) > /dev/null 2> /dev/null < /dev/null &
            fi
        else
            if [ "$sh_debug" -eq 1 ] 
            then
                ( HlsStreamCreator ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
            else
                ( HlsStreamCreator ) > /dev/null 2> /dev/null < /dev/null &
            fi
        fi
    fi

    Println "$info 频道[ $chnl_channel_name ]已开启 !\n"
}

StopChannel()
{
    if [ -n "${kind:-}" ]
    then
        if [ "$kind" != "flv" ] 
        then
            Println "$error 暂不支持 $kind ...\n" && exit 1
        elif [ "$chnl_status" == "on" ]
        then
            Println "$error HLS 频道正开启，走错片场了？\n" && exit 1
        fi
    elif [ "$chnl_flv_status" == "on" ]
    then
        Println "$error FLV 频道正开启，走错片场了？\n" && exit 1
    fi

    if [ "${kind:-}" == "flv" ] 
    then
        if kill -0 "$chnl_pid" 2> /dev/null 
        then
            Println "$info 关闭频道, 请稍等..."
            if kill "$chnl_pid" 2> /dev/null
            then
                until [ ! -f "/tmp/flv.lockdir/$chnl_pid" ]
                do
                    sleep 1
                done
            else
                Println "$error 频道关闭失败, 请重试 !" && exit 1
            fi
        else
            JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.flv_status)="off"'
            printf -v date_now '%(%m-%d %H:%M:%S)T'
            printf '%s\n' "$date_now $chnl_channel_name FLV 关闭" >> "$MONITOR_LOG"
            action="stop"
            SyncFile
            rm -f "/tmp/flv.lockdir/$chnl_pid"
        fi
        chnl_flv_status="off"
    else
        if kill -0 "$chnl_pid" 2> /dev/null 
        then
            Println "$info 关闭频道, 请稍等..."
            if kill "$chnl_pid" 2> /dev/null 
            then
                until [ ! -d "$chnl_output_dir_root" ]
                do
                    sleep 1
                done
            else
                Println "$error 频道关闭失败, 请重试 !\n" && exit 1
            fi
        else
            JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.status)="off"'
            printf -v date_now '%(%m-%d %H:%M:%S)T'
            printf '%s\n' "$date_now $chnl_channel_name HLS 关闭" >> "$MONITOR_LOG"
            action="stop"
            SyncFile
            until [ ! -d "$chnl_output_dir_root" ]
            do
                rm -rf "$chnl_output_dir_root"
            done
        fi
        chnl_status="off"
    fi
    Println "$info 频道[ $chnl_channel_name ]已关闭 !\n"
}

StopChannelsForce()
{
    pkill -9 -f ffmpeg 2> /dev/null || true
    pkill -f 'tv m' 2> /dev/null || true
    [ -d "$CHANNELS_FILE.lockdir" ] && rm -rf "$CHANNELS_FILE.lockdir"
    GetChannelsInfo
    for((i=0;i<chnls_count;i++));
    do
        chnl_pid=${chnls_pid[i]}
        GetChannelInfoLite
        JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"$chnl_pid"')|.status)="off"
        |(.channels[]|select(.pid=='"$chnl_pid"')|.flv_status)="off"'
        chnl_sync_file=${chnl_sync_file:-$d_sync_file}
        IFS=" " read -ra chnl_sync_files <<< "$chnl_sync_file"
        for sync_file in "${chnl_sync_files[@]}"
        do
            [ -d "$sync_file.lockdir" ] && rm -rf "$sync_file.lockdir"
        done
        action="stop"
        SyncFile > /dev/null
        if [ "${chnl_live_yn}" == "yes" ] 
        then
            rm -rf "$chnl_output_dir_root"
        fi
    done
    Println "$info 全部频道已关闭 !\n"
}

RestartChannel()
{
    ListChannels
    InputChannelsIndex
    for chnl_pid in "${chnls_pid_chosen[@]}"
    do
        GetChannelInfo
        if [ "${kind:-}" == "flv" ] 
        then
            if [ "$chnl_flv_status" == "on" ] 
            then
                action="skip"
                StopChannel
            fi
        elif [ "$chnl_status" == "on" ] 
        then
            action="skip"
            StopChannel
        fi
        TestXtreamCodesLink
        if [ "$to_try" -eq 1 ] 
        then
            continue
        fi
        StartChannel
        Println "$info 频道重启成功 !\n"
    done
}

ViewChannelLog()
{
    ListChannels
    InputChannelsIndex
    for chnl_pid in "${chnls_pid_chosen[@]}"
    do
        GetChannelInfo
        ViewChannelInfo

        Println "${green}输出日志:$plain\n"
        if [ -s "$FFMPEG_LOG_ROOT/$chnl_pid.log" ] 
        then
            tail -n 10 "$FFMPEG_LOG_ROOT/$chnl_pid.log"
        else
            echo "无"
        fi

        Println "${red}错误日志:$plain\n"
        if [ -s "$FFMPEG_LOG_ROOT/$chnl_pid.err" ] 
        then
            cat "$FFMPEG_LOG_ROOT/$chnl_pid.err"
        else
            echo "无"
        fi
        echo
    done
}

DelChannel()
{
    ListChannels
    InputChannelsIndex
    for chnl_pid in "${chnls_pid_chosen[@]}"
    do
        GetChannelInfo
        if [ "${kind:-}" == "flv" ] 
        then
            if [ "$chnl_flv_status" == "on" ] 
            then
                StopChannel
            fi
        elif [ "$chnl_status" == "on" ] 
        then
            StopChannel
        fi
        JQ delete "$CHANNELS_FILE" channels "$chnl_pid"
        rm -f "$FFMPEG_LOG_ROOT/$chnl_pid.log"
        rm -f "$FFMPEG_LOG_ROOT/$chnl_pid.err"
        Println "$info 频道[ $chnl_channel_name ]删除成功 !\n"
    done
}

RandStr()
{
    str_size=${1:-8}
    str_array=(
        q w e r t y u i o p a s d f g h j k l z x c v b n m Q W E R T Y U I O P A S D
F G H J K L Z X C V B N M
    )
    str_array_size=${#str_array[*]}
    str_len=0
    rand_str=""
    while [[ $str_len -lt $str_size ]]
    do
        str_index=$((RANDOM%str_array_size))
        rand_str="$rand_str${str_array[str_index]}"
        str_len=$((str_len+1))
    done
    echo "$rand_str"
}

RandOutputDirName()
{
    while :;do
        output_dir_name=$(RandStr)
        if [[ -z $($JQ_FILE '.channels[] | select(.output_dir_name=="'"$output_dir_name"'")' "$CHANNELS_FILE") ]]
        then
            echo "$output_dir_name"
            break
        fi
    done
}

RandPlaylistName()
{
    while :;do
        playlist_name=$(RandStr)
        if [[ -z $($JQ_FILE '.channels[] | select(.playlist_name=="'"$playlist_name"'")' "$CHANNELS_FILE") ]]
        then
            echo "$playlist_name"
            break
        fi
    done
}

RandSegDirName()
{
    while :;do
        seg_dir_name=$(RandStr)
        if [[ -z $($JQ_FILE '.channels[] | select(.seg_dir_name=="'"$seg_dir_name"'")' "$CHANNELS_FILE") ]]
        then
            echo "$seg_dir_name"
            break
        fi
    done
}

# printf %s "$1" | jq -s -R -r @uri
Urlencode() {
    local LANG=C i c e=''
    for ((i=0;i<${#1};i++)); do
        c=${1:$i:1}
        [[ "$c" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v c '%%%02X' "'$c"
        e+="$c"
    done
    echo "$e"
}

GenerateScheduleNowtv()
{
    SCHEDULE_LINK_NOWTV="https://nowplayer.now.com/tvguide/epglist?channelIdList%5B%5D=$1&day=1"

    nowtv_schedule=$(curl --cookie "LANG=zh" -s "$SCHEDULE_LINK_NOWTV" || true)

    if [ -z "${nowtv_schedule:-}" ]
    then
        Println "NowTV empty: $chnl_nowtv_id\n"
        return 0
    else
        if [ ! -s "$SCHEDULE_JSON" ] 
        then
            printf '{"%s":[]}' "$chnl_nowtv_id" > "$SCHEDULE_JSON"
        fi

        schedule=""
        while IFS= read -r program
        do
            title=${program#*title: }
            title=${title%, time:*}
            time=${program#*time: }
            time=${time%, sys_time:*}
            sys_time=${program#*sys_time: }
            sys_time=${sys_time%\"}
            sys_time=${sys_time:0:10}
            [ -n "$schedule" ] && schedule="$schedule,"
            schedule=$schedule'{
                "title":"'"$title"'",
                "time":"'"$time"'",
                "sys_time":"'"$sys_time"'"
            }'
        done < <($JQ_FILE '.[0] | to_entries | map("title: \(.value.name), time: \(.value.startTime), sys_time: \(.value.start)") | .[]' <<< "$nowtv_schedule")

        if [ -z "$schedule" ] 
        then
            Println "$error\nNowTV not found\n"
        else
            JQ replace "$SCHEDULE_JSON" "$chnl_nowtv_id" "[$schedule]"
        fi
    fi
}

GenerateScheduleNiotv()
{
    if [ ! -s "$SCHEDULE_JSON" ] 
    then
        printf '{"%s":[]}' "$chnl_niotv_id" > "$SCHEDULE_JSON"
    fi

    printf -v today '%(%Y-%m-%d)T'
    SCHEDULE_LINK_NIOTV="http://www.niotv.com/i_index.php?cont=day"

    empty=1
    check=1
    schedule=""
    while IFS= read -r line
    do
        if [[ $line == *"<td class=epg_tab_tm>"* ]] 
        then
            empty=0
            line=${line#*<td class=epg_tab_tm>}
            start_time=${line%%~*}
            end_time=${line#*~}
            end_time=${end_time%%</td>*}
        fi

        if [[ $line == *"</a></td>"* ]] 
        then
            line=${line%% </a></td>*}
            line=${line%%</a></td>*}
            title=${line#*target=_blank>}
            title=${title//\"/}
            title=${title//\'/}
            title=${title//\\/\'}
            sys_time=$(date -d "$today $start_time" +%s)

            start_time_num=$sys_time
            end_time_num=$(date -d "$today $end_time" +%s)

            if [ "$check" -eq 1 ] && [ "$start_time_num" -gt "$end_time_num" ] 
            then
                continue
            fi

            check=0

            [ -n "$schedule" ] && schedule="$schedule,"
            schedule=$schedule'{
                "title":"'"$title"'",
                "time":"'"$start_time"'",
                "sys_time":"'"$sys_time"'"
            }'
        fi
    done < <(wget --post-data "act=select&day=$today&sch_id=$1" "$SCHEDULE_LINK_NIOTV" -qO- || true)
    #curl -d "day=$today&sch_id=$1" -X POST "$SCHEDULE_LINK_NIOTV" || true

    if [ "$empty" -eq 1 ] 
    then
        Println "NioTV empty: $chnl_niotv_id\ntrying NowTV...\n"
        match_nowtv=0
        for chnl_nowtv in "${chnls_nowtv[@]}" ; do
            chnl_nowtv_id=${chnl_nowtv%%:*}
            if [ "$chnl_nowtv_id" == "$chnl_niotv_id" ] 
            then
                match_nowtv=1
                chnl_nowtv_num=${chnl_nowtv#*:}
                GenerateScheduleNowtv "$chnl_nowtv_num"
                break
            fi
        done
        [ "$match_nowtv" -eq 0 ] && Println "NowTV not found"
        return 0
    fi

    JQ replace "$SCHEDULE_JSON" "$chnl_niotv_id" "[$schedule]"
}

GenerateSchedule()
{
    if [ ! -s "$SCHEDULE_JSON" ] 
    then
        printf '{"%s":[]}' "$chnl_id" > "$SCHEDULE_JSON"
    fi

    chnl_id=${1%%:*}
    chnl_name=${chnl#*:}
    chnl_name=${chnl_name// /-}
    chnl_name_encode=$(Urlencode "$chnl_name")

    printf -v today '%(%Y-%m-%d)T'

    SCHEDULE_LINK="https://xn--i0yt6h0rn.tw/channel/$chnl_name_encode/index.json"

    schedule=""
    while IFS= read -r program 
    do
        program_title=${program#*name: }
        program_title=${program_title%%, time: *}
        program_time=${program#*, time: }
        program_time=${program_time%\"}
        program_sys_time=$(date -d "$today $program_time" +%s)

        [ -n "$schedule" ] && schedule="$schedule,"
        schedule=$schedule'{
            "title":"'"$program_title"'",
            "time":"'"$program_time"'",
            "sys_time":"'"$program_sys_time"'"
        }'
    done < <($JQ_FILE '.list[] | select(.key=="'"$today"'").values | to_entries | map("name: \(.value.name), time: \(.value.time)")[]' <<< $(wget --no-check-certificate "$SCHEDULE_LINK" -qO- || true))

    if [ -z "$schedule" ]
    then
        today=${today//-/\/}
        while IFS= read -r program 
        do
            program_title=${program#*name: }
            program_title=${program_title%%, time: *}
            program_time=${program#*, time: }
            program_time=${program_time%\"}
            program_sys_time=$(date -d "$today $program_time" +%s)

            [ -n "$schedule" ] && schedule="$schedule,"
            schedule=$schedule'{
                "title":"'"$program_title"'",
                "time":"'"$program_time"'",
                "sys_time":"'"$program_sys_time"'"
            }'
        done < <($JQ_FILE '.list[] | select(.key=="'"$today"'").values | to_entries | map("name: \(.value.name), time: \(.value.time)")[]' <<< $(wget --no-check-certificate "$SCHEDULE_LINK" -qO- || true))

        if [ -z "$schedule" ] 
        then
            Println "\nempty: $1\ntrying NioTV...\n"

            match=0
            for chnl_niotv in "${chnls_niotv[@]}" ; do
                chnl_niotv_id=${chnl_niotv%%:*}
                if [ "$chnl_niotv_id" == "$chnl_id" ] 
                then
                    match=1
                    chnl_niotv_num=${chnl_niotv#*:}
                    GenerateScheduleNiotv "$chnl_niotv_num"
                fi
            done

            if [ "$match" -eq 0 ] 
            then
                Println "NioTV not found\ntrying NowTV...\n"
                for chnl_nowtv in "${chnls_nowtv[@]}" ; do
                    chnl_nowtv_id=${chnl_nowtv%%:*}
                    if [ "$chnl_nowtv_id" == "$chnl_id" ] 
                    then
                        match=1
                        chnl_nowtv_num=${chnl_nowtv#*:}
                        GenerateScheduleNowtv "$chnl_nowtv_num"
                        break
                    fi
                done
            fi

            [ "$match" -eq 0 ] && Println "NowTV not found"
            return 0
        fi
    fi

    JQ replace "$SCHEDULE_JSON" "$chnl_id" "[$schedule]"
}

InstallPdf2html()
{
    Println "$info 检查依赖，耗时可能会很长..."
    CheckRelease
    Progress &
    progress_pid=$!
    if [ "$release" == "rpm" ] 
    then
        yum install cmake gcc gnu-getopt java-1.8.0-openjdk libpng-devel fontforge-devel cairo-devel poppler-devel libspiro-devel freetype-devel libtiff-devel openjpeg libxml2-devel giflibgiflib-devel libjpeg-turbo-devel libuninameslist-devel pango-devel make gcc-c++ >/dev/null 2>&1
    else
        apt-get -y update >/dev/null 2>&1
        apt-get -y install libpoppler-private-dev libpoppler-dev libfontforge-dev pkg-config libopenjp2-7-dev libjpeg-dev libtiff5-dev libpng-dev libfreetype6-dev libgif-dev libgtk-3-dev libxml2-dev libpango1.0-dev libcairo2-dev libspiro-dev libuninameslist-dev python3-dev ninja-build cmake build-essential >/dev/null 2>&1
    fi

    echo -n "...40%..."

    while IFS= read -r line
    do
        if [[ $line == *"latest stable release is"* ]] 
        then
            line=${line#*<a href=\"}
            poppler_name=${line%%.tar.xz*}
        elif [[ $line == *"poppler encoding data"* ]] 
        then
            line=${line#*<a href=\"}
            poppler_data_name=${line%%.tar.gz*}
            break
        fi
    done < <( wget --timeout=10 --tries=3 --no-check-certificate "https://poppler.freedesktop.org/" -qO- )

    cd ~
    if [ ! -e "./$poppler_data_name" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "$FFMPEG_MIRROR_LINK/$poppler_data_name.tar.gz" -qO "$poppler_data_name.tar.gz"
        tar xzvf "$poppler_data_name.tar.gz" >/dev/null 2>&1
    fi

    cd "$poppler_data_name/"
    make install >/dev/null 2>&1

    echo -n "...50%..."

    poppler_name="poppler-0.81.0"

    cd ~
    if [ ! -e "./$poppler_name" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "$FFMPEG_MIRROR_LINK/$poppler_name.tar.xz" -qO "$poppler_name.tar.xz"
        tar -xJf "$poppler_name.tar.xz" >/dev/null 2>&1
    fi

    cd "$poppler_name/"
    mkdir -p build
    cd build
    cmake -DENABLE_UNSTABLE_API_ABI_HEADERS=ON .. >/dev/null 2>&1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1

    echo -n "...70%..."

    cd ~
    if [ ! -e "./fontforge-20190413" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "$FFMPEG_MIRROR_LINK/fontforge-20190413.tar.gz" -qO "fontforge-20190413.tar.gz"
        tar xzvf "fontforge-20190413.tar.gz" >/dev/null 2>&1
    fi

    cd "fontforge-20190413/"
    ./bootstrap >/dev/null 2>&1
    ./configure >/dev/null 2>&1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    echo -n "...90%..."

    cd ~
    if [ ! -e "./pdf2htmlEX-0.18.7-poppler-0.81.0" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "$FFMPEG_MIRROR_LINK/pdf2htmlEX-0.18.7-poppler-0.81.0.zip" -qO "pdf2htmlEX-0.18.7-poppler-0.81.0.zip"
        unzip "pdf2htmlEX-0.18.7-poppler-0.81.0.zip" >/dev/null 2>&1
    fi

    cd "pdf2htmlEX-0.18.7-poppler-0.81.0/"
    ./dobuild >/dev/null 2>&1
    cd build
    make install >/dev/null 2>&1

    kill $progress_pid
    echo -n "...100%\n"

    if grep -q "profile.d" < "/etc/profile"
    then
        echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig' >> /etc/profile.d/pdf2htmlEX
        echo 'export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}' >> /etc/profile.d/pdf2htmlEX
        # shellcheck source=/dev/null
        source /etc/profile.d/pdf2htmlEX &>/dev/null
    else
        echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig' >> /etc/profile
        echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> /etc/profile
    fi
}

Schedule()
{
    CheckRelease
    GetDefault

    if [ -n "$d_schedule_file" ] 
    then
        SCHEDULE_JSON=$d_schedule_file
    else
        echo "请先设置 schedule_file 位置！" && exit 1
    fi

    chnls=( 
#        "hbogq:HBO HD"
#        "hbohits:HBO Hits"
#        "hbosignature:HBO Signature"
#        "hbofamily:HBO Family"
#        "foxmovies:FOX MOVIES"
#        "disney:Disney"
        "minshi:民視"
        "mtvlivetw:MTV-Live"
        "tvbfc:TVB 翡翠台"
        "tvbpearl:TVB Pearl"
        "tvbj2:TVB J2"
        "tvbwxxw:TVB 互動新聞台"
        "fhwszx:凤凰卫视资讯台"
        "fhwsxg:凤凰卫视香港台"
        "fhwszw:凤凰卫视中文台"
        "xgws:香港衛視綜合台"
        "foxfamily:福斯家庭電影台"
        "hlwdy:好萊塢電影"
        "xwdy:星衛HD電影台"
        "mydy:美亞電影台"
        "mycinemaeurope:My Cinema Europe HD我的歐洲電影台"
        "ymjs:影迷數位紀實台"
        "ymdy:影迷數位電影台"
        "hyyj:華藝影劇台"
        "catchplaydy:CatchPlay電影台"
        "ccyj:采昌影劇台"
        "lxdy:LS龍祥電影"
        "cinemax:Cinemax"
        "cinemaworld:CinemaWorld"
        "axn:AXN HD"
        "channelv:Channel V國際娛樂台HD"
        "dreamworks:DREAMWORKS"
        "nickasia:Nickelodeon Asia(尼克兒童頻道)"
        "cbeebies:CBeebies"
        "babytv:Baby TV"
        "boomerang:Boomerang"
        "mykids:MY-KIDS TV"
        "dwxq:動物星球頻道"
        "eltvshyy:ELTV生活英語台"
        "ifundm:i-Fun動漫台"
        "momoqz:momo親子台"
        "cnkt:CN卡通台"
        "ffxw:非凡新聞"
        "hycj:寰宇財經台"
        "hyzh:寰宇HD綜合台"
        "hyxw:寰宇新聞台"
        "hyxw2:寰宇新聞二台"
        "aedzh:愛爾達綜合台"
        "aedyj:愛爾達影劇台"
        "jtzx:靖天資訊台"
        "jtzh:靖天綜合台"
        "jtyl:靖天育樂台"
        "jtxj:靖天戲劇台"
        "jthl:Nice TV 靖天歡樂台"
        "jtyh:靖天映畫"
        "jtgj:KLT-靖天國際台"
        "jtrb:靖天日本台"
        "jtdy:靖天電影台"
        "jtkt:靖天卡通台"
        "jyxj:靖洋戲劇台"
        "jykt:靖洋卡通台Nice Bingo"
        "lhxj:龍華戲劇"
        "lhox:龍華偶像"
        "lhyj:龍華影劇"
        "lhdy:龍華電影"
        "lhjd:龍華經典"
        "lhyp:龍華洋片"
        "lhdh:龍華動畫"
        "wszw:衛視中文台"
        "wsdy:衛視電影台"
        "gxws:國興衛視"
        "gs:公視"
        "gs2:公視2台"
        "gs3:公視3台"
        "ts:台視"
        "tszh:台視綜合台"
        "tscj:台視財經台"
        "hs:華視"
        "hsjywh:華視教育文化"
        "zs:中視"
        "zsxw:中視新聞台"
        "zsjd:中視經典台"
        "sltw:三立台灣台"
        "sldh:三立都會台"
        "slzh:三立綜合台"
        "slxj:三立戲劇台"
        "bdzh:八大綜合"
        "bddy:八大第一"
        "bdxj:八大戲劇"
        "bdyl:八大娛樂"
        "gdyl:高點育樂"
        "gdzh:高點綜合"
        "ydsdy:壹電視電影台"
        "ydszxzh:壹電視資訊綜合台"
        "wlty:緯來體育台"
        "wlxj:緯來戲劇台"
        "wlrb:緯來日本台"
        "wldy:緯來電影台"
        "wlzh:緯來綜合台"
        "wlyl:緯來育樂台"
        "wljc:緯來精采台"
        "dszh:東森綜合台"
        "dsxj:東森戲劇台"
        "dsyy:東森幼幼台"
        "dsdy:東森電影台"
        "dsyp:東森洋片台"
        "dsxw:東森新聞台"
        "dscjxw:東森財經新聞台"
        "dscs:超級電視台"
        "ztxw:中天新聞台"
        "ztyl:中天娛樂台"
        "ztzh:中天綜合台"
        "msxq:美食星球頻道"
        "yzms:亞洲美食頻道"
        "yzly:亞洲旅遊台"
        "yzzh:亞洲綜合台"
        "yzxw:亞洲新聞台"
        "pltw:霹靂台灣"
        "titvyjm:原住民"
        "history:歷史頻道"
        "history2:HISTORY 2"
        "gjdlyr:國家地理高畫質悠人頻道"
        "gjdlys:國家地理高畫質野生頻道"
        "gjdlgq:國家地理高畫質頻道"
        "bbcearth:BBC Earth"
        "bbcworldnews:BBC World News"
        "bbclifestyle:BBC Lifestyle Channel"
        "wakawakajapan:WAKUWAKU JAPAN"
        "luxe:LUXE TV Channel"
        "bswx:博斯無限台"
        "bsgq1:博斯高球一台"
        "bsgq2:博斯高球二台"
        "bsml:博斯魅力網"
        "bswq:博斯網球台"
        "bsyd1:博斯運動一台"
        "bsyd2:博斯運動二台"
        "zlty:智林體育台"
        "eurosport:EUROSPORT"
        "fox:FOX頻道"
        "foxsports:FOX SPORTS"
        "foxsports2:FOX SPORTS 2"
        "foxsports3:FOX SPORTS 3"
        "elevensportsplus:ELEVEN SPORTS PLUS"
        "elevensports2:ELEVEN SPORTS 2"
        "discoveryasia:Discovery Asia"
        "discovery:Discovery"
        "discoverykx:Discovery科學頻道"
        "tracesportstars:TRACE Sport Stars"
        "dw:DW(Deutsch)"
        "lifetime:Lifetime"
        "foxcrime:FOXCRIME"
        "foxnews:FOX News Channel"
        "animax:Animax"
        "mtvtw:MTV綜合電視台"
        "ndmuch:年代MUCH"
        "ndxw:年代新聞"
        "nhk:NHK"
        "euronews:Euronews"
        "cnn:CNN International"
        "skynews:SKY NEWS HD"
        "nhkxwzx:NHK新聞資訊台"
        "jetzh:JET綜合"
        "tlclysh:旅遊生活"
        "z:Z頻道"
        "itvchoice:ITV Choice"
        "mdrb:曼迪日本台"
        "smartzs:Smart知識台"
        "tv5monde:TV5MONDE"
        "outdoor:Outdoor"
        "eentertainment:E! Entertainment"
        "davinci:DaVinCi Learning達文西頻道"
        "my101zh:MY101綜合台"
        "blueantextreme:BLUE ANT EXTREME"
        "blueantentertainmet:BLUE ANT EXTREME"
        "eyetvxj:EYE TV戲劇台"
        "eyetvly:EYE TV旅遊台"
        "travel:Travel Channel"
        "dmax:DMAX頻道"
        "hitshd:HITS"
        "fx:FX"
        "tvbs:TVBS"
        "tvbshl:TVBS歡樂"
        "tvbsjc:TVBS精采台"
        "tvbxh:TVB星河頻道"
        "tvn:tvN"
        "hgyl:韓國娛樂台KMTV"
        "xfkjjj:幸福空間居家台"
        "xwyl:星衛娛樂台"
        "amc:AMC"
        "animaxhd:Animax HD"
        "diva:Diva"
        "bloomberg:Bloomberg TV"
        "fgss:時尚頻道"
        "warner:Warner TV"
        "ettodayzh:ETtoday綜合台" )

    chnls_niotv=( 
        "msxw:45"
        "tsxw:637"
        "slxw:38"
        "slinews:172"
        "tvbsxw:41"
        "minshi:16"
        "mtvlivetw:751"
        "hbogq:629"
        "hbohits:501"
        "hbosignature:503"
        "hbofamily:502"
        "foxmovies:47"
        "foxfamily:540"
        "disney:63"
        "dreamworks:758"
        "nickasia:705"
        "cbeebies:771"
        "babytv:553"
        "boomerang:766"
        "dwxq:61"
        "momoqz:148"
        "cnkt:65"
        "hyxw:695"
        "jtzx:709"
        "jtzh:710"
        "jtyl:202"
        "jtxj:721"
        "jthl:708"
        "jtyh:727"
        "jtrb:711"
        "jtkt:707"
        "jyxj:203"
        "jykt:706"
        "wszw:19"
        "wsdy:55"
        "gxws:73"
        "gs:17"
        "gs2:759"
        "gs3:177"
        "ts:11"
        "tszh:632"
        "tscj:633"
        "hs:15"
        "hsjywh:138"
        "zs:13"
        "zsxw:668"
        "zsjd:714"
        "sltw:34"
        "sldh:35"
        "bdzh:21"
        "bddy:33"
        "bdxj:22"
        "bdyl:60"
        "gdyl:170"
        "gdzh:143"
        "ydsdy:187"
        "ydszxzh:681"
        "wlty:66"
        "wlxj:29"
        "wlrb:72"
        "wldy:57"
        "wlzh:24"
        "wlyl:53"
        "wljc:546"
        "dszh:23"
        "dsxj:36"
        "dsyy:64"
        "dsdy:56"
        "dsyp:48"
        "dsxw:42"
        "dscjxw:43"
        "dscs:18"
        "ztxw:668"
        "ztyl:14"
        "ztzh:27"
        "yzly:778"
        "yzms:733"
        "yzxw:554"
        "pltw:26"
        "titvyjm:133"
        "history:549"
        "history2:198"
        "gjdlyr:670"
        "gjdlys:161"
        "gjdlgq:519"
        "discoveryasia:563"
        "discovery:58"
        "discoverykx:520"
        "bbcearth:698"
        "bbcworldnews:144"
        "bbclifestyle:646"
        "bswx:587"
        "bsgq1:529"
        "bsgq2:526"
        "bsml:588"
        "bsyd2:635"
        "bsyd1:527"
        "eurosport:581"
        "fox:70"
        "foxsports:67"
        "foxsports2:68"
        "foxsports3:547"
        "elevensportsplus:787"
        "elevensports2:770"
        "lifetime:199"
        "foxcrime:543"
        "cinemax:49"
        "hlwdy:52"
        "animax:84"
        "mtvtw:69"
        "ndmuch:25"
        "ndxw:40"
        "nhk:74"
        "euronews:591"
        "ffxw:79"
        "jetzh:71"
        "tlclysh:62"
        "axn:50"
        "z:75"
        "luxe:590"
        "catchplaydy:582"
        "tv5monde:574"
        "channelv:584"
        "davinci:669"
        "blueantextreme:779"
        "blueantentertainmet:785"
        "travel:684"
        "cnn:107"
        "dmax:521"
        "hitshd:692"
        "lxdy:141"
        "fx:544"
        "tvn:757"
        "hgyl:568"
        "xfkjjj:672"
        "nhkxwzx:773"
        "zlty:676"
        "xwdy:558"
        "xwyl:539"
        "mycinemaeurope:775"
        "amc:682"
        "animaxhd:772"
        "wakawakajapan:765"
        "tvbs:20"
        "tvbshl:32"
        "tvbsjc:774"
        "cinemaworld:559"
        "warner:688" )

    chnls_nowtv=( 
        "hbohits:111"
        "hbofamily:112"
        "cinemax:113"
        "hbosignature:114"
        "hbogq:115"
        "foxmovies:117"
        "foxfamily:120"
        "foxaction:118"
        "wsdy:139"
        "animaxhd:150"
        "tvn:155"
        "wszw:160"
        "discoveryasia:208"
        "discovery:209"
        "dwxq:210"
        "discoverykx:211"
        "dmax:212"
        "tlclysh:213"
        "gjdl:215"
        "gjdlys:216"
        "gjdlyr:217"
        "gjdlgq:218"
        "bbcearth:220"
        "history:223"
        "cnn:316"
        "foxnews:318"
        "bbcworldnews:320"
        "bloomberg:321"
        "yzxw:322"
        "skynews:323"
        "dw:324"
        "euronews:326"
        "nhk:328"
        "fhwszx:366"
        "fhwsxg:367"
        "xgws:368"
        "disney:441"
        "boomerang:445"
        "cbeebies:447"
        "babytv:448"
        "bbclifestyle:502"
        "eentertainment:506"
        "diva:508"
        "warner:510"
        "AXN:512"
        "blueantextreme:516"
        "blueantentertainmet:517"
        "fox:518"
        "foxcrime:523"
        "fx:524"
        "lifetime:525"
        "yzms:527"
        "channelv:534"
        "fhwszw:548"
        "zgzwws:556"
        "foxsports:670"
        "foxsports2:671"
        "foxsports3:672" )

    if [ -z ${2+x} ] 
    then
        count=0

        for chnl in "${chnls[@]}" ; do
            GenerateSchedule "$chnl"
            count=$((count + 1))
            echo -n $count
        done

        return
    fi

    case $2 in
        "hbo")
            printf -v today '%(%Y-%m-%d)T'

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "hbo" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "hbo"
                "hbotw"
                "hbored"
                "cinemax"
                "hbohd"
                "hits"
                "signature"
                "family" )

            for chnl in "${chnls[@]}" ; do

                if [ "$chnl" == "hbo" ] 
                then
                    SCHEDULE_LINK="https://hboasia.com/HBO/zh-cn/ajax/home_schedule?date=$today&channel=$chnl&feed=cn"
                elif [ "$chnl" == "hbotw" ] 
                then
                    SCHEDULE_LINK="https://hboasia.com/HBO/zh-cn/ajax/home_schedule?date=$today&channel=hbo&feed=satellite"
                elif [ "$chnl" == "hbored" ] 
                then
                    SCHEDULE_LINK="https://hboasia.com/HBO/zh-cn/ajax/home_schedule?date=$today&channel=red&feed=satellite"
                elif [ "$chnl" == "cinemax" ] 
                then
                    SCHEDULE_LINK="https://hboasia.com/HBO/zh-cn/ajax/home_schedule?date=$today&channel=$chnl&feed=satellite"
                else
                    SCHEDULE_LINK="https://hboasia.com/HBO/zh-tw/ajax/home_schedule?date=$today&channel=$chnl&feed=satellite"
                fi

                schedule=""
                while IFS= read -r program 
                do
                    program_id=${program#*id: }
                    program_id=${program_id%%, title: *}
                    program_title=${program#*, title: }
                    program_title=${program_title%%, title_local: *}
                    program_title_local=${program#*, title_local: }
                    program_title_local=${program_title_local%%, time: *}
                    program_time=${program#*, time: }
                    program_time=${program_time%%, sys_time: *}
                    program_sys_time=${program#*, sys_time: }
                    program_sys_time=${program_sys_time%\"}

                    if [ -n "$program_title_local" ] 
                    then
                        program_title="$program_title_local $program_title"
                    fi

                    [ -n "$schedule" ] && schedule="$schedule,"
                    schedule=$schedule'{
                        "id":"'"$program_id"'",
                        "title":"'"$program_title"'",
                        "time":"'"$program_time"'",
                        "sys_time":"'"$program_sys_time"'"
                    }'
                done < <($JQ_FILE 'to_entries | map("id: \(.value.id), title: \(.value.title), title_local: \(.value.title_local), time: \(.value.time), sys_time: \(.value.sys_time)")[]' <<< $(wget --no-check-certificate "$SCHEDULE_LINK" -qO-))

                if [ -z "$schedule" ] 
                then
                    Println "$error\n$chnl not found\n"
                else
                    JQ replace "$SCHEDULE_JSON" "$chnl" "[$schedule]"
                fi
            done
        ;;
        "hbous")
            printf -v today '%(%Y-%m-%d)T'
            sys_time=$(date -d $today +%s)
            min_sys_time=$((sys_time-7200))
            max_sys_time=$((sys_time+86400))
            yesterday=$(printf '%(%Y-%m-%d)T' $((sys_time - 86400)))

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "hbous_hbo" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "hbo:HBO:EAST"
                "hbo2:HBO2:EAST"
                "hbosignature:HBO SIGNATURE:EAST"
                "hbofamily:HBO FAMILY:EAST"
                "hbocomedy:HBO COMEDY:EAST"
                "hbozone:HBO ZONE:EAST"
                "hbolatino:HBO LATINO:EAST"
                "hbo:HBO:WEST"
                "hbo2:HBO2:WEST"
                "hbosignature:HBO SIGNATURE:WEST"
                "hbofamily:HBO FAMILY:WEST"
                "hbocomedy:HBO COMEDY:WEST"
                "hbozone:HBO ZONE:WEST"
                "hbolatino:HBO LATINO:WEST" )

            if [ "${4:-}" == "WEST" ] || [ "${4:-}" == "west" ]
            then
                zone="WEST"
            else
                zone="EAST"
            fi

            hbous_yesterday_schedule=$(wget --no-check-certificate "https://proxy-v4.cms.hbo.com/v1/schedule?date=$yesterday" -qO-)
            hbous_today_schedule=$(wget --no-check-certificate "https://proxy-v4.cms.hbo.com/v1/schedule?date=$today" -qO-)

            for chnl in "${chnls[@]}" ; do
                chnl_id=${chnl%%:*}
                chnl=${chnl#*:}
                chnl_name=${chnl%:*}
                chnl_zone=${chnl#*:}

                if [ -n "${3:-}" ] 
                then
                    if [ "$3" != "$chnl_id" ] || [ "$zone" != "$chnl_zone" ]
                    then
                        continue
                    fi
                fi

                schedule=""

                while IFS="=" read -r program_time program_title
                do
                    program_time=${program_time#\"}
                    program_title=${program_title%\"}
                    program_sys_time=$(date -d "$program_time" +%s)
                    if [ "$program_sys_time" -ge "$min_sys_time" ] 
                    then
                        program_time=$(printf '%(%H:%M)T' "$program_sys_time")
                        [ -n "$schedule" ] && schedule="$schedule,"
                        schedule=$schedule'{
                            "title":"'"$program_title"'",
                            "time":"'"$program_time"'",
                            "sys_time":"'"$program_sys_time"'"
                        }'
                    fi
                done < <($JQ_FILE --arg channelName "$chnl_name" --arg channelZone "$chnl_zone" '.channels | to_entries | map(select(.value.channelName==$channelName and .value.channelZone==$channelZone))[].value.programAirings | to_entries | map("\(.value.airing.playDate)=\(.value.program.title)")[]' <<< "$hbous_yesterday_schedule")

                min_sys_time=${program_sys_time:-$sys_time}

                while IFS="=" read -r program_time program_title
                do
                    program_time=${program_time#\"}
                    program_title=${program_title%\"}
                    program_sys_time=$(date -d "$program_time" +%s)
                    if [ "$program_sys_time" -le "$max_sys_time" ] && [ "$program_sys_time" -gt "$min_sys_time" ]
                    then
                        program_time=$(printf '%(%H:%M)T' "$program_sys_time")
                        [ -n "$schedule" ] && schedule="$schedule,"
                        schedule=$schedule'{
                            "title":"'"$program_title"'",
                            "time":"'"$program_time"'",
                            "sys_time":"'"$program_sys_time"'"
                        }'
                    fi
                done < <($JQ_FILE --arg channelName "$chnl_name" --arg channelZone "$chnl_zone" '.channels | to_entries | map(select(.value.channelName==$channelName and .value.channelZone==$channelZone))[].value.programAirings | to_entries | map("\(.value.airing.playDate)=\(.value.program.title)")[]' <<< "$hbous_today_schedule")

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "hbous_$chnl_id" "[$schedule]"
                fi
            done
        ;;
        "ontvtonight")
            printf -v today '%(%Y-%m-%d)T'
            sys_time=$(date -d $today +%s)
            min_sys_time=$((sys_time-7200))
            max_sys_time=$((sys_time+86400))
            yesterday=$(printf '%(%Y-%m-%d)T' $((sys_time - 86400)))

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "us_abc" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "abc@abc@69048344@-04:00"
                "cbs@cbs@69048345@-04:00"
                "nbc@nbc@69048423@-04:00"
                "fox@fox@69048367@-04:00"
                "msnbc@msnbc@69023101@-04:00"
                "amc@amc-east@69047124@-04:00"
                "nickjr@nick-jr@69047681@-04:00"
                "universalkids@universal-kids@69027178@-04:00"
                "disneyjr@disney-junior-hdtv-east@69044944@-04:00"
                "mtvlive@mtv-live-hdtv@69027734@-04:00"
                "mtvlivehd@mtv-live-hdtv@69038784@+00:00"
                "mtvdance@mtv-dance@69036268@+02:00"
                "comedycentral@comedy-central-east@69036536@-04:00" )

            for chnl in "${chnls[@]}" ; do
                IFS="@" read -r chnl_id chnl_name chnl_no chnl_zone <<< "$chnl"

                if [ -n "${3:-}" ] && [ "${3:-}" != "$chnl_id" ]
                then
                    continue
                fi

                schedule=""
                start=0

                if [ "$chnl_id" == "mtvdance" ] 
                then
                    uk="uk/"
                else
                    uk=""
                fi

                while IFS= read -r line
                do
                    if [[ $line == *"<tbody>"* ]] 
                    then
                        start=1
                    elif [ "$start" -eq 1 ] && [[ $line == *"<h5"* ]] && [[ $line == *"</h5>"* ]]
                    then
                        line=${line#*>}
                        program_time=${line%<*}
                        new_program_time=${program_time% *}
                        hour=${new_program_time%:*}
                        if [ "${program_time#* }" == "pm" ] && [ "$hour" -lt 12 ]
                        then
                            hour=$((hour+12))
                            new_program_time="$hour:${new_program_time#*:}"
                        elif [ "${program_time#* }" == "am" ] && [ "$hour" -eq 12 ]
                        then
                            new_program_time="00:${new_program_time#*:}"
                        fi
                    elif [ "$start" -eq 1 ] && [[ $line == *"</a></h5>"* ]] 
                    then
                        line=${line%%<\/a>*}
                        lead=${line%%[^[:blank:]]*}
                        program_title=${line#${lead}}
                        program_title=${program_title//amp;/}
                        program_title=${program_title//&#039;/\'}
                        program_sys_time=$(date -d "${yesterday}T$new_program_time$chnl_zone" +%s)
                        if [ "$program_sys_time" -ge "$min_sys_time" ] 
                        then
                            program_time=$(printf '%(%H:%M)T' "$program_sys_time")
                            [ -n "$schedule" ] && schedule="$schedule,"
                            schedule=$schedule'{
                                "title":"'"$program_title"'",
                                "time":"'"$program_time"'",
                                "sys_time":"'"$program_sys_time"'"
                            }'
                        fi
                    elif [ "$start" -eq 1 ] && [[ $line == *"</tbody>"* ]] 
                    then
                        break
                    fi
                done < <(wget --no-check-certificate "https://www.ontvtonight.com/${uk}guide/listings/channel/$chnl_no/$chnl_name.html?dt=$yesterday" -qO-)

                while IFS= read -r line
                do
                    if [[ $line == *"<tbody>"* ]] 
                    then
                        start=1
                    elif [ "$start" -eq 1 ] && [[ $line == *"<h5"* ]] && [[ $line == *"</h5>"* ]] 
                    then
                        line=${line#*>}
                        program_time=${line%<*}
                        new_program_time=${program_time% *}
                        hour=${new_program_time%:*}
                        if [ "${program_time#* }" == "pm" ] && [ "$hour" -lt 12 ]
                        then
                            hour=$((hour+12))
                            new_program_time="$hour:${new_program_time#*:}"
                        elif [ "${program_time#* }" == "am" ] && [ "$hour" -eq 12 ]
                        then
                            new_program_time="00:${new_program_time#*:}"
                        fi
                    elif [ "$start" -eq 1 ] && [[ $line == *"</a></h5>"* ]] 
                    then
                        line=${line%%<\/a>*}
                        lead=${line%%[^[:blank:]]*}
                        program_title=${line#${lead}}
                        program_title=${program_title//amp;/}
                        program_title=${program_title//&#039;/\'}
                        program_sys_time=$(date -d "${today}T$new_program_time$chnl_zone" +%s)
                        if [ "$program_sys_time" -le "$max_sys_time" ] 
                        then
                            program_time=$(printf '%(%H:%M)T' "$program_sys_time")
                            [ -n "$schedule" ] && schedule="$schedule,"
                            schedule=$schedule'{
                                "title":"'"$program_title"'",
                                "time":"'"$program_time"'",
                                "sys_time":"'"$program_sys_time"'"
                            }'
                        fi
                    elif [ "$start" -eq 1 ] && [[ $line == *"</tbody>"* ]] 
                    then
                        break
                    fi
                done < <(wget --no-check-certificate "https://www.ontvtonight.com/${uk}guide/listings/channel/$chnl_no/$chnl_name.html?dt=$today" -qO-)

                if [ "$chnl_id" != "mtvlivehd" ] && [ "$chnl_id" != "mtvdance" ]
                then
                    chnl_id="us_$chnl_id"
                fi

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "$chnl_id" "[$schedule]"
                fi
            done
        ;;
        "disneyjr")
            printf -v today '%(%Y%m%d)T'
            SCHEDULE_LINK="https://disney.com.tw/_schedule/full/$today/8/%2Fepg"

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "$2" > "$SCHEDULE_JSON"
            fi

            schedule=""
            while IFS= read -r program 
            do
                program_title=${program#*show_title: }
                program_title=${program_title%%, time: *}
                program_time=${program#*, time: }
                program_time=${program_time%%, iso8601_utc_time: *}
                program_sys_time=${program#*, iso8601_utc_time: }
                program_sys_time=${program_sys_time%\"}
                program_sys_time=$(date -d "$program_sys_time" +%s)

                [ -n "$schedule" ] && schedule="$schedule,"
                schedule=$schedule'{
                    "title":"'"$program_title"'",
                    "time":"'"$program_time"'",
                    "sys_time":"'"$program_sys_time"'"
                }'
            done < <($JQ_FILE '.schedule | to_entries | map(.value.schedule_items[]) | to_entries | map("show_title: \(.value.show_title), time: \(.value.time), iso8601_utc_time: \(.value.iso8601_utc_time)")[]' <<< $(wget --no-check-certificate "$SCHEDULE_LINK" -qO-))

            if [ -z "$schedule" ] 
            then
                Println "$error\nnot found\n"
            else
                JQ replace "$SCHEDULE_JSON" "$2" "[$schedule]"
            fi
        ;;
        "foxmovies")
            printf -v today '%(%Y-%-m-%-d)T'
            SCHEDULE_LINK="https://www.fng.tw/foxmovies/program.php?go=$today"

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "$2" > "$SCHEDULE_JSON"
            fi

            schedule=""
            while IFS= read -r line
            do
                if [[ $line == *"<td>"* ]] 
                then
                    line=${line#*<td>}
                    line=${line%%<\/td>*}

                    if [[ $line == *"<br>"* ]]  
                    then
                        line=${line%% <br>*}
                        line=${line//\"/}
                        line=${line//\'/}
                        line=${line//\\/\'}
                        sys_time=$(date -d "$today $time" +%s)
                        [ -n "$schedule" ] && schedule="$schedule,"
                        schedule=$schedule'{
                            "title":"'"$line"'",
                            "time":"'"$time"'",
                            "sys_time":"'"$sys_time"'"
                        }'
                    else
                        time=${line#* }
                    fi
                fi
            done < <(wget --no-check-certificate "$SCHEDULE_LINK" -qO-)

            if [ -z "$schedule" ] 
            then
                Println "$error\nnot found\n"
            else
                JQ replace "$SCHEDULE_JSON" "$2" "[$schedule]"
            fi
        ;;
        "amlh")
            printf -v today '%(%Y-%-m-%-d)T'
            timestamp=$(date -d $today +%s)

            TODAY_SCHEDULE_LINK="http://wap.lotustv.cc/wap.php/Sub/program/d/$timestamp"
            YESTERDAY_SCHEDULE_LINK="http://wap.lotustv.cc/wap.php/Sub/program/d/$((timestamp-86400))"

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "$2" > "$SCHEDULE_JSON"
            fi

            found=0
            schedule=""
            replace=""

            while IFS= read -r line
            do
                if [[ $line == *"program_list"* ]] 
                then
                    found=1
                elif [ "$found" -eq 1 ] && [[ $line == *"<li>"* ]] 
                then
                    line=${line#*<em>}
                    time=${line%%<\/em>*}
                    while [ -n "$time" ] 
                    do
                        time=${time:0:5}
                        line=${line#*<span>}
                        if [ "${flag:-0}" -gt 0 ] && [ "${time:0:1}" -eq 0 ]
                        then
                            title=${line%%<\/span>*}
                            [ -z "$replace" ] && replace="${title:4:1}"
                            title="${title//$replace/ }"
                            if [ "${title:0:4}" == "經典影院" ] 
                            then
                                title=${title:5}
                            fi
                            sys_time=$(date -d "$today $time" +%s)
                            [ -n "$schedule" ] && schedule="$schedule,"
                            schedule=$schedule'{
                                "title":"'"$title"'",
                                "time":"'"$time"'",
                                "sys_time":"'"$sys_time"'"
                            }'
                        else
                            flag=${time:0:1}
                        fi
                        if [[ $line == *"<em>"* ]] 
                        then
                            line=${line#*<em>}
                            time=${line%%<\/em>*}
                        else
                            break
                        fi
                    done
                    break
                fi
            done < <(wget --no-check-certificate "$YESTERDAY_SCHEDULE_LINK" -qO-)

            flag=0
            found=0

            while IFS= read -r line
            do
                if [[ $line == *"program_list"* ]] 
                then
                    found=1
                elif [ "$found" -eq 1 ] && [[ $line == *"<li>"* ]] 
                then
                    line=${line#*<em>}
                    time=${line%%<\/em>*}
                    while [ -n "$time" ] 
                    do
                        time=${time:0:5}
                        line=${line#*<span>}
                        if [ ! "$flag" -gt "${time:0:1}" ]
                        then
                            flag=${time:0:1}
                            title=${line%%<\/span>*}
                            title="${title//$replace/ }"
                            if [ "${title:0:4}" == "經典影院" ] 
                            then
                                title=${title:5}
                            fi
                            sys_time=$(date -d "$today $time" +%s)
                            [ -n "$schedule" ] && schedule="$schedule,"
                            schedule=$schedule'{
                                "title":"'"$title"'",
                                "time":"'"$time"'",
                                "sys_time":"'"$sys_time"'"
                            }'
                        else
                            break 2
                        fi
                        line=${line#*<em>}
                        time=${line%%<\/em>*}
                    done
                    break
                fi
            done < <(wget --no-check-certificate "$TODAY_SCHEDULE_LINK" -qO-)

            if [ -z "$schedule" ] 
            then
                Println "$error\nnot found\n"
            else
                JQ replace "$SCHEDULE_JSON" "$2" "[$schedule]"
            fi
        ;;
        "tvbhk")
            printf -v today '%(%Y-%m-%d)T'
            sys_time=$(date -d $today +%s)
            max_sys_time=$((sys_time+86400))
            yesterday=$(printf '%(%Y-%m-%d)T' $((sys_time - 86400)))

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "tvbhk_pearl" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "pearl:P"
                "jade:J"
                "j2:B"
                "news:C"
                "finance:A"
                "xinghe:X"
                "classic:E"
                "koreandrama:K"
                "japanesedrama:D"
                "chinesedrama:U"
                "asianvariety:V"
                "food:L"
                "classicmovies:W" )

            for chnl in "${chnls[@]}" ; do
                chnl_name=${chnl%:*}
                chnl_code=${chnl#*:}

                if [ -n "${3:-}" ] && [ "$3" != "$chnl_name" ] 
                then
                    continue
                fi

                schedule=""

                while IFS= read -r line
                do
                    if [[ $line == *"<li"* ]] 
                    then
                        while [[ $line == *"<li"* ]] 
                        do
                            line=${line#*time=\"}
                            program_sys_time=${line%%\"*}
                            if [ "$program_sys_time" -ge "$sys_time" ]
                            then
                                line=${line#*<span class=\"time\">}
                                program_time=${line%%</span>*}
                                line=${line#*<p class=\"ftit\">}
                                if [ "${line:0:7}" == "<a href" ] 
                                then
                                    line=${line#*>}
                                fi
                                program_title=${line%%</p>*}
                                program_title=${program_title%% <cite*}
                                program_title=${program_title%%</a>*}
                                program_title=${program_title%%<em *}
                                program_title=${program_title//&nbsp;/ }
                                [ -n "$schedule" ] && schedule="$schedule,"
                                schedule=$schedule'{
                                    "title":"'"$program_title"'",
                                    "time":"'"$program_time"'",
                                    "sys_time":"'"$program_sys_time"'"
                                }'
                            fi
                        done
                        break
                    fi
                done < <(wget --no-check-certificate "https://programme.tvb.com/ajax.php?action=channellist&code=$chnl_code&date=$yesterday" -qO-)

                while IFS= read -r line
                do
                    if [[ $line == *"<li"* ]] 
                    then
                        while [[ $line == *"<li"* ]] 
                        do
                            line=${line#*time=\"}
                            program_sys_time=${line%%\"*}
                            if [ "$program_sys_time" -ge "$sys_time" ] && [ "$program_sys_time" -le "$max_sys_time" ]
                            then
                                line=${line#*<span class=\"time\">}
                                program_time=${line%%</span>*}
                                line=${line#*<p class=\"ftit\">}
                                if [ "${line:0:7}" == "<a href" ] 
                                then
                                    line=${line#*>}
                                fi
                                program_title=${line%%</p>*}
                                program_title=${program_title%% <cite*}
                                program_title=${program_title%%</a>*}
                                program_title=${program_title%%<em *}
                                program_title=${program_title//&nbsp;/ }
                                [ -n "$schedule" ] && schedule="$schedule,"
                                schedule=$schedule'{
                                    "title":"'"$program_title"'",
                                    "time":"'"$program_time"'",
                                    "sys_time":"'"$program_sys_time"'"
                                }'
                            fi
                        done
                        break
                    fi
                done < <(wget --no-check-certificate "https://programme.tvb.com/ajax.php?action=channellist&code=$chnl_code&date=$today" -qO-)

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "tvbhk_$chnl_name" "[$schedule]"
                fi
            done
        ;;
        "tvbhd")
            if [[ ! -x $(command -v pdf2htmlEX) ]] 
            then
                Println "需要先安装 pdf2htmlEX，因为是编译 pdf2htmlEX，耗时会很长，是否继续？[y/N]"
                read -p "(默认: N): " pdf2html_install_yn
                pdf2html_install_yn=${pdf2html_install_yn:-N}
                if [[ $pdf2html_install_yn == [Yy] ]] 
                then
                    InstallPdf2html
                    Println "$info pdf2htmlEX 安装完成\n"
                    if ! pdf2htmlEX -v > /dev/null 2>&1
                    then
                        Println "$info 请先输入 source /etc/profile 以启用 pdf2htmlEX\n" && exit 1
                    fi
                else
                    Println "已取消...\n" && exit 1
                fi
            fi

            wget --timeout=10 --tries=3 --no-check-certificate "https://schedule.tvbusa.com/current/tvb_hd.pdf" -qO "$IPTV_ROOT/tvb_hd.pdf"
            cd "$IPTV_ROOT"
            pdf2htmlEX --zoom 1.3 "./tvb_hd.pdf"

            printf -v today '%(%Y-%m-%d)T'
            sys_time=$(date -d $today +%s)
            yesterday=$(printf '%(%Y-%m-%d)T' $((sys_time - 86400)))

            weekday_program_title=()
            weekday_program_time=()
            saturday_program_title=()
            saturday_program_time=()
            sunday_program_title=()
            sunday_program_time=()

            while IFS= read -r line 
            do
                if [[ $line == *"節目表"* ]] 
                then
                    line=${line#*"星期日"}
                    line=${line#*"日期"}
                    line=${line//"<span class=\"_ _28\"></span>"/}
                    line=${line//"<div class=\"t m0 x10 ha ya ff2 fs3 fc0 sc0 ls0 ws0\">11:30</div></div>"/}
                    old_program_time=""
                    skips=(
                        "4:saturday sunday"
                        "7:saturday"
                        "9:saturday sunday"
                        "10:weekday"
                        "11:weekday saturday"
                        "12:sunday"
                        "13:sunday"
                        "16:saturday sunday"
                        "17:weekday"
                        "18:saturday"
                        "19:sunday"
                        "20:saturday"
                        "22:saturday sunday"
                        "23:sunday"
                        "24:weekday"
                        "25:weekday"
                        "26:sunday"
                        "27:saturday sunday"
                        "28:saturday sunday"
                        "29:weekday"
                        "30:saturday sunday"
                        "32:saturday sunday"
                        "33:saturday"
                        "34:sunday"
                        "36:weekday"
                        "37:sunday"
                        "38:saturday sunday"
                        "39:sunday"
                        "40:saturday sunday"
                        "41:sunday"
                        "43:weekday"
                        "44:weekday"
                        "47:sunday"
                        "48:weekday saturday"
                        "49:sunday"
                        "50:weekday"
                        "51:saturday"
                        "52:sunday"
                        "53:saturday"
                        "54:sunday"
                        "55:saturday"
                        "56:saturday sunday"
                        "57:saturday sunday"
                        "58:saturday sunday"
                        "59:saturday sunday"
                        "60:saturday sunday"
                    )
                    loop=1
                    count=0
                    day="weekday"
                    while true 
                    do
                        class=${line%%\">*}
                        class=${class#*<div class=\"}
                        line=${line#*>}
                        content=${line%%<*}

                        case $content in
                            ""|" "|"AM"|"PM"|"東岸"|"西岸"|"星期日"|"星期一"|"星期二至六"|"日期"|"Next Day") continue
                            ;;
                            *"夏令時間"*) continue
                            ;;
                            *"將時鐘"*) continue
                            ;;
                            "高清台") 
                                if [[ -n ${program_title:-} ]] 
                                then
                                    if [[ -n ${program_start_date:-} ]] 
                                    then
                                        program_title="$program_title $program_start_date"
                                    fi
                                    program_title=${program_title//amp;/}
                                    program_title=${program_title//&#039;/\'}
                                    if [ "$day" == "weekday" ] 
                                    then
                                        if [[ -n $old_program_time ]] 
                                        then
                                            weekday_program_title+=("$program_title")
                                            weekday_program_time+=("$old_program_time")
                                        else
                                            index=${#weekday_program_title[@]}
                                            index=$((index-1))
                                            weekday_program_title[index]="${weekday_program_title[index]} $program_title"
                                        fi
                                    elif [ "$day" == "saturday" ] 
                                    then
                                        if [[ -n $old_program_time ]] 
                                        then
                                            saturday_program_title+=("$program_title")
                                            saturday_program_time+=("$old_program_time")
                                        else
                                            index=${#saturday_program_title[@]}
                                            index=$((index-1))
                                            saturday_program_title[index]="${saturday_program_title[index]} $program_title"
                                        fi
                                    elif [ "$day" == "sunday" ] 
                                    then
                                        if [[ -n $old_program_time ]] 
                                        then
                                            sunday_program_title+=("$program_title")
                                            sunday_program_time+=("$old_program_time")
                                        else
                                            index=${#sunday_program_title[@]}
                                            index=$((index-1))
                                            sunday_program_title[index]="${sunday_program_title[index]} $program_title"
                                        fi
                                    fi
                                    program_title=""
                                    old_program_time=""
                                    program_sys_time=""
                                    program_start_date=""
                                fi
                                break
                            ;;
                            *) 
                                if [[ ${content:1:1} == "/" ]] && [[ ! ${content:0:1} == *[!0-9]* ]] && [[ ! ${content:2} == *[!0-9]* ]] 
                                then
                                    program_start_date=$content
                                elif [[ ${content:2:1} == "/" ]] && [[ ! ${content:0:2} == *[!0-9]* ]] && [[ ! ${content:3} == *[!0-9]* ]] 
                                then
                                    program_start_date=$content
                                elif [[ ${content:1:1} == ":" ]] 
                                then
                                    if [[ ! ${content:0:1} == *[!0-9]* ]] && [[ ! ${content:2} == *[!0-9]* ]] 
                                    then
                                        [ -n "${program_time:-}" ] && program_time=""
                                        if [[ -z ${program_time_east:-} ]] 
                                        then
                                            program_time_east=$content
                                        else
                                            program_time=$content
                                            program_time_east=""
                                        fi
                                    fi
                                elif [[ ${content:2:1} == ":" ]] 
                                then
                                    if [[ ! ${content:0:2} == *[!0-9]* ]] && [[ ! ${content:3} == *[!0-9]* ]] 
                                    then
                                        [ -n "${program_time:-}" ] && program_time=""
                                        if [[ -z ${program_time_east:-} ]] 
                                        then
                                            program_time_east=$content
                                        else
                                            program_time=$content
                                            program_time_east=""
                                        fi
                                    fi
                                else
                                    old_day=$day

                                    if [ "$count" -gt 0 ] 
                                    then
                                        if [ "$old_day" == "sunday" ] 
                                        then
                                            day="weekday"
                                        elif [ "$old_day" == "weekday" ] 
                                        then
                                            day="saturday"
                                        elif [ "$old_day" == "saturday" ] 
                                        then
                                            day="sunday"
                                        fi
                                    fi

                                    count=$((count+1))
                                    if [[ $((count % 3)) -eq 0 ]] 
                                    then
                                        loop=$((count/3))
                                    else
                                        loop=$((count/3 + 1))
                                    fi

                                    redo=1
                                    while [ "$redo" -eq 1 ] 
                                    do
                                        redo=0
                                        for skip in "${skips[@]}"
                                        do
                                            if [ "${skip%:*}" == "$loop" ] 
                                            then
                                                redo=1
                                                IFS=" " read -ra days <<< "${skip#*:}"
                                                for ele in "${days[@]}"
                                                do
                                                    if [ "$ele" == "$day" ] 
                                                    then
                                                        count=$((count+1))
                                                        if [ "$day" == "sunday" ] 
                                                        then
                                                            day="weekday"
                                                        elif [ "$day" == "weekday" ] 
                                                        then
                                                            day="saturday"
                                                        elif [ "$day" == "saturday" ] 
                                                        then
                                                            day="sunday"
                                                        fi
                                                    fi
                                                done
                                                if [[ $((count % 3)) -eq 0 ]] 
                                                then
                                                    new_loop=$((count/3))
                                                else
                                                    new_loop=$((count/3 + 1))
                                                fi
                                                if [ "$new_loop" == "$loop" ] 
                                                then
                                                    redo=0
                                                else
                                                    loop=$new_loop
                                                fi
                                                break
                                            fi
                                        done
                                    done

                                    case $((count%3)) in
                                        0) day="sunday"
                                        ;;
                                        1) day="weekday"
                                        ;;
                                        2) day="saturday"
                                        ;;
                                    esac

                                    if [[ -n ${program_title:-} ]] 
                                    then
                                        if [[ -n ${program_start_date:-} ]] 
                                        then
                                            program_title="$program_title $program_start_date"
                                        fi
                                        program_title=${program_title//amp;/}
                                        program_title=${program_title//&#039;/\'}
                                        if [ "$old_day" == "weekday" ] 
                                        then
                                            if [[ -n $old_program_time ]] 
                                            then
                                                weekday_program_title+=("$program_title")
                                                weekday_program_time+=("$old_program_time")
                                            else
                                                index=${#weekday_program_title[@]}
                                                index=$((index-1))
                                                weekday_program_title[index]="${weekday_program_title[index]} $program_title"
                                            fi
                                        elif [ "$old_day" == "saturday" ] 
                                        then
                                            if [[ -n $old_program_time ]] 
                                            then
                                                saturday_program_title+=("$program_title")
                                                saturday_program_time+=("$old_program_time")
                                            else
                                                index=${#saturday_program_title[@]}
                                                index=$((index-1))
                                                saturday_program_title[index]="${saturday_program_title[index]} $program_title"
                                            fi
                                        elif [ "$old_day" == "sunday" ] 
                                        then
                                            if [[ -n $old_program_time ]] 
                                            then
                                                sunday_program_title+=("$program_title")
                                                sunday_program_time+=("$old_program_time")
                                            else
                                                index=${#sunday_program_title[@]}
                                                index=$((index-1))
                                                sunday_program_title[index]="${sunday_program_title[index]} $program_title"
                                            fi
                                        fi
                                        program_title=""
                                        old_program_time=""
                                        program_start_date=""
                                    fi

                                    if [ -n "${program_time_east:-}" ] 
                                    then
                                        program_time=$program_time_east
                                        program_time_east=""
                                    fi

                                    program_title=$content

                                    if [ -n "$program_time" ] 
                                    then
                                        old_program_time=$program_time
                                        program_time=""
                                    fi
                                fi
                            ;;
                        esac
                    done
                    break
                fi
            done < "./tvb_hd.html"
            weekday=$(printf '%(%u)T')
            if [ "$weekday" -eq 1 ] 
            then
                p_title=("${sunday_program_title[@]}")
                p_time=("${sunday_program_time[@]}")
            elif [ "$weekday" -eq 0 ] 
            then
                p_title=("${saturday_program_title[@]}")
                p_time=("${saturday_program_time[@]}")
            else
                p_title=("${weekday_program_title[@]}")
                p_time=("${weekday_program_time[@]}")
            fi

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "tvbhd" > "$SCHEDULE_JSON"
            fi

            schedule=""
            change=0
            date=$yesterday
            for((i=0;i<${#p_time[@]};i++));
            do
                [ -n "${program_time:-}" ] && program_time_old=$program_time

                program_time=${p_time[i]}

                if [ -n "${program_time_old:-}" ] &&[ "${program_time%:*}" -lt "${program_time_old%:*}" ]
                then
                    change=$((change+1))
                fi

                if [ "$change" -eq 1 ] 
                then
                    hour=${program_time%:*}
                    hour=$((hour+12))
                    if [ "$hour" -eq 24 ] 
                    then
                        hour="0"
                        date=$today
                    fi
                    new_program_time="$hour:${program_time#*:}"
                elif [ "$change" -eq 2 ] 
                then
                    date=$today
                    new_program_time=$program_time
                else
                    new_program_time=$program_time
                fi

                if [[ ${new_program_time:1:1} == ":" ]] 
                then
                    new_program_time="0$new_program_time"
                else
                    new_program_time=$new_program_time
                fi

                program_sys_time=$(date -d "${date}T$new_program_time-08:00" +%s)
                new_program_time=$(printf '%(%H:%M)T' "$program_sys_time")

                program_title=${p_title[i]}

                [ -n "$schedule" ] && schedule="$schedule,"
                schedule=$schedule'{
                    "title":"'"$program_title"'",
                    "time":"'"$new_program_time"'",
                    "sys_time":"'"$program_sys_time"'"
                }'
            done

            if [ -n "$schedule" ] 
            then
                JQ replace "$SCHEDULE_JSON" "tvbhd" "[$schedule]"
            fi
        ;;
        "singteltv")
            printf -v today '%(%Y%m%d)T'

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "my_tvbjade" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "ch5:2"
                "ch8:3"
                "chu:7"
                "kidschannel:243"
                "ele:501"
                "jiale:502"
                "starchinese:507"
                "tvbjade:511"
                "nowjelli:512"
                "one:513"
                "xingkong:516"
                "xinghe:517"
                "tvn:518"
                "gem:519"
                "ettvasia:521"
                "oh!k:525"
                "entertainment:531"
                "cbo:532"
                "foodandhealth:533"
                "cctventertainment:534"
                "dragontvintl:535"
                "channelvchina:547"
                "mtvchina:550"
                "cctv4:555"
                "ctiasia:557"
                "ettvnews:561"
                "scmhd:571"
                "scmlegend:573"
                "ccm:580"
                "celestialmovies:585" )

            schedule_today=$(wget "http://singteltv.com.sg/epg/channel$today.html" -qO-)

            for chnl in "${chnls[@]}" ; do
                chnl_name=${chnl%:*}
                chnl_id=${chnl#*:}

                if [ -n "${3:-}" ] && [ "$3" != "$chnl_name" ]
                then
                    continue
                fi

                schedule=""

                line=$(grep -o -P '(?<=ch-'"$chnl_id"'").*?(?=</ul>)' <<< "$schedule_today")
                while [[ $line == *"li-time"* ]] 
                do
                    line=${line#*<span class=\"li-time\">}
                    program_time=${line%%<\/span>*}
                    line=${line#*<span class=\"li-title\">}
                    program_title=${line%%<\/span>*}
                    program_title=${program_title%% / *}
                    program_title=${program_title//\"/\\\"}
                    program_sys_time=$(date -d "$today $program_time" +%s)
                    [ -n "$schedule" ] && schedule="$schedule,"
                    schedule=$schedule'{
                        "title":"'"$program_title"'",
                        "time":"'"$program_time"'",
                        "sys_time":"'"$program_sys_time"'"
                    }'
                done

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "my_$chnl_name" "[$schedule]"
                fi
            done
        ;;
        "cntv")
            printf -v today '%(%Y%m%d)T'

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "cctv13" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "cctv1"
                "cctv2"
                "cctv3"
                "cctv4"
                "cctv5"
                "cctv6"
                "cctv7"
                "cctv8"
                "cctvjilu"
                "cctv10"
                "cctv11"
                "cctv12"
                "cctv13"
                "cctvchild"
                "cctv15"
                "cctv5plus"
                "cctv17"
                "cctveurope"
                "cctvamerica" )

            for chnl in "${chnls[@]}" ; do

                if [ -n "${3:-}" ] && [ "$3" != "$chnl" ]
                then
                    continue
                fi

                schedule=""
                schedule_today=$(wget "http://api.cntv.cn/epg/getEpgInfoByChannelNew?c=$chnl&serviceId=tvcctv&d=$today" -qO-)

                while IFS=" = " read -r program_title program_sys_time program_time
                do
                    program_title=${program_title#\"}
                    program_time=${program_time%\"}
                    [ -n "$schedule" ] && schedule="$schedule,"
                    schedule=$schedule'{
                        "title":"'"$program_title"'",
                        "time":"'"$program_time"'",
                        "sys_time":"'"$program_sys_time"'"
                    }'
                done < <($JQ_FILE ".data.$chnl.list|to_entries|map(\"\(.value.title) = \(.value.startTime) = \(.value.showTime)\")|.[]" <<< "$schedule_today")

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "$chnl" "[$schedule]"
                fi
            done
        ;;
        "tvbs")
            printf -v today '%(%Y-%m-%d)T'

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "tvbs" > "$SCHEDULE_JSON"
            fi

            chnls=( tvbsxw tvbshl tvbs tvbsjc tvbsyz )
            chn_order=0
            lang=2

            for chnl in "${chnls[@]}"
            do
                chn_order=$((chn_order+1))
                if [ -n "${3:-}" ] && [ "$3" != "$chnl" ]
                then
                    continue
                fi

                schedule=""
                schedule_today=$(wget --no-check-certificate "https://tvbsapp.tvbs.com.tw/pg_api/pg_list/$chn_order/$today/1/$lang" -qO-)

                while IFS="=" read -r program_time program_title
                do
                    program_time=${program_time#\"}
                    program_title=${program_title%\"}
                    program_sys_time=$(date -d "$today $program_time" +%s)
                    [ -n "$schedule" ] && schedule="$schedule,"
                    schedule=$schedule'{
                        "title":"'"$program_title"'",
                        "time":"'"$program_time"'",
                        "sys_time":"'"$program_sys_time"'"
                    }'
                done < <($JQ_FILE '.data|to_entries|map(select(.value.date=="'"$today"'"))|.[].value.data|to_entries|map("\(.value.pg_hour)=\(.value.pg_name)")|.[]' <<< "$schedule_today")

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "$chnl" "[$schedule]"
                fi
            done
        ;;
        "astro")
            printf -v today '%(%Y-%m-%d)T'

            if [ ! -s "$SCHEDULE_JSON" ] 
            then
                printf '{"%s":[]}' "iqiyi" > "$SCHEDULE_JSON"
            fi

            chnls=(
                "iqiyi:355" )

            for chnl in "${chnls[@]}"
            do
                chnl_name=${chnl%:*}
                chnl_id=${chnl#*:}

                if [ -n "${3:-}" ] && [ "$3" != "$chnl_name" ]
                then
                    continue
                fi

                schedule=""
                schedule_today=$(wget --no-check-certificate "https://contenthub-api.eco.astro.com.my/channel/$chnl_id.json" -qO-)

                while IFS="=" read -r program_time program_title
                do
                    program_time=${program_time#\"}
                    program_sys_time=$(date -d "$program_time" +%s)
                    program_time=${program_time#* }
                    program_time=${program_time:0:5}
                    program_title=${program_title%\"}
                    [ -n "$schedule" ] && schedule="$schedule,"
                    schedule=$schedule'{
                        "title":"'"$program_title"'",
                        "time":"'"$program_time"'",
                        "sys_time":"'"$program_sys_time"'"
                    }'
                done < <($JQ_FILE '.response.schedule["'"$today"'"]|to_entries|map("\(.value.datetime)=\(.value.title)")|.[]' <<< "$schedule_today")

                if [ -n "$schedule" ] 
                then
                    JQ replace "$SCHEDULE_JSON" "$chnl_name" "[$schedule]"
                fi
            done
        ;;
        *) 
            found=0
            for chnl in "${chnls[@]}" ; do
                chnl_id=${chnl%%:*}
                if [ "$chnl_id" == "$2" ] 
                then
                    found=1
                    GenerateSchedule "$2"
                    break
                fi
            done

            if [ "$found" -eq 0 ] 
            then
                Println "not found: $2\ntrying NioTV...\n"
                for chnl_niotv in "${chnls_niotv[@]}" ; do
                    chnl_niotv_id=${chnl_niotv%%:*}
                    if [ "$chnl_niotv_id" == "$2" ] 
                    then
                        found=1
                        chnl_niotv_num=${chnl_niotv#*:}
                        GenerateScheduleNiotv "$chnl_niotv_num"
                        break
                    fi
                done
            fi

            if [ "$found" -eq 0 ] 
            then
                Println "NioTV not found: $2\ntrying NowTV...\n"
                for chnl_nowtv in "${chnls_nowtv[@]}" ; do
                    chnl_nowtv_id=${chnl_nowtv%%:*}
                    if [ "$chnl_nowtv_id" == "$2" ] 
                    then
                        found=1
                        chnl_nowtv_num=${chnl_nowtv#*:}
                        GenerateScheduleNowtv "$chnl_nowtv_num"
                        break
                    fi
                done
            fi

            [ "$found" -eq 0 ] && Println "no support yet ~"
        ;;
    esac
}

TsIsUnique()
{
    not_unique=$(wget --no-check-certificate "${ts_array[unique_url]}?accounttype=${ts_array[acc_type_reg]}&username=$account" -qO- | $JQ_FILE '.ret')
    if [ "$not_unique" != 0 ] 
    then
        Println "$error 用户名已存在,请重新输入！"
    fi
}

TsImg()
{
    IMG_FILE="$IPTV_ROOT/ts_yzm.jpg"
    if [ -n "${ts_array[refresh_token_url]:-}" ] 
    then
        deviceno=$(< /proc/sys/kernel/random/uuid)
        str=$(printf '%s' "$deviceno" | md5sum)
        str=${str%% *}
        str=${str:7:1}
        deviceno="$deviceno$str"
        declare -A token_array
        while IFS="=" read -r key value
        do
            token_array[$key]="$value"
        done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(curl -X POST -s --data '{"role":"guest","deviceno":"'"$deviceno"'","deviceType":"yuj"}' "${ts_array[token_url]}"))

        if [ "${token_array[ret]}" -eq 0 ] 
        then
            declare -A refresh_token_array
            while IFS="=" read -r key value
            do
                refresh_token_array[$key]="$value"
            done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(curl -X POST -s --data '{"accessToken":"'"${token_array[accessToken]}"'","refreshToken":"'"${token_array[refreshToken]}"'"}' "${ts_array[refresh_token_url]}"))

            if [ "${refresh_token_array[ret]}" -eq 0 ] 
            then
                declare -A img_array
                while IFS="=" read -r key value
                do
                    img_array[$key]="$value"
                done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[img_url]}?accesstoken=${refresh_token_array[accessToken]}" -qO-))

                if [ "${img_array[ret]}" -eq 0 ] 
                then
                    picid=${img_array[picid]}
                    image=${img_array[image]}
                    refresh_img=0
                    base64 -d <<< "${image#*,}" > "$IMG_FILE"
                    /usr/local/bin/imgcat --half-height "$IMG_FILE"
                    rm -f "${IMG_FILE:-notfound}"
                    Println "$info 输入图片验证码："
                    read -p "(默认: 刷新验证码): " pincode
                    [ -z "$pincode" ] && refresh_img=1
                    return 0
                fi
            fi
        fi
    else
        declare -A token_array
        while IFS="=" read -r key value
        do
            token_array[$key]="$value"
        done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(curl -X POST -s --data '{"usagescen":1}' "${ts_array[token_url]}"))

        if [ "${token_array[ret]}" -eq 0 ] 
        then
            declare -A img_array
            while IFS="=" read -r key value
            do
                img_array[$key]="$value"
            done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[img_url]}?accesstoken=${token_array[access_token]}" -qO-))

            if [ "${img_array[ret]}" -eq 0 ] 
            then
                picid=${img_array[picid]}
                image=${img_array[image]}
                refresh_img=0
                base64 -d <<< "${image#*,}" > "$IMG_FILE"
                /usr/local/bin/imgcat --half-height "$IMG_FILE"
                rm -f "${IMG_FILE:-notfound}"
                Println "$info 输入图片验证码："
                read -p "(默认: 刷新验证码): " pincode
                [ -z "$pincode" ] && refresh_img=1
                return 0
            fi
        fi
    fi
}

TsRegister()
{
    if [ ! -e "/usr/local/bin/imgcat" ] &&  [ -n "${ts_array[img_url]:-}" ]
    then
        Println "$error 缺少 imgcat ,是否现在安装? [y/N]"
        read -p "(默认: 取消): " imgcat_yn
        imgcat_yn=${imgcat_yn:-N}
        if [[ $imgcat_yn == [Yy] ]] 
        then
            Progress &
            progress_pid=$!
            CheckRelease
            if [ "$release" == "rpm" ] 
            then
                yum -y install gcc gcc-c++ ncurses-devel >/dev/null 2>&1
                echo -n "...50%..."
            else
                apt-get -y update >/dev/null 2>&1
                apt-get -y install debconf-utils libncurses5-dev >/dev/null 2>&1
                echo '* libraries/restart-without-asking boolean true' | debconf-set-selections
                apt-get -y install software-properties-common pkg-config build-essential >/dev/null 2>&1
                echo -n "...50%..."
            fi

            cd ~

            if [ ! -e "./imgcat-master" ] 
            then
                wget --timeout=10 --tries=3 --no-check-certificate "$FFMPEG_MIRROR_LINK/imgcat.zip" -qO "imgcat.zip"
                unzip "imgcat.zip" >/dev/null 2>&1
            fi

            cd "./imgcat-master"
            autoconf >/dev/null 2>&1
            ./configure >/dev/null 2>&1
            make >/dev/null 2>&1
            make install >/dev/null 2>&1
            kill $progress_pid
            echo -n "...100%" && Println "$info imgcat 安装完成"
        else
            Println "已取消...\n" && exit 1
        fi
    fi
    not_unique=1
    while [ "$not_unique" != 0 ] 
    do
        Println "$info 输入账号："
        read -p "(默认: 取消): " account
        [ -z "$account" ] && Println "已取消...\n" && exit 1
        if [ -z "${ts_array[unique_url]:-}" ] 
        then
            not_unique=0
        else
            TsIsUnique
        fi
    done

    Println "$info 输入密码："
    read -p "(默认: 取消): " password
    [ -z "$password" ] && Println "已取消...\n" && exit 1

    if [ -n "${ts_array[img_url]:-}" ] 
    then
        refresh_img=1
        while [ "$refresh_img" != 0 ] 
        do
            TsImg
            [ "$refresh_img" -eq 1 ] && continue

            if [ -n "${ts_array[sms_url]:-}" ] 
            then
                declare -A sms_array
                while IFS="=" read -r key value
                do
                    sms_array[$key]="$value"
                done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[sms_url]}?pincode=$pincode&picid=$picid&verifytype=3&account=$account&accounttype=1" -qO-))

                if [ "${sms_array[ret]}" -eq 0 ] 
                then
                    Println "$info 短信已发送！"
                    Println "$info 输入短信验证码："
                    read -p "(默认: 取消): " smscode
                    [ -z "$smscode" ] && Println "已取消...\n" && exit 1

                    declare -A verify_array
                    while IFS="=" read -r key value
                    do
                        verify_array[$key]="$value"
                    done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[verify_url]}?verifycode=$smscode&verifytype=3&username=$account&account=$account" -qO-))

                    if [ "${verify_array[ret]}" -eq 0 ] 
                    then
                        deviceno=$(< /proc/sys/kernel/random/uuid)
                        str=$(printf '%s' "$deviceno" | md5sum)
                        str=${str%% *}
                        str=${str:7:1}
                        deviceno="$deviceno$str"
                        devicetype="yuj"
                        md5_password=$(printf '%s' "$password" | md5sum)
                        md5_password=${md5_password%% *}
                        printf -v timestamp '%(%s)T'
                        timestamp=$((timestamp * 1000))
                        signature="$account|$md5_password|$deviceno|$devicetype|$timestamp"
                        signature=$(printf '%s' "$signature" | md5sum)
                        signature=${signature%% *}
                        declare -A reg_array
                        while IFS="=" read -r key value
                        do
                            reg_array[$key]="$value"
                        done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(curl -X POST -s --data '{"account":"'"$account"'","deviceno":"'"$deviceno"'","devicetype":"'"$devicetype"'","code":"'"${verify_array[code]}"'","signature":"'"$signature"'","birthday":"1970-1-1","username":"'"$account"'","type":1,"timestamp":"'"$timestamp"'","pwd":"'"$md5_password"'","accounttype":"'"${ts_array[acc_type_reg]}"'"}' "${ts_array[reg_url]}"))

                        if [ "${reg_array[ret]}" -eq 0 ] 
                        then
                            Println "$info 注册成功！"
                            Println "$info 是否登录账号? [y/N]"
                            read -p "(默认: N): " login_yn
                            login_yn=${login_yn:-N}
                            if [[ $login_yn == [Yy] ]]
                            then
                                TsLogin
                            else
                                Println "已取消...\n" && exit 1
                            fi
                        else
                            Println "$error 注册失败！"
                            printf '%s\n' "${reg_array[@]}"
                        fi
                    fi

                else
                    if [ -z "${ts_array[unique_url]:-}" ] 
                    then
                        Println "$error 验证码或其它错误！请重新尝试！"
                    else
                        Println "$error 验证码错误！"
                    fi
                    #printf '%s\n' "${sms_array[@]}"
                    refresh_img=1
                fi
            fi
        done
    else
        md5_password=$(printf '%s' "$password" | md5sum)
        md5_password=${md5_password%% *}
        declare -A reg_array
        while IFS="=" read -r key value
        do
            reg_array[$key]="$value"
        done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[reg_url]}?username=$account&iconid=1&pwd=$md5_password&birthday=1970-1-1&type=1&accounttype=${ts_array[acc_type_reg]}" -qO-))

        if [ "${reg_array[ret]}" -eq 0 ] 
        then
            Println "$info 注册成功！"
            Println "$info 是否登录账号? [y/N]"
            read -p "(默认: N): " login_yn
            login_yn=${login_yn:-N}
            if [[ $login_yn == [Yy] ]]
            then
                TsLogin
            else
                Println "已取消...\n" && exit 1
            fi
        else
            Println "$error 发生错误"
            printf '%s\n' "${sms_array[@]}"
        fi
    fi
    
}

TsLogin()
{
    if [ -z "${account:-}" ] 
    then
        Println "$info 输入账号："
        read -p "(默认: 取消): " account
        [ -z "$account" ] && Println "已取消...\n" && exit 1
    fi

    if [ -z "${password:-}" ] 
    then
        Println "$info 输入密码："
        read -p "(默认: 取消): " password
        [ -z "$password" ] && Println "已取消...\n" && exit 1
    fi

    deviceno=$(< /proc/sys/kernel/random/uuid)
    str=$(printf '%s' "$deviceno" | md5sum)
    str=${str%% *}
    str=${str:7:1}
    deviceno="$deviceno$str"
    md5_password=$(printf '%s' "$password" | md5sum)
    md5_password=${md5_password%% *}

    if [ -z "${ts_array[img_url]:-}" ] 
    then
        TOKEN_LINK="${ts_array[login_url]}?deviceno=$deviceno&devicetype=3&accounttype=${ts_array[acc_type_login]:-2}&accesstoken=(null)&account=$account&pwd=$md5_password&isforce=1&businessplatform=1"
        token=$(wget --no-check-certificate "$TOKEN_LINK" -qO-)
    else
        printf -v timestamp '%(%s)T'
        timestamp=$((timestamp * 1000))
        signature="$deviceno|yuj|${ts_array[acc_type_login]}|$account|$timestamp"
        signature=$(printf '%s' "$signature" | md5sum)
        signature=${signature%% *}
        if [[ ${ts_array[extend_info]} == "{"*"}" ]] 
        then
            token=$(curl -X POST -s --data '{"account":"'"$account"'","deviceno":"'"$deviceno"'","pwd":"'"$md5_password"'","devicetype":"yuj","businessplatform":1,"signature":"'"$signature"'","isforce":1,"extendinfo":'"${ts_array[extend_info]}"',"timestamp":"'"$timestamp"'","accounttype":'"${ts_array[acc_type_login]}"'}' "${ts_array[login_url]}")
        else
            token=$(curl -X POST -s --data '{"account":"'"$account"'","deviceno":"'"$deviceno"'","pwd":"'"$md5_password"'","devicetype":"yuj","businessplatform":1,"signature":"'"$signature"'","isforce":1,"extendinfo":"'"${ts_array[extend_info]}"'","timestamp":"'"$timestamp"'","accounttype":'"${ts_array[acc_type_login]}"'}' "${ts_array[login_url]}")
        fi
    fi

    declare -A login_array
    while IFS="=" read -r key value
    do
        login_array[$key]="$value"
    done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< "$token")

    if [ -z "${login_array[access_token]:-}" ] 
    then
        Println "$error 账号错误"
        printf '%s\n' "${login_array[@]}"
        Println "$info 是否注册账号? [y/N]"
        read -p "(默认: N): " register_yn
        register_yn=${register_yn:-N}
        if [[ $register_yn == [Yy] ]]
        then
            TsRegister
        else
            Println "已取消...\n" && exit 1
        fi
    else
        while :; do
            Println "$info 输入需要转换的频道号码："
            read -p "(默认: 取消): " programid
            [ -z "$programid" ] && Println "已取消...\n" && exit 1
            [[ $programid =~ ^[0-9]{10}$ ]] || { Println "$error频道号码错误！"; continue; }
            break
        done

        if [ -n "${ts_array[auth_info_url]:-}" ] 
        then
            declare -A auth_info_array
            while IFS="=" read -r key value
            do
                auth_info_array[$key]="$value"
            done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[auth_info_url]}?accesstoken=${login_array[access_token]}&programid=$programid&playtype=live&protocol=hls&verifycode=${login_array[device_id]}" -qO-))

            if [ "${auth_info_array[ret]}" -eq 0 ] 
            then
                authtoken="ipanel123#%#&*(&(*#*&^*@#&*%()#*()$)#@&%(*@#()*%321ipanel${auth_info_array[auth_random_sn]}"
                authtoken=$(printf '%s' "$authtoken" | md5sum)
                authtoken=${authtoken%% *}
                playtoken=${auth_info_array[play_token]}

                declare -A auth_verify_array
                while IFS="=" read -r key value
                do
                    auth_verify_array[$key]="$value"
                done < <($JQ_FILE -r 'to_entries | map("\(.key)=\(.value)") | .[]' <<< $(wget --no-check-certificate "${ts_array[auth_verify_url]}?programid=$programid&playtype=live&protocol=hls&accesstoken=${login_array[access_token]}&verifycode=${login_array[device_id]}&authtoken=$authtoken" -qO-))

                if [ "${auth_verify_array[ret]}" -eq 0 ] 
                then
                    TS_LINK="${ts_array[play_url]}?playtype=live&protocol=http&accesstoken=${login_array[access_token]}&playtoken=$playtoken&verifycode=${login_array[device_id]}&rate=org&programid=$programid"
                else
                    Println "$error 发生错误"
                    printf '%s\n' "${auth_verify_array[@]}"
                    exit 1
                fi
            else
                Println "$error 发生错误"
                printf '%s\n' "${auth_info_array[@]}"
                exit 1
            fi
        else
            TS_LINK="${ts_array[play_url]}?playtype=live&protocol=http&accesstoken=${login_array[access_token]}&playtoken=ABCDEFGH&verifycode=${login_array[device_id]}&rate=org&programid=$programid"
        fi

        Println "$info ts链接：\n$TS_LINK"

        stream_link=$($JQ_FILE -r --arg a "programid=$programid" '[.channels[].stream_link] | map(select(test($a)))[0]' "$CHANNELS_FILE")
        if [ "${stream_link:-}" != null ]
        then
            Println "$info 检测到此频道原有链接，是否替换成新的ts链接? [Y/n]"
            read -p "(默认: Y): " change_yn
            change_yn=${change_yn:-Y}
            if [[ $change_yn == [Yy] ]]
            then
                JQ update "$CHANNELS_FILE" '(.channels[]|select(.stream_link=="'"$stream_link"'")|.stream_link)="'"$TS_LINK"'"'
                Println "$info 修改成功 !\n"
            else
                Println "已取消...\n" && exit 1
            fi
        fi
    fi
}

TsMenu()
{
    GetDefault

    Println "$info 是否使用默认频道文件? 默认链接: $DEFAULT_CHANNELS_LINK [Y/n]"
    read -p "(默认: Y): " use_default_channels_yn
    use_default_channels_yn=${use_default_channels_yn:-Y}
    if [[ $use_default_channels_yn == [Yy] ]]
    then
        TS_CHANNELS_LINK=$DEFAULT_CHANNELS_LINK
    else
        if [ -n "$d_sync_file" ] && [[ -n $($JQ_FILE '.data[] | select(.reg_url != null)' "${d_sync_file%% *}") ]] 
        then
            Println "$info 是否使用本地频道文件? 本地路径: ${d_sync_file%% *} [Y/n]"
            read -p "(默认: Y): " use_local_channels_yn
            use_local_channels_yn=${use_local_channels_yn:-Y}
            if [[ $use_local_channels_yn == [Yy] ]] 
            then
                TS_CHANNELS_FILE=${d_sync_file%% *}
            fi
        fi
        if [ -z "${TS_CHANNELS_FILE:-}" ]
        then
            Println "$info 请输入使用的频道文件链接或本地路径: \n"
            read -p "(默认: 取消): " TS_CHANNELS_LINK_OR_FILE
            [ -z "$TS_CHANNELS_LINK_OR_FILE" ] && Println "已取消...\n" && exit 1
            if [ "${TS_CHANNELS_LINK_OR_FILE:0:4}" == "http" ] 
            then
                TS_CHANNELS_LINK=$TS_CHANNELS_LINK_OR_FILE
            else
                [ ! -e "$TS_CHANNELS_LINK_OR_FILE" ] && Println "文件不存在，已取消...\n" && exit 1
                TS_CHANNELS_FILE=$TS_CHANNELS_LINK_OR_FILE
            fi
        fi
    fi

    if [ -z "${TS_CHANNELS_LINK:-}" ] 
    then
        ts_channels=$(< "$TS_CHANNELS_FILE")
    else
        ts_channels=$(wget --no-check-certificate "$TS_CHANNELS_LINK" -qO-)

        [ -z "$ts_channels" ] && Println "$error 无法连接文件地址，已取消...\n" && exit 1
    fi

    ts_channels_desc=()
    while IFS='' read -r desc 
    do
        ts_channels_desc+=("$desc")
    done < <($JQ_FILE -r '.data[] | select(.reg_url != null) | .desc | @sh' <<< "$ts_channels")
    
    count=${#ts_channels_desc[@]}

    Println "$info 选择需要操作的直播源\n"
    for((i=0;i<count;i++));
    do
        desc=${ts_channels_desc[i]//\"/}
        desc=${desc//\'/}
        desc=${desc//\\/\'}
        echo -e "$green$((i+1)).$plain $desc"
    done
    
    while :; do
        echo && read -p "(默认: 取消): " channel_id
        [ -z "$channel_id" ] && Println "已取消...\n" && exit 1
        [[ $channel_id =~ ^[0-9]+$ ]] || { Println "$error请输入序号！"; continue; }
        if ((channel_id >= 1 && channel_id <= count)); then
            ((channel_id--))
            declare -A ts_array
            while IFS="=" read -r key value
            do
                ts_array[$key]="$value"
            done < <($JQ_FILE -r '[.data[] | select(.reg_url != null)]['"$channel_id"'] | to_entries | map("\(.key)=\(.value)") | .[]' <<< "$ts_channels")

            if [ "${ts_array[name]}" == "jxtvnet" ] && ! nc -z "access.jxtvnet.tv" 81 2> /dev/null
            then
                Println "$info 部分服务器无法连接此直播源，但可以将ip写入 /etc/hosts 来连接，请选择线路
  ${green}1.$plain 电信
  ${green}2.$plain 联通"
                read -p "(默认: 取消): " jxtvnet_lane
                case $jxtvnet_lane in
                    1) 
                        printf '%s\n' "59.63.205.33 access.jxtvnet.tv" >> "/etc/hosts"
                        printf '%s\n' "59.63.205.33 stream.slave.jxtvnet.tv" >> "/etc/hosts"
                        printf '%s\n' "59.63.205.33 slave.jxtvnet.tv" >> "/etc/hosts"
                    ;;
                    2) 
                        printf '%s\n' "110.52.240.146 access.jxtvnet.tv" >> "/etc/hosts"
                        printf '%s\n' "110.52.240.146 stream.slave.jxtvnet.tv" >> "/etc/hosts"
                        printf '%s\n' "110.52.240.146 slave.jxtvnet.tv" >> "/etc/hosts"
                    ;;
                    *) Println "已取消...\n" && exit 1
                    ;;
                esac
            fi

            Println "$info 选择操作

  ${green}1.$plain 登录以获取ts链接
  ${green}2.$plain 注册账号\n"
            read -p "(默认: 取消): " channel_act
            [ -z "$channel_act" ] && Println "已取消...\n" && exit 1
            
            case $channel_act in
                1) TsLogin
                ;;
                2) TsRegister
                ;;
                *) Println "已取消...\n" && exit 1
                ;;
            esac
            
            break
        else
            Println "$error序号错误，请重新输入！"
        fi
    done
    
}

AntiDDoS()
{
    trap '' HUP INT
    trap 'MonitorError $LINENO' ERR
    trap '
        [ -e "/tmp/monitor.lockdir/$BASHPID" ] && rm -f "/tmp/monitor.lockdir/$BASHPID"
    ' EXIT

    mkdir -p "/tmp/monitor.lockdir" 
    printf '%s' "" > "/tmp/monitor.lockdir/$BASHPID"

    ips=()
    jail_time=()

    if [[ $d_anti_ddos_port == *","* ]] || [[ $d_anti_ddos_port == *"-"* ]] 
    then
        d_anti_ddos_port="$d_anti_ddos_port proto tcp"
    fi

    if [ -s "$IP_DENY" ]  
    then
        while IFS= read -r line
        do
            if [[ $line == *:* ]] 
            then
                ip=${line%:*}
                jail=${line#*:}
                ips+=("$ip")
                jail_time+=("$jail")
            else
                ip=$line
                ufw delete deny from "$ip" to any port $d_anti_ddos_port > /dev/null 2>> "$IP_LOG"
            fi
        done < "$IP_DENY"

        if [ -n "${ips:-}" ] 
        then
            new_ips=()
            new_jail_time=()
            printf -v now '%(%s)T'

            update=0
            for((i=0;i<${#ips[@]};i++));
            do
                if [ "$now" -gt "${jail_time[i]}" ] 
                then
                    ufw delete deny from "${ips[i]}" to any port $d_anti_ddos_port > /dev/null 2>> "$IP_LOG"
                    update=1
                else
                    new_ips+=("${ips[i]}")
                    new_jail_time+=("${jail_time[i]}")
                fi
            done

            if [ "$update" -eq 1 ] 
            then
                ips=("${new_ips[@]}")
                jail_time=("${new_jail_time[@]}")

                printf '%s' "" > "$IP_DENY"

                for((i=0;i<${#ips[@]};i++));
                do
                    printf '%s\n' "${ips[i]}:${jail_time[i]}" >> "$IP_DENY"
                done
            fi
        else
            printf '%s' "" > "$IP_DENY"
        fi
    fi

    printf '%s\n' "$date_now AntiDDoS 启动成功 PID $BASHPID !" >> "$MONITOR_LOG"

    current_ip=${SSH_CLIENT%% *}
    [ -n "${anti_ddos_level:-}" ] && ((anti_ddos_level++))
    monitor=1
    while true
    do
        if [ "$anti_ddos_syn_flood_yn" == "yes" ] 
        then
            anti_ddos_syn_flood_ips=()
            while IFS= read -r anti_ddos_syn_flood_ip 
            do
                anti_ddos_syn_flood_ips+=("$anti_ddos_syn_flood_ip")
            done < <(ss -taH|awk '{gsub(/.*:/, "", $4);gsub(/:.*/, "", $5); if ($1 == "SYN-RECV" && $5 != "'"$current_ip"'" && ('"$anti_ddos_ports_command$anti_ddos_ports_range_command"')) print $5}')

            sleep "$anti_ddos_syn_flood_delay_seconds"

            printf -v now '%(%s)T'
            jail=$((now + anti_ddos_syn_flood_seconds))

            while IFS= read -r anti_ddos_syn_flood_ip 
            do
                to_ban=1
                for banned_ip in "${ips[@]}"
                do
                    if [ "$banned_ip" == "$anti_ddos_syn_flood_ip/24" ] 
                    then
                        to_ban=0
                        break 1
                    fi
                done

                if [ "$to_ban" -eq 1 ] 
                then
                    for ip in "${anti_ddos_syn_flood_ips[@]}"
                    do
                        if [ "$ip" == "$anti_ddos_syn_flood_ip" ] 
                        then
                            ip="$ip/24"
                            jail_time+=("$jail")
                            printf '%s\n' "$ip:$jail" >> "$IP_DENY"
                            ufw insert 1 deny from "$ip" to any port $anti_ddos_port > /dev/null 2>> "$IP_LOG"
                            printf -v date_now '%(%m-%d %H:%M:%S)T'
                            printf '%s\n' "$date_now $ip 已被禁" >> "$IP_LOG"
                            ips+=("$ip")
                            break 1
                        fi
                    done
                fi
            done < <(ss -taH|awk '{gsub(/.*:/, "", $4);gsub(/:.*/, "", $5); if ($1 == "SYN-RECV" && $5 != "'"$current_ip"'" && ('"$anti_ddos_ports_command$anti_ddos_ports_range_command"')) print $5}')
        fi

        if [ "$anti_ddos_yn" == "yes" ] 
        then
            chnls_count=0
            chnls_output_dir_name=()
            chnls_seg_length=()
            chnls_seg_count=()
            while IFS= read -r channel
            do
                chnls_count=$((chnls_count+1))
                map_output_dir_name=${channel#*output_dir_name: }
                map_output_dir_name=${map_output_dir_name%, seg_length:*}
                map_seg_length=${channel#*seg_length: }
                map_seg_length=${map_seg_length%, seg_count:*}
                map_seg_count=${channel#*seg_count: }
                map_seg_count=${map_seg_count%\"}

                chnls_output_dir_name+=("$map_output_dir_name")
                chnls_seg_length+=("$map_seg_length")
                chnls_seg_count+=("$map_seg_count")
            done < <($JQ_FILE '.channels | to_entries | map("output_dir_name: \(.value.output_dir_name), seg_length: \(.value.seg_length), seg_count: \(.value.seg_count)") | .[]' "$CHANNELS_FILE")

            output_dir_names=()
            triggers=()
            for output_dir_root in "$LIVE_ROOT"/*
            do
                output_dir_name=${output_dir_root#*$LIVE_ROOT/}

                for((i=0;i<chnls_count;i++));
                do
                    if [ "$output_dir_name" == "${chnls_output_dir_name[i]}" ] 
                    then
                        chnl_seg_count=${chnls_seg_count[i]}
                        if [ "$chnl_seg_count" != 0 ] 
                        then
                            chnl_seg_length=${chnls_seg_length[i]}
                            trigger=$(( 60 * anti_ddos_level / (chnl_seg_length * chnl_seg_count) ))
                            if [ "$trigger" -eq 0 ] 
                            then
                                trigger=1
                            fi
                            output_dir_names+=("$output_dir_name")
                            triggers+=("$trigger")
                        fi
                    fi
                done
            done

            printf -v now '%(%s)T'
            jail=$((now + anti_ddos_seconds))

            while IFS=' ' read -r counts ip access_file
            do
                if [[ $access_file == *".ts" ]] 
                then
                    seg_name=${access_file##*/}
                    access_file=${access_file%/*}
                    dir_name=${access_file##*/}
                    access_file=${access_file%/*}
                    to_ban=0

                    if [ -e "$LIVE_ROOT/$dir_name/$seg_name" ] 
                    then
                        output_dir_name=$dir_name
                        to_ban=1
                    elif [ -e "$LIVE_ROOT/${access_file##*/}/$dir_name/$seg_name" ] 
                    then
                        output_dir_name=${access_file##*/}
                        to_ban=1
                    fi

                    for banned_ip in "${ips[@]}"
                    do
                        if [ "$banned_ip" == "$ip" ] 
                        then
                            to_ban=0
                            break 1
                        fi
                    done

                    if [ "$to_ban" -eq 1 ] 
                    then
                        for((i=0;i<${#output_dir_names[@]};i++));
                        do
                            if [ "${output_dir_names[i]}" == "$output_dir_name" ] && [ "$counts" -gt "${triggers[i]}" ]
                            then
                                jail_time+=("$jail")
                                printf '%s\n' "$ip:$jail" >> "$IP_DENY"
                                ufw insert 1 deny from "$ip" to any port $anti_ddos_port > /dev/null 2>> "$IP_LOG"
                                printf -v date_now '%(%m-%d %H:%M:%S)T'
                                printf '%s\n' "$date_now $ip 已被禁" >> "$IP_LOG"
                                ips+=("$ip")
                                break 1
                            fi
                        done
                    fi
                fi
            done< <(awk -v d1="$(printf '%(%d/%b/%Y:%H:%M:%S)T' $((now-60)))" '{gsub(/^[\[\t]+/, "", $4); if ( $4 > d1 ) print $1,$7;}' /usr/local/nginx/logs/access.log | sort | uniq -c | sort -k1 -nr)
            # date --date '-1 min' '+%d/%b/%Y:%T'
            # awk -v d1="$(printf '%(%d/%b/%Y:%H:%M:%S)T' $((now-60)))" '{gsub(/^[\[\t]+/, "", $4); if ($7 ~ "'"$link"'" && $4 > d1 ) print $1;}' /usr/local/nginx/logs/access.log | sort | uniq -c | sort -fr
        fi

        sleep 10

        if [ -n "${ips:-}" ] 
        then
            new_ips=()
            new_jail_time=()
            printf -v now '%(%s)T'

            update=0
            for((i=0;i<${#ips[@]};i++));
            do
                if [ "$now" -gt "${jail_time[i]}" ] 
                then
                    ufw delete deny from "${ips[i]}" to any port $anti_ddos_port > /dev/null 2>> "$IP_LOG"
                    update=1
                else
                    new_ips+=("${ips[i]}")
                    new_jail_time+=("${jail_time[i]}")
                fi
            done

            if [ "$update" -eq 1 ] 
            then
                ips=("${new_ips[@]}")
                jail_time=("${new_jail_time[@]}")

                printf '%s' "" > "$IP_DENY"

                for((i=0;i<${#ips[@]};i++));
                do
                    printf '%s\n' "${ips[i]}:${jail_time[i]}" >> "$IP_DENY"
                done
            fi
        fi
    done
}

AntiDDoSSet()
{
    if [ -x "$(command -v ufw)" ] && [ -s "/usr/local/nginx/logs/access.log" ] && ls -A $LIVE_ROOT/* > /dev/null 2>&1
    then
        sleep 1

        if ufw show added | grep -q "None" 
        then
            [ -x "$(command -v iptables)" ] && iptables -F
            Println "$info 添加常用 ufw 规则"
            ufw allow ssh > /dev/null 2>&1
            ufw allow http > /dev/null 2>&1
            ufw allow https > /dev/null 2>&1

            if ufw status | grep -q "inactive" 
            then
                current_port=${SSH_CLIENT##* }
                if [ "$current_port" != 22 ] 
                then
                    ufw allow "$current_port" > /dev/null 2>&1
                fi
                Println "$info 开启 ufw"
                ufw --force enable > /dev/null 2>&1
            fi
        fi

        [ -z "${d_anti_ddos_port:-}" ] && GetDefault

        Println "设置封禁端口"
        echo -e "$tip 多个端口用空格分隔 比如 22 80 443 12480-12489\n"
        while read -p "(默认: $d_anti_ddos_port_text): " anti_ddos_ports
        do
            anti_ddos_ports=${anti_ddos_ports:-$d_anti_ddos_port_text}
            if [ -z "$anti_ddos_ports" ] 
            then
                Println "$error 请输入正确的数字\n"
                continue
            fi

            IFS=" " read -ra anti_ddos_ports_arr <<< "$anti_ddos_ports"

            error_no=0
            for anti_ddos_port in "${anti_ddos_ports_arr[@]}"
            do
                case "$anti_ddos_port" in
                    *"-"*)
                        anti_ddos_ports_start=${anti_ddos_port%-*}
                        anti_ddos_ports_end=${anti_ddos_port#*-}
                        if [[ $anti_ddos_ports_start == *[!0-9]* ]] || [[ $anti_ddos_ports_end == *[!0-9]* ]] || [ "$anti_ddos_ports_start" -eq 0 ] || [ "$anti_ddos_ports_end" -eq 0 ] || [ "$anti_ddos_ports_start" -ge "$anti_ddos_ports_end" ]
                        then
                            error_no=3
                        fi
                    ;;
                    *[!0-9]*)
                        error_no=1
                    ;;
                    *)
                        if [ "$anti_ddos_port" -lt 1 ]  
                        then
                            error_no=2
                        fi
                    ;;
                esac
            done

            case "$error_no" in
                1|2|3)
                    Println "$error 请输入正确的数字\n"
                ;;
                *)
                    anti_ddos_ports_command=""
                    anti_ddos_ports_range_command=""
                    for anti_ddos_port in "${anti_ddos_ports_arr[@]}"
                    do
                        if [[ $anti_ddos_port -eq 80 ]] 
                        then
                            anti_ddos_port="http"
                        elif [[ $anti_ddos_port -eq 443 ]] 
                        then
                            anti_ddos_port="https"
                        elif [[ $anti_ddos_port -eq 22 ]] 
                        then
                            anti_ddos_port="ssh"
                        elif [[ $anti_ddos_port == *"-"* ]] 
                        then
                            anti_ddos_ports_start=${anti_ddos_port%-*}
                            anti_ddos_ports_end=${anti_ddos_port#*-}
                            if [[ anti_ddos_ports_start -le 22 && $anti_ddos_ports_end -ge 22 ]] 
                            then
                                [ -n "$anti_ddos_ports_command" ] && anti_ddos_ports_command="$anti_ddos_ports_command|"
                                anti_ddos_ports_command=$anti_ddos_ports_command"ssh"
                            elif [[ anti_ddos_ports_start -le 80 && $anti_ddos_ports_end -ge 80 ]] 
                            then
                                [ -n "$anti_ddos_ports_command" ] && anti_ddos_ports_command="$anti_ddos_ports_command|"
                                anti_ddos_ports_command=$anti_ddos_ports_command"http"
                            elif [[ anti_ddos_ports_start -le 443 && $anti_ddos_ports_end -ge 443 ]] 
                            then
                                [ -n "$anti_ddos_ports_command" ] && anti_ddos_ports_command="$anti_ddos_ports_command|"
                                anti_ddos_ports_command=$anti_ddos_ports_command"https"
                            fi
                            [ -n "$anti_ddos_ports_range_command" ] && anti_ddos_ports_range_command="$anti_ddos_ports_range_command || "
                            anti_ddos_ports_range_command=$anti_ddos_ports_range_command'($4 >= '"$anti_ddos_ports_start"' && $4 <= '"$anti_ddos_ports_end"')'
                            continue
                        fi

                        [ -n "$anti_ddos_ports_command" ] && anti_ddos_ports_command="$anti_ddos_ports_command|"
                        anti_ddos_ports_command="$anti_ddos_ports_command$anti_ddos_port"
                    done

                    [ -n "$anti_ddos_ports_command" ] && anti_ddos_ports_command='$4 ~ /^('"$anti_ddos_ports_command"')$/'
                    if [ -n "$anti_ddos_ports_range_command" ] 
                    then
                        anti_ddos_ports_range_command='$4 ~ /^[0-9]+$/ && ('"$anti_ddos_ports_range_command"')'
                        [ -n "$anti_ddos_ports_command" ] && anti_ddos_ports_range_command=' || ('"$anti_ddos_ports_range_command"')'
                    fi
                    if [[ $anti_ddos_ports == *" "* ]] || [[ $anti_ddos_ports == *"-"* ]]
                    then
                        anti_ddos_port=${anti_ddos_ports// /,}
                        anti_ddos_port=${anti_ddos_port//-/:}
                        anti_ddos_port="$anti_ddos_port proto tcp"
                    else
                        anti_ddos_port=$anti_ddos_ports
                    fi
                    break
                ;;
            esac
        done

        Println "是否开启 SYN Flood attack 防御 ? [y/N]"
        read -p "(默认: $d_anti_ddos_syn_flood): " anti_ddos_syn_flood_yn
        anti_ddos_syn_flood_yn=${anti_ddos_syn_flood_yn:-$d_anti_ddos_syn_flood}
        if [[ $anti_ddos_syn_flood_yn == [Yy] ]] 
        then
            anti_ddos_syn_flood_yn="yes"
            sysctl -w net.ipv4.tcp_syn_retries=6 > /dev/null
            sysctl -w net.ipv4.tcp_synack_retries=2 > /dev/null
            sysctl -w net.ipv4.tcp_syncookies=1 > /dev/null
            sysctl -w net.ipv4.tcp_max_syn_backlog=1024 > /dev/null
            #iptables -A INPUT -p tcp --syn -m limit --limit 1/s -j ACCEPT --limit 1/s

            Println "设置判断为 SYN Flood attack 的时间 (秒)"
            while read -p "(默认: $d_anti_ddos_syn_flood_delay_seconds 秒): " anti_ddos_syn_flood_delay_seconds
            do
                case $anti_ddos_syn_flood_delay_seconds in
                    "") anti_ddos_syn_flood_delay_seconds=$d_anti_ddos_syn_flood_delay_seconds && break
                    ;;
                    *[!0-9]*) Println "$error 请输入正确的数字\n"
                    ;;
                    *) 
                        if [ "$anti_ddos_syn_flood_delay_seconds" -gt 0 ]
                        then
                            break
                        else
                            Println "$error 请输入正确的数字(大于0)\n"
                        fi
                    ;;
                esac
            done

            Println "设置封禁 SYN Flood attack ip 多少秒"
            while read -p "(默认: $d_anti_ddos_syn_flood_seconds 秒): " anti_ddos_syn_flood_seconds
            do
                case $anti_ddos_syn_flood_seconds in
                    "") anti_ddos_syn_flood_seconds=$d_anti_ddos_syn_flood_seconds && break
                    ;;
                    *[!0-9]*) Println "$error 请输入正确的数字\n"
                    ;;
                    *) 
                        if [ "$anti_ddos_syn_flood_seconds" -gt 0 ]
                        then
                            break
                        else
                            Println "$error 请输入正确的数字(大于0)\n"
                        fi
                    ;;
                esac
            done
        else
            anti_ddos_syn_flood_yn="no"
        fi

        Println "是否开启 iptv 防御 ? [y/N]"
        read -p "(默认: $d_anti_ddos): " anti_ddos_yn
        anti_ddos_yn=${anti_ddos_yn:-$d_anti_ddos}
        if [[ $anti_ddos_yn == [Yy] ]] 
        then
            anti_ddos_yn="yes"

            Println "设置封禁用户 ip 多少秒"
            while read -p "(默认: $d_anti_ddos_seconds 秒): " anti_ddos_seconds
            do
                case $anti_ddos_seconds in
                    "") anti_ddos_seconds=$d_anti_ddos_seconds && break
                    ;;
                    *[!0-9]*) Println "$error 请输入正确的数字\n"
                    ;;
                    *) 
                        if [ "$anti_ddos_seconds" -gt 0 ]
                        then
                            break
                        else
                            Println "$error 请输入正确的数字(大于0)\n"
                        fi
                    ;;
                esac
            done

            Println "设置封禁等级(1-9)"
            echo -e "$tip 数值越低越严格，也越容易误伤，很多情况是网络问题导致重复请求并非 DDoS\n"
            while read -p "(默认: $d_anti_ddos_level): " anti_ddos_level
            do
                case $anti_ddos_level in
                    "") 
                        anti_ddos_level=$d_anti_ddos_level
                        break
                    ;;
                    *[!0-9]*) Println "$error 请输入正确的数字\n"
                    ;;
                    *) 
                        if [ "$anti_ddos_level" -gt 0 ] && [ "$anti_ddos_level" -lt 10 ]
                        then
                            break
                        else
                            Println "$error 请输入正确的数字(1-9)\n"
                        fi
                    ;;
                esac
            done
        else
            anti_ddos_yn="no"
        fi

        if [ "$anti_ddos_syn_flood_yn" == "no" ] && [ "$anti_ddos_yn" == "no" ] 
        then
            if [ "$d_anti_ddos_syn_flood_yn" != "no" ] || [ "$d_anti_ddos_yn" != "no" ]
            then
                JQ update "$CHANNELS_FILE" '(.default|.anti_ddos_syn_flood)="no"|(.default|.anti_ddos)="no"'
            fi
            Println "不启动 AntiDDoS ...\n" && exit 0
        else
            anti_ddos_ports=${anti_ddos_port:-$d_anti_ddos_port}
            anti_ddos_ports=${anti_ddos_port%% *}
            JQ update "$CHANNELS_FILE" '(.default|.anti_ddos_syn_flood)="'"${anti_ddos_syn_flood_yn:-$d_anti_ddos_syn_flood_yn}"'"
            |(.default|.anti_ddos_syn_flood_delay_seconds)='"${anti_ddos_syn_flood_delay_seconds:-$d_anti_ddos_syn_flood_delay_seconds}"'
            |(.default|.anti_ddos_syn_flood_seconds)='"${anti_ddos_syn_flood_seconds:-$d_anti_ddos_syn_flood_seconds}"'
            |(.default|.anti_ddos)="'"${anti_ddos_yn:-$d_anti_ddos_yn}"'"
            |(.default|.anti_ddos_port)="'"$anti_ddos_ports"'"
            |(.default|.anti_ddos_seconds)='"${anti_ddos_seconds:-$d_anti_ddos_seconds}"'
            |(.default|.anti_ddos_level)='"${anti_ddos_level:-$d_anti_ddos_level}"''
        fi
    else
        exit 0
    fi
}

MonitorStop()
{
    printf -v date_now '%(%m-%d %H:%M:%S)T'
    if ! ls -A "/tmp/monitor.lockdir/"* > /dev/null 2>&1
    then
        Println "$error 监控未启动 !\n"
    else
        for PID in "/tmp/monitor.lockdir/"*
        do
            PID=${PID##*/}
            if kill -0 "$PID" 2> /dev/null
            then
                kill "$PID" 2> /dev/null
                printf '%s\n' "$date_now 关闭监控 PID $PID !" >> "$MONITOR_LOG"
            else
                rm -f "/tmp/monitor.lockdir/$PID"
            fi
        done

        Println "$info 关闭监控, 稍等..."

        until ! ls -A "/tmp/monitor.lockdir/"* > /dev/null 2>&1 
        do
            sleep 1
        done

        rm -rf "/tmp/monitor.lockdir/"
        Println "$info 监控关闭成功 !\n"
    fi

    if [ -s "$IP_DENY" ] 
    then
        ips=()
        jail_time=()
        GetDefault
        if [[ $d_anti_ddos_port == *","* ]] || [[ $d_anti_ddos_port == *"-"* ]] 
        then
            d_anti_ddos_port="$d_anti_ddos_port proto tcp"
        fi
        while IFS= read -r line
        do
            if [[ $line == *:* ]] 
            then
                ip=${line%:*}
                jail=${line#*:}
                ips+=("$ip")
                jail_time+=("$jail")
            else
                ip=$line
                ufw delete deny from "$ip" to any port $d_anti_ddos_port
            fi
        done < "$IP_DENY"

        if [ -n "${ips:-}" ] 
        then
            new_ips=()
            new_jail_time=()
            printf -v now '%(%s)T'

            update=0
            for((i=0;i<${#ips[@]};i++));
            do
                if [ "$now" -gt "${jail_time[i]}" ] 
                then
                    ufw delete deny from "${ips[i]}" to any port $d_anti_ddos_port
                    update=1
                else
                    new_ips+=("${ips[i]}")
                    new_jail_time+=("${jail_time[i]}")
                fi
            done

            if [ "$update" -eq 1 ] 
            then
                ips=("${new_ips[@]}")
                jail_time=("${new_jail_time[@]}")

                printf '%s' "" > "$IP_DENY"

                for((i=0;i<${#ips[@]};i++));
                do
                    printf '%s\n' "${ips[i]}:${jail_time[i]}" >> "$IP_DENY"
                done
            fi
        else
            printf '%s' "" > "$IP_DENY"
        fi
    fi
}

MonitorError()
{
    printf -v date_now '%(%m-%d %H:%M:%S)T'
    printf '%s\n' "$date_now [LINE:$1] ERROR" >> "$MONITOR_LOG"
}

MonitorTryAccounts()
{
    accounts=()
    macs=()

    while IFS= read -r line 
    do
        if [[ $line == *"$chnl_domain"* ]] 
        then
            line=${line#* }
            account_line=${line#* }
            if [[ $account_line == *" "* ]] 
            then
                new_account_line=""
                while [[ $account_line == *" "* ]] 
                do
                    if [[ ${account_line%% *} =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
                    then
                        macs+=("${account_line%% *}")
                        account_line=${account_line#* }
                        continue
                    fi
                    [ -n "$new_account_line" ] && new_account_line=" $new_account_line"
                    new_account_line="${account_line%% *}$new_account_line"
                    account_line=${account_line#* }
                done
            elif [[ $account_line =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
            then
                macs+=("$account_line")
            else
                new_account_line=$account_line
            fi

            IFS=" " read -ra accounts <<< "$new_account_line"
            break
        fi
    done < "$XTREAM_CODES"

    if [ -n "${chnl_mac:-}" ] 
    then
        if [ "${#macs[@]}" -gt 0 ] 
        then
            macs+=("$chnl_mac")
            for mac_address in "${macs[@]}"
            do
                xc_chnl_found=0
                for xc_chnl_mac in "${xc_chnls_mac[@]}"
                do
                    if [ "$xc_chnl_mac" == "$chnl_domain/$mac_address" ] 
                    then
                        xc_chnl_found=1
                        break
                    fi
                done

                valid=0
                if [ "$xc_chnl_found" -eq 0 ] 
                then
                    token=""
                    access_token=""
                    profile=""
                    chnl_user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
                    server="http://$chnl_domain"
                    mac=$(Urlencode "$mac_address")
                    timezone=$(Urlencode "Europe/Amsterdam")
                    chnl_cookies="mac=$mac; stb_lang=en; timezone=$timezone"
                    token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
                    profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"
                    genres_url="$server/portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml"

                    token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                        --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                        | $JQ_FILE -r '.js.token' || true)
                    if [ -z "$token" ] 
                    then
                        break
                    fi
                    access_token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                        --header="Authorization: Bearer $token" \
                        --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                        | $JQ_FILE -r '.js.token' || true)
                    if [ -z "$access_token" ] 
                    then
                        break
                    fi
                    chnl_headers="Authorization: Bearer $access_token"
                    profile=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                        --header="$chnl_headers" \
                        --header="Cookie: $chnl_cookies" "$profile_url" -qO- || true)
                    if [ -z "$profile" ] 
                    then
                        break
                    fi

                    if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
                    then
                        continue
                    fi

                    create_link_url="$server/portal.php?type=itv&action=create_link&cmd=$chnl_cmd&series=&forced_storage=undefined&disable_ad=0&download=0&JsHttpRequest=1-xml"
                    chnl_stream_link=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                        --header="$chnl_headers" \
                        --header="Cookie: $chnl_cookies" "$create_link_url" -qO- \
                        | $JQ_FILE -r '.js.cmd')
                    chnl_stream_link=${chnl_stream_link#* }
                    IFS="/" read -ra s <<< "$chnl_stream_link"
                    if [ "${s[3]}" == "live" ] 
                    then
                        chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[5]}/${s[-1]}"
                    else
                        chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[-1]}"
                    fi

                    audio=0
                    video=0
                    while IFS= read -r line 
                    do
                        if [[ $line == *"codec_type=audio"* ]] 
                        then
                            audio=1
                        elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                        then
                            audio=0
                        elif [[ $line == *"codec_type=video"* ]] 
                        then
                            video=1
                        fi
                    done < <($FFPROBE $chnl_proxy_command -i "$chnl_stream_link" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

                    if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ]
                    then
                        valid=1
                    fi

                    if [ "$valid" -eq 1 ] 
                    then
                        action="skip"
                        StopChannel

                        if [[ $chnl_stream_links == *" "* ]] 
                        then
                            chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$mac_address ${chnl_stream_links#* }"
                        else
                            chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$mac_address"
                        fi

                        if [ -n "${monitor:-}" ] && [ "$anti_leech_yn" == "yes" ]
                        then
                            if [ -z "${kind:-}" ] && [ "$anti_leech_restart_hls_changes_yn" == "yes" ]
                            then
                                chnl_playlist_name=$(RandStr)
                                chnl_seg_name=$chnl_playlist_name
                                if [ "$chnl_encrypt_yn" == "yes" ] 
                                then
                                    mkdir -p "$chnl_output_dir_root"
                                    chnl_key_name=$(RandStr)
                                    openssl rand 16 > "$chnl_output_dir_root/$chnl_key_name.key"
                                    if [ "$chnl_encrypt_session_yn" == "yes" ] 
                                    then
                                        echo -e "/keys?key=$chnl_key_name&channel=$chnl_output_dir_name\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                                    else
                                        echo -e "$chnl_key_name.key\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                                    fi
                                fi
                            elif [ "${kind:-}" == "flv" ] && [ "$anti_leech_restart_flv_changes_yn" == "yes" ]
                            then
                                stream_name=${chnl_flv_push_link##*/}
                                new_stream_name=$(RandStr)
                                while [[ -n $($JQ_FILE '.channels[]|select(.flv_push_link=="'"${chnl_flv_push_link%/*}/$new_stream_name"'")' "$CHANNELS_FILE") ]] 
                                do
                                    new_stream_name=$(RandStr)
                                done
                                chnl_flv_push_link="${chnl_flv_push_link%/*}/$new_stream_name"
                                monitor_flv_push_links[i]=$chnl_flv_push_link
                                if [ -n "$chnl_flv_pull_link" ] 
                                then
                                    chnl_flv_pull_link=${chnl_flv_pull_link//stream=$stream_name/stream=$new_stream_name}
                                    monitor_flv_pull_links[i]=$chnl_flv_pull_link
                                fi
                            fi
                        fi

                        StartChannel
                        if [ -z "${monitor:-}" ] 
                        then
                            try_success=1
                            sleep 3
                            break
                        fi
                        sleep 15
                        GetChannelInfo

                        if [ "${kind:-}" == "flv" ] 
                        then
                            audio=0
                            video=0
                            while IFS= read -r line 
                            do
                                if [[ $line == *"codec_type=audio"* ]] 
                                then
                                    audio=1
                                elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]]
                                then
                                    audio=0
                                elif [[ $line == *"codec_type=video"* ]] 
                                then
                                    video=1
                                fi
                            done < <($FFPROBE -i "${chnl_flv_pull_link:-$chnl_flv_push_link}" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

                            if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ]
                            then
                                try_success=1
                                printf -v date_now '%(%m-%d %H:%M:%S)T'
                                printf '%s\n' "$date_now $chnl_channel_name 重启成功" >> "$MONITOR_LOG"
                                break
                            fi
                        elif ls -A "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts > /dev/null 2>&1 
                        then
                            if [ "$chnl_encrypt_yn" == "yes" ] && [ -e "$LIVE_ROOT/$output_dir_name/$chnl_keyinfo_name.keyinfo" ] && [ -e "$LIVE_ROOT/$output_dir_name/$chnl_key_name.key" ]
                            then
                                line_no=0
                                while IFS= read -r line 
                                do
                                    line_no=$((line_no+1))
                                    if [ "$line_no" -eq 3 ] 
                                    then
                                        iv_hex=$line
                                    fi
                                done < "$LIVE_ROOT/$output_dir_name/$chnl_keyinfo_name.keyinfo"

                                encrypt_key=$(hexdump -e '16/1 "%02x"' < "$LIVE_ROOT/$output_dir_name/$chnl_key_name.key")
                                encrypt_command="-key $encrypt_key -iv $iv_hex"
                            else
                                encrypt_command=""
                            fi

                            audio=0
                            video=0
                            video_bitrate=0
                            bitrate_check=0

                            f_count=1
                            for f in "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts
                            do
                                ((f_count++))
                            done

                            f_num=$((f_count/2))
                            f_count=1

                            for f in "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts
                            do
                                if [ "$f_count" -lt "$f_num" ] 
                                then
                                    ((f_count++))
                                    continue
                                fi
                                [ -n "$encrypt_command" ] && f="crypto:$f"
                                while IFS= read -r line 
                                do
                                    if [[ $line == *"codec_type=video"* ]] 
                                    then
                                        video=1
                                    elif [ "$bitrate_check" -eq 0 ] && [ "$video" -eq 1 ] && [[ $line == *"bit_rate="* ]] 
                                    then
                                        line=${line#*bit_rate=}
                                        video_bitrate=${line//N\/A/$hls_min_bitrates}
                                        bitrate_check=1
                                    elif [[ $line == *"codec_type=audio"* ]] 
                                    then
                                        audio=1
                                    elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                                    then
                                        audio=0
                                    fi
                                done < <($FFPROBE $encrypt_command -i "$f" -show_streams -loglevel quiet || true)
                                break
                            done

                            if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ] && [[ $video_bitrate -ge $hls_min_bitrates ]]
                            then
                                try_success=1
                                printf -v date_now '%(%m-%d %H:%M:%S)T'
                                printf '%s\n' "$date_now $chnl_channel_name 重启成功" >> "$MONITOR_LOG"
                                break
                            fi
                        fi
                    fi
                fi
            done
        fi
    elif [ "${#accounts[@]}" -gt 0 ] 
    then
        accounts+=("$chnl_account")

        for account in "${accounts[@]}"
        do
            xc_chnl_found=0
            for xc_chnl in "${xc_chnls[@]}"
            do
                if [ "$xc_chnl" == "$chnl_domain/$account" ] 
                then
                    xc_chnl_found=1
                    break
                fi
            done

            valid=0
            if [ "$xc_chnl_found" -eq 0 ] 
            then
                if [[ $chnl_stream_link == *"/live/"* ]] 
                then
                    chnl_stream_link="http://$chnl_domain/live/${account//:/\/}/${chnl_stream_link##*/}"
                else
                    chnl_stream_link="http://$chnl_domain/${account//:/\/}/${chnl_stream_link##*/}"
                fi

                audio=0
                video=0
                while IFS= read -r line 
                do
                    if [[ $line == *"codec_type=audio"* ]] 
                    then
                        audio=1
                    elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                    then
                        audio=0
                    elif [[ $line == *"codec_type=video"* ]] 
                    then
                        video=1
                    fi
                done < <($FFPROBE $chnl_proxy_command -i "$chnl_stream_link" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

                if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ]
                then
                    valid=1
                fi
            fi

            if [ "$valid" -eq 1 ] 
            then
                action="skip"
                StopChannel

                if [[ $chnl_stream_links == *" "* ]] 
                then
                    chnl_stream_links="$chnl_stream_link ${chnl_stream_links#* }"
                else
                    chnl_stream_links=$chnl_stream_link
                fi

                if [ -n "${monitor:-}" ] && [ "$anti_leech_yn" == "yes" ]
                then
                    if [ -z "${kind:-}" ] && [ "$anti_leech_restart_hls_changes_yn" == "yes" ]
                    then
                        chnl_playlist_name=$(RandStr)
                        chnl_seg_name=$chnl_playlist_name
                        if [ "$chnl_encrypt_yn" == "yes" ] 
                        then
                            mkdir -p "$chnl_output_dir_root"
                            chnl_key_name=$(RandStr)
                            openssl rand 16 > "$chnl_output_dir_root/$chnl_key_name.key"
                            if [ "$chnl_encrypt_session_yn" == "yes" ] 
                            then
                                echo -e "/keys?key=$chnl_key_name&channel=$chnl_output_dir_name\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                            else
                                echo -e "$chnl_key_name.key\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                            fi
                        fi
                    elif [ "${kind:-}" == "flv" ] && [ "$anti_leech_restart_flv_changes_yn" == "yes" ]
                    then
                        stream_name=${chnl_flv_push_link##*/}
                        new_stream_name=$(RandStr)
                        while [[ -n $($JQ_FILE '.channels[]|select(.flv_push_link=="'"${chnl_flv_push_link%/*}/$new_stream_name"'")' "$CHANNELS_FILE") ]] 
                        do
                            new_stream_name=$(RandStr)
                        done
                        chnl_flv_push_link="${chnl_flv_push_link%/*}/$new_stream_name"
                        monitor_flv_push_links[i]=$chnl_flv_push_link
                        if [ -n "$chnl_flv_pull_link" ] 
                        then
                            chnl_flv_pull_link=${chnl_flv_pull_link//stream=$stream_name/stream=$new_stream_name}
                            monitor_flv_pull_links[i]=$chnl_flv_pull_link
                        fi
                    fi
                fi

                StartChannel
                if [ -z "${monitor:-}" ] 
                then
                    try_success=1
                    sleep 3
                    break
                fi
                sleep 15
                GetChannelInfo

                if [ "${kind:-}" == "flv" ] 
                then
                    audio=0
                    video=0
                    while IFS= read -r line 
                    do
                        if [[ $line == *"codec_type=audio"* ]] 
                        then
                            audio=1
                        elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]]
                        then
                            audio=0
                        elif [[ $line == *"codec_type=video"* ]] 
                        then
                            video=1
                        fi
                    done < <($FFPROBE -i "${chnl_flv_pull_link:-$chnl_flv_push_link}" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

                    if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ]
                    then
                        try_success=1
                        printf -v date_now '%(%m-%d %H:%M:%S)T'
                        printf '%s\n' "$date_now $chnl_channel_name 重启成功" >> "$MONITOR_LOG"
                        break
                    fi
                elif ls -A "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts > /dev/null 2>&1 
                then
                    if [ "$chnl_encrypt_yn" == "yes" ] && [ -e "$LIVE_ROOT/$output_dir_name/$chnl_keyinfo_name.keyinfo" ] && [ -e "$LIVE_ROOT/$output_dir_name/$chnl_key_name.key" ]
                    then
                        line_no=0
                        while IFS= read -r line 
                        do
                            line_no=$((line_no+1))
                            if [ "$line_no" -eq 3 ] 
                            then
                                iv_hex=$line
                            fi
                        done < "$LIVE_ROOT/$output_dir_name/$chnl_keyinfo_name.keyinfo"

                        encrypt_key=$(hexdump -e '16/1 "%02x"' < "$LIVE_ROOT/$output_dir_name/$chnl_key_name.key")
                        encrypt_command="-key $encrypt_key -iv $iv_hex"
                    else
                        encrypt_command=""
                    fi

                    audio=0
                    video=0
                    video_bitrate=0
                    bitrate_check=0

                    f_count=1
                    for f in "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts
                    do
                        ((f_count++))
                    done

                    f_num=$((f_count/2))
                    f_count=1

                    for f in "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts
                    do
                        if [ "$f_count" -lt "$f_num" ] 
                        then
                            ((f_count++))
                            continue
                        fi
                        [ -n "$encrypt_command" ] && f="crypto:$f"
                        while IFS= read -r line 
                        do
                            if [[ $line == *"codec_type=video"* ]] 
                            then
                                video=1
                            elif [ "$bitrate_check" -eq 0 ] && [ "$video" -eq 1 ] && [[ $line == *"bit_rate="* ]] 
                            then
                                line=${line#*bit_rate=}
                                video_bitrate=${line//N\/A/$hls_min_bitrates}
                                bitrate_check=1
                            elif [[ $line == *"codec_type=audio"* ]] 
                            then
                                audio=1
                            elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                            then
                                audio=0
                            fi
                        done < <($FFPROBE $encrypt_command -i "$f" -show_streams -loglevel quiet || true)
                        break
                    done

                    if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ] && [[ $video_bitrate -ge $hls_min_bitrates ]]
                    then
                        try_success=1
                        printf -v date_now '%(%m-%d %H:%M:%S)T'
                        printf '%s\n' "$date_now $chnl_channel_name 重启成功" >> "$MONITOR_LOG"
                        break
                    fi
                fi
            fi
        done
    fi
}

GetXtreamCodesDomains()
{
    if [ ! -s "$XTREAM_CODES" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate $XTREAM_CODES_LINK -qO "$XTREAM_CODES"
    fi

    xtream_codes_domains=()

    while IFS= read -r line 
    do
        line=${line#* }
        line=${line%% *}
        IFS="|" read -ra xc_domains <<< "$line"
        for xc_domain in "${xc_domains[@]}"
        do
            xtream_codes_domains+=("$xc_domain")
        done
    done < "$XTREAM_CODES"
}

GetXtreamCodesChnls()
{
    xc_chnls=()
    xc_chnls_mac=()
    if [ "${#xtream_codes_domains[@]}" -gt 0 ] 
    then
        while IFS= read -r line 
        do
            if [[ $line == *\"status\":* ]] 
            then
                line=${line#*: \"}
                f_status=${line%\",*}
            elif [[ $line == *\"stream_link\":* ]]
            then
                line=${line#*: \"}
                line=${line%\",*}
                line=${line%% *}
                if [[ ${line##*|} =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
                then
                    f_mac=${line##*|}
                    f_domain=${line%%|*}
                elif [[ $line == http://*/*/*/* ]] 
                then
                    line=${line#*http://}
                    f_domain=${line%%/*}
                    line=${line#*/}
                    f_username=${line%%/*}
                    if [ "$f_username" == "live" ] 
                    then
                        line=${line#*/}
                        f_username=${line%%/*}
                    fi
                    line=${line#*/}
                    f_password=${line%%/*}
                fi
            elif [[ $line == *\"output_dir_name\":* ]] 
            then
                line=${line#*: \"}
                f_dir_name=${line%\",*}
            elif [[ $line == *\"flv_status\":* ]] 
            then
                line=${line#*: \"}
                f_flv_status=${line%\",*}
            elif [[ $line == *\"flv_push_link\":* ]] 
            then
                line=${line#*: \"}
                f_flv_push_link=${line%\",*}
                if [ -n "${f_domain:-}" ] 
                then
                    for xc_domain in "${xtream_codes_domains[@]}"
                    do
                        if [ "$xc_domain" == "$f_domain" ] 
                        then
                            if { [ "$f_status" == "on" ] && [ "$f_dir_name" != "${chnl_output_dir_name:-}" ]; } || { [ "$f_flv_status" == "on" ] && [ "$f_flv_push_link" != "${chnl_flv_push_link:-}" ]; }
                            then
                                if [ -n "${f_mac:-}" ] 
                                then
                                    xc_chnls_mac+=("$f_domain/$f_mac")
                                else
                                    xc_chnls+=("$f_domain/$f_username:$f_password")
                                fi
                            fi
                        fi
                    done
                fi
                f_domain=""
                f_mac=""
            fi
        done < "$CHANNELS_FILE"
    fi
}

MonitorHlsRestartSuccess()
{
    if [ -n "${failed_restart_nums:-}" ] 
    then
        declare -a new_array
        for element in "${hls_failed[@]}"
        do
            [ "$element" != "$output_dir_name" ] && new_array+=("$element")
        done
        hls_failed=("${new_array[@]}")
        unset new_array

        declare -a new_array
        for element in "${hls_recheck_time[@]}"
        do
            [ "$element" != "${hls_recheck_time[failed_i]}" ] && new_array+=("$element")
        done
        hls_recheck_time=("${new_array[@]}")
        unset new_array
    fi
    printf -v date_now '%(%m-%d %H:%M:%S)T'
    printf '%s\n' "$date_now $chnl_channel_name 重启成功" >> "$MONITOR_LOG"
}

MonitorHlsRestartFail()
{
    StopChannel
    printf -v now '%(%s)T'
    recheck_time=$((now+recheck_period))

    if [ -n "${failed_restart_nums:-}" ] 
    then
        hls_recheck_time[failed_i]=$recheck_time
    else
        hls_recheck_time+=("$recheck_time")
        hls_failed+=("$output_dir_name")
    fi

    declare -a new_array
    for element in "${monitor_dir_names_chosen[@]}"
    do
        [ "$element" != "$output_dir_name" ] && new_array+=("$element")
    done
    monitor_dir_names_chosen=("${new_array[@]}")
    unset new_array

    printf -v date_now '%(%m-%d %H:%M:%S)T'
    printf '%s\n' "$date_now $chnl_channel_name 重启失败" >> "$MONITOR_LOG"
}

MonitorHlsRestartChannel()
{
    GetXtreamCodesChnls
    domains_tried=()
    hls_restart_nums=${hls_restart_nums:-20}
    unset failed_restart_nums

    for((failed_i=0;failed_i<${#hls_failed[@]};failed_i++));
    do
        if [ "${hls_failed[failed_i]}" == "$output_dir_name" ] 
        then
            failed_restart_nums=3
            break
        fi
    done

    restart_nums=${failed_restart_nums:-$hls_restart_nums}

    IFS=" " read -ra chnl_stream_links_arr <<< "$chnl_stream_links"

    if [ "${#chnl_stream_links_arr[@]}" -gt $restart_nums ] 
    then
        restart_nums=${#chnl_stream_links_arr[@]}
    fi

    for((restart_i=0;restart_i<restart_nums;restart_i++))
    do
        if [ "$restart_i" -gt 0 ] && [[ $chnl_stream_links == *" "* ]] 
        then
            chnl_stream_links="${chnl_stream_links#* } $chnl_stream_link"
            chnl_stream_link=${chnl_stream_links%% *}
        fi

        chnl_mac=""
        if [[ ${chnl_stream_link##*|} =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
        then
            chnl_domain=${chnl_stream_link%%|*}
            chnl_mac=${chnl_stream_link##*|}
            chnl_cmd=${chnl_stream_link%|*}
            chnl_cmd=${chnl_cmd##*|}

            to_try=0
            for xc_domain in "${xtream_codes_domains[@]}"
            do
                if [ "$xc_domain" == "$chnl_domain" ] 
                then
                    to_try=1
                    for domain in "${domains_tried[@]}"
                    do
                        if [ "$domain" == "$chnl_domain" ] 
                        then
                            to_try=0
                            break
                        fi
                    done
                    break
                fi
            done

            xc_chnl_found=0
            if [ "$to_try" -eq 1 ] 
            then
                to_try=0
                for xc_chnl_mac in "${xc_chnls_mac[@]}"
                do
                    if [ "$xc_chnl_mac" == "$chnl_domain/$chnl_mac" ] 
                    then
                        xc_chnl_found=1
                        break
                    fi
                done
            fi

            if [ "$xc_chnl_found" -eq 1 ]
            then
                domains_tried+=("$chnl_domain")
                try_success=0
                MonitorTryAccounts
                if [ "$try_success" -eq 1 ] 
                then
                    MonitorHlsRestartSuccess
                else
                    if [[ $restart_i -eq $((restart_nums-1)) ]] 
                    then
                        MonitorHlsRestartFail
                    else
                        continue
                    fi
                fi
                break
            fi

            token=""
            access_token=""
            profile=""
            chnl_user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
            server="http://$chnl_domain"
            mac=$(Urlencode "$chnl_mac")
            timezone=$(Urlencode "Europe/Amsterdam")
            chnl_cookies="mac=$mac; stb_lang=en; timezone=$timezone"
            token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
            profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"
            genres_url="$server/portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml"

            token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                | $JQ_FILE -r '.js.token' || true)
            if [ -z "$token" ] 
            then
                if [[ $restart_i -eq $((restart_nums-1)) ]] 
                then
                    MonitorHlsRestartFail
                    break
                else
                    continue
                fi
            fi
            access_token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="Authorization: Bearer $token" \
                --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                | $JQ_FILE -r '.js.token' || true)
            if [ -z "$access_token" ] 
            then
                if [[ $restart_i -eq $((restart_nums-1)) ]] 
                then
                    MonitorHlsRestartFail
                    break
                else
                    continue
                fi
            fi
            chnl_headers="Authorization: Bearer $access_token"
            profile=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="$chnl_headers" \
                --header="Cookie: $chnl_cookies" "$profile_url" -qO- || true)
            if [ -z "$profile" ] 
            then
                if [[ $restart_i -eq $((restart_nums-1)) ]] 
                then
                    MonitorHlsRestartFail
                    break
                else
                    continue
                fi
            fi

            if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
            then
                if [ "$to_try" -eq 1 ] 
                then
                    domains_tried+=("$chnl_domain")
                    try_success=0
                    MonitorTryAccounts
                    if [ "$try_success" -eq 1 ] 
                    then
                        MonitorHlsRestartSuccess
                    else
                        MonitorHlsRestartFail
                    fi
                else
                    MonitorHlsRestartFail
                fi
                break
            else
                create_link_url="$server/portal.php?type=itv&action=create_link&cmd=$chnl_cmd&series=&forced_storage=undefined&disable_ad=0&download=0&JsHttpRequest=1-xml"
                chnl_stream_link=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                    --header="$chnl_headers" \
                    --header="Cookie: $chnl_cookies" "$create_link_url" -qO- \
                    | $JQ_FILE -r '.js.cmd')
                chnl_stream_link=${chnl_stream_link#* }
                IFS="/" read -ra s <<< "$chnl_stream_link"
                if [ "${s[3]}" == "live" ] 
                then
                    chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[5]}/${s[-1]}"
                else
                    chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[-1]}"
                fi
                if [[ $chnl_stream_links == *" "* ]] 
                then
                    chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$chnl_mac ${chnl_stream_links#* }"
                else
                    chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$chnl_mac"
                fi
            fi
        else
            to_try=0
            if [[ $chnl_stream_link =~ http://([^/]+)/([^/]+)/([^/]+)/ ]] 
            then
                chnl_domain=${BASH_REMATCH[1]}

                for xc_domain in "${xtream_codes_domains[@]}"
                do
                    if [ "$xc_domain" == "$chnl_domain" ] 
                    then
                        to_try=1
                        for domain in "${domains_tried[@]}"
                        do
                            if [ "$domain" == "$chnl_domain" ] 
                            then
                                to_try=0
                                break
                            fi
                        done
                        break
                    fi
                done
            fi

            xc_chnl_found=0
            if [ "$to_try" -eq 1 ] 
            then
                to_try=0
                if [ "${BASH_REMATCH[2]}" == "live" ] && [[ $chnl_stream_link =~ http://([^/]+)/live/([^/]+)/([^/]+)/ ]]
                then
                    chnl_account="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
                else
                    chnl_account="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
                fi
                for xc_chnl in "${xc_chnls[@]}"
                do
                    if [ "$xc_chnl" == "$chnl_domain/$chnl_account" ] 
                    then
                        xc_chnl_found=1
                        break
                    fi
                done
            fi

            if [ "$xc_chnl_found" -eq 1 ]
            then
                domains_tried+=("$chnl_domain")
                try_success=0
                MonitorTryAccounts
                if [ "$try_success" -eq 1 ] 
                then
                    MonitorHlsRestartSuccess
                else
                    if [[ $restart_i -eq $((restart_nums-1)) ]] 
                    then
                        MonitorHlsRestartFail
                    else
                        continue
                    fi
                fi
                break
            fi
        fi

        action="skip"
        StopChannel
        if [ "$anti_leech_yn" == "yes" ] && [ "$anti_leech_restart_hls_changes_yn" == "yes" ] 
        then
            chnl_playlist_name=$(RandStr)
            chnl_seg_name=$chnl_playlist_name
            if [ "$chnl_encrypt_yn" == "yes" ] 
            then
                mkdir -p "$chnl_output_dir_root"
                chnl_key_name=$(RandStr)
                openssl rand 16 > "$chnl_output_dir_root/$chnl_key_name.key"
                if [ "$chnl_encrypt_session_yn" == "yes" ] 
                then
                    echo -e "/keys?key=$chnl_key_name&channel=$chnl_output_dir_name\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                else
                    echo -e "$chnl_key_name.key\n$chnl_output_dir_root/$chnl_key_name.key\n$(openssl rand -hex 16)" > "$chnl_output_dir_root/$chnl_keyinfo_name.keyinfo"
                fi
            fi
        fi
        StartChannel
        sleep 15
        GetChannelInfo

        if ls -A "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts > /dev/null 2>&1 
        then
            if [ "$chnl_encrypt_yn" == "yes" ] && [ -e "$LIVE_ROOT/$output_dir_name/$chnl_keyinfo_name.keyinfo" ] && [ -e "$LIVE_ROOT/$output_dir_name/$chnl_key_name.key" ]
            then
                line_no=0
                while IFS= read -r line 
                do
                    line_no=$((line_no+1))
                    if [ "$line_no" -eq 3 ] 
                    then
                        iv_hex=$line
                    fi
                done < "$LIVE_ROOT/$output_dir_name/$chnl_keyinfo_name.keyinfo"
                # xxd -p $KEY_FILE
                encrypt_key=$(hexdump -e '16/1 "%02x"' < "$LIVE_ROOT/$output_dir_name/$chnl_key_name.key")
                encrypt_command="-key $encrypt_key -iv $iv_hex"
            else
                encrypt_command=""
            fi

            audio=0
            video=0
            video_bitrate=0
            bitrate_check=0

            f_count=1
            for f in "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts
            do
                ((f_count++))
            done

            f_num=$((f_count/2))
            f_count=1

            for f in "$LIVE_ROOT/$output_dir_name/$chnl_seg_dir_name/"*.ts
            do
                if [ "$f_count" -lt "$f_num" ] 
                then
                    ((f_count++))
                    continue
                fi
                [ -n "$encrypt_command" ] && f="crypto:$f"
                while IFS= read -r line 
                do
                    if [[ $line == *"codec_type=video"* ]] 
                    then
                        video=1
                    elif [ "$bitrate_check" -eq 0 ] && [ "$video" -eq 1 ] && [[ $line == *"bit_rate="* ]] 
                    then
                        line=${line#*bit_rate=}
                        video_bitrate=${line//N\/A/$hls_min_bitrates}
                        bitrate_check=1
                    elif [[ $line == *"codec_type=audio"* ]] 
                    then
                        audio=1
                    elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                    then
                        audio=0
                    fi
                done < <($FFPROBE $encrypt_command -i "$f" -show_streams -loglevel quiet || true)
                break
            done

            if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ] && [[ $video_bitrate -ge $hls_min_bitrates ]]
            then
                MonitorHlsRestartSuccess
                break
            fi
        fi

        if [ "$to_try" -eq 1 ] 
        then
            domains_tried+=("$chnl_domain")
            try_success=0
            MonitorTryAccounts
            if [ "$try_success" -eq 1 ] 
            then
                MonitorHlsRestartSuccess
                break
            fi
        fi

        if [[ $restart_i -eq $((restart_nums - 1)) ]] 
        then
            MonitorHlsRestartFail
        fi
    done
}

MonitorFlvRestartSuccess()
{
    if [ -n "${failed_restart_nums:-}" ] 
    then
        declare -a new_array
        for element in "${flv_failed[@]}"
        do
            [ "$element" != "$flv_num" ] && new_array+=("$element")
        done
        flv_failed=("${new_array[@]}")
        unset new_array

        declare -a new_array
        for element in "${flv_recheck_time[@]}"
        do
            [ "$element" != "${flv_recheck_time[failed_i]}" ] && new_array+=("$element")
        done
        flv_recheck_time=("${new_array[@]}")
        unset new_array
    fi
    printf -v date_now '%(%m-%d %H:%M:%S)T'
    printf '%s\n' "$date_now $chnl_channel_name 重启成功" >> "$MONITOR_LOG"
}

MonitorFlvRestartFail()
{
    StopChannel
    printf -v now '%(%s)T'
    recheck_time=$((now+recheck_period))

    if [ -n "${failed_restart_nums:-}" ] 
    then
        flv_recheck_time[failed_i]=$recheck_time
    else
        flv_recheck_time+=("$recheck_time")
        flv_failed+=("$flv_num")
    fi

    declare -a new_array
    for element in "${flv_nums_arr[@]}"
    do
        [ "$element" != "$flv_num" ] && new_array+=("$element")
    done
    flv_nums_arr=("${new_array[@]}")
    unset new_array

    printf -v date_now '%(%m-%d %H:%M:%S)T'
    printf '%s\n' "$date_now $chnl_channel_name FLV 重启超过${flv_restart_nums:-20}次关闭" >> "$MONITOR_LOG"
}

MonitorFlvRestartChannel()
{
    GetXtreamCodesChnls
    domains_tried=()
    flv_restart_nums=${flv_restart_nums:-20}
    unset failed_restart_nums

    for((failed_i=0;failed_i<${#flv_failed[@]};failed_i++));
    do
        if [ "${flv_failed[failed_i]}" == "$flv_num" ] 
        then
            failed_restart_nums=3
            break
        fi
    done

    restart_nums=${failed_restart_nums:-$flv_restart_nums}

    IFS=" " read -ra chnl_stream_links_arr <<< "$chnl_stream_links"

    if [ "${#chnl_stream_links_arr[@]}" -gt $restart_nums ] 
    then
        restart_nums=${#chnl_stream_links_arr[@]}
    fi

    for((restart_i=0;restart_i<restart_nums;restart_i++))
    do
        if [ "$restart_i" -gt 0 ] && [[ ${#chnl_stream_links_arr[@]} -gt 1 ]] 
        then
            chnl_stream_links="${chnl_stream_links#* } $chnl_stream_link"
            chnl_stream_link=${chnl_stream_links%% *}
        fi

        chnl_mac=""
        if [[ ${chnl_stream_link##*|} =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
        then
            chnl_domain=${chnl_stream_link%%|*}
            chnl_mac=${chnl_stream_link##*|}
            chnl_cmd=${chnl_stream_link%|*}
            chnl_cmd=${chnl_cmd##*|}

            to_try=0
            for xc_domain in "${xtream_codes_domains[@]}"
            do
                if [ "$xc_domain" == "$chnl_domain" ] 
                then
                    to_try=1
                    for domain in "${domains_tried[@]}"
                    do
                        if [ "$domain" == "$chnl_domain" ] 
                        then
                            to_try=0
                            break
                        fi
                    done
                    break
                fi
            done

            xc_chnl_found=0
            if [ "$to_try" -eq 1 ] 
            then
                for xc_chnl_mac in "${xc_chnls_mac[@]}"
                do
                    if [ "$xc_chnl_mac" == "$chnl_domain/$chnl_mac" ] 
                    then
                        xc_chnl_found=1
                        break
                    fi
                done
            fi

            if [ "$xc_chnl_found" -eq 1 ] 
            then
                domains_tried+=("$chnl_domain")
                try_success=0
                MonitorTryAccounts
                if [ "$try_success" -eq 1 ] 
                then
                    MonitorFlvRestartSuccess
                else
                    if [[ $restart_i -eq $((restart_nums-1)) ]] 
                    then
                        MonitorFlvRestartFail
                    else
                        continue
                    fi
                fi
                break
            fi

            token=""
            access_token=""
            profile=""
            chnl_user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
            server="http://$chnl_domain"
            mac=$(Urlencode "$chnl_mac")
            timezone=$(Urlencode "Europe/Amsterdam")
            chnl_cookies="mac=$mac; stb_lang=en; timezone=$timezone"
            token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
            profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"
            genres_url="$server/portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml"

            token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                | $JQ_FILE -r '.js.token' || true)
            if [ -z "$token" ] 
            then
                if [[ $restart_i -eq $((restart_nums-1)) ]] 
                then
                    MonitorFlvRestartFail
                    break
                else
                    continue
                fi
            fi
            access_token=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="Authorization: Bearer $token" \
                --header="Cookie: $chnl_cookies" "$token_url" -qO- \
                | $JQ_FILE -r '.js.token' || true)
            if [ -z "$access_token" ] 
            then
                if [[ $restart_i -eq $((restart_nums-1)) ]] 
                then
                    MonitorFlvRestartFail
                    break
                else
                    continue
                fi
            fi
            chnl_headers="Authorization: Bearer $access_token"
            profile=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                --header="$chnl_headers" \
                --header="Cookie: $chnl_cookies" "$profile_url" -qO- || true)
            if [ -z "$profile" ] 
            then
                if [[ $restart_i -eq $((restart_nums-1)) ]] 
                then
                    MonitorFlvRestartFail
                    break
                else
                    continue
                fi
            fi

            if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
            then
                if [ "$to_try" -eq 1 ] 
                then
                    domains_tried+=("$chnl_domain")
                    try_success=0
                    MonitorTryAccounts
                    if [ "$try_success" -eq 1 ] 
                    then
                        MonitorFlvRestartSuccess
                    else
                        MonitorFlvRestartFail
                    fi
                else
                    MonitorFlvRestartFail
                fi
                break
            else
                create_link_url="$server/portal.php?type=itv&action=create_link&cmd=$chnl_cmd&series=&forced_storage=undefined&disable_ad=0&download=0&JsHttpRequest=1-xml"
                chnl_stream_link=$(wget --timeout=10 --tries=3 --user-agent="$chnl_user_agent" --no-check-certificate \
                    --header="$chnl_headers" \
                    --header="Cookie: $chnl_cookies" "$create_link_url" -qO- \
                    | $JQ_FILE -r '.js.cmd')
                chnl_stream_link=${chnl_stream_link#* }
                IFS="/" read -ra s <<< "$chnl_stream_link"
                if [ "${s[3]}" == "live" ] 
                then
                    chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[5]}/${s[-1]}"
                else
                    chnl_stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[-1]}"
                fi
                if [[ $chnl_stream_links == *" "* ]] 
                then
                    chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$chnl_mac ${chnl_stream_links#* }"
                else
                    chnl_stream_links="$chnl_domain|$chnl_stream_link|$chnl_cmd|$chnl_mac"
                fi
            fi
        else
            to_try=0
            if [[ $chnl_stream_link =~ http://([^/]+)/([^/]+)/([^/]+)/ ]] 
            then
                chnl_domain=${BASH_REMATCH[1]}

                for xc_domain in "${xtream_codes_domains[@]}"
                do
                    if [ "$xc_domain" == "$chnl_domain" ] 
                    then
                        to_try=1
                        for domain in "${domains_tried[@]}"
                        do
                            if [ "$domain" == "$chnl_domain" ] 
                            then
                                to_try=0
                                break
                            fi
                        done
                        break
                    fi
                done
            fi

            xc_chnl_found=0
            if [ "$to_try" -eq 1 ] 
            then
                to_try=0
                if [ "${BASH_REMATCH[2]}" == "live" ] && [[ $chnl_stream_link =~ http://([^/]+)/live/([^/]+)/([^/]+)/ ]] 
                then
                    chnl_account="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
                else
                    chnl_account="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
                fi
                for xc_chnl in "${xc_chnls[@]}"
                do
                    if [ "$xc_chnl" == "$chnl_domain/$chnl_account" ] 
                    then
                        xc_chnl_found=1
                        break
                    fi
                done
            fi

            if [ "$xc_chnl_found" -eq 1 ]  
            then
                domains_tried+=("$chnl_domain")
                try_success=0
                MonitorTryAccounts
                if [ "$try_success" -eq 1 ] 
                then
                    MonitorFlvRestartSuccess
                else
                    if [[ $restart_i -eq $((restart_nums-1)) ]] 
                    then
                        MonitorFlvRestartFail
                    else
                        continue
                    fi
                fi
                break
            fi
        fi

        action="skip"
        StopChannel
        if [ "$anti_leech_yn" == "yes" ] && [ "$anti_leech_restart_flv_changes_yn" == "yes" ] 
        then
            stream_name=${chnl_flv_push_link##*/}
            new_stream_name=$(RandStr)
            while [[ -n $($JQ_FILE '.channels[]|select(.flv_push_link=="'"${chnl_flv_push_link%/*}/$new_stream_name"'")' "$CHANNELS_FILE") ]] 
            do
                new_stream_name=$(RandStr)
            done
            chnl_flv_push_link="${chnl_flv_push_link%/*}/$new_stream_name"
            monitor_flv_push_links[i]=$chnl_flv_push_link
            if [ -n "$chnl_flv_pull_link" ] 
            then
                chnl_flv_pull_link=${chnl_flv_pull_link//stream=$stream_name/stream=$new_stream_name}
                monitor_flv_pull_links[i]=$chnl_flv_pull_link
            fi
        fi
        StartChannel
        sleep 15
        GetChannelInfo

        if [ "$chnl_flv_status" == "on" ] 
        then
            audio=0
            video=0
            while IFS= read -r line 
            do
                if [[ $line == *"codec_type=audio"* ]] 
                then
                    audio=1
                elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                then
                    audio=0
                elif [[ $line == *"codec_type=video"* ]] 
                then
                    video=1
                fi
            done < <($FFPROBE -i "${chnl_flv_pull_link:-$chnl_flv_push_link}" -rw_timeout 10000000 -show_streams -loglevel quiet || true)
            if [ "$audio" -eq 1 ] && [ "$video" -eq 1 ] 
            then
                MonitorFlvRestartSuccess
                break
            fi
        fi

        if [ "$to_try" -eq 1 ] 
        then
            domains_tried+=("$chnl_domain")
            try_success=0
            MonitorTryAccounts
            if [ "$try_success" -eq 1 ] 
            then
                MonitorFlvRestartSuccess
                break
            fi
        fi

        if [[ $restart_i -eq $((restart_nums - 1)) ]] 
        then
            MonitorFlvRestartFail
        fi
    done
}

Monitor()
{
    trap '' HUP INT
    trap 'MonitorError $LINENO' ERR

    trap '
        [ -e "/tmp/monitor.lockdir/$BASHPID" ] && rm -f "/tmp/monitor.lockdir/$BASHPID"
        exit 
    ' TERM

    mkdir -p "/tmp/monitor.lockdir" 
    printf '%s' "" > "/tmp/monitor.lockdir/$BASHPID"

    mkdir -p "$LIVE_ROOT"
    printf '%s\n' "$date_now 监控启动成功 PID $BASHPID !" >> "$MONITOR_LOG"

    FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
    FFPROBE="$FFMPEG_ROOT/ffprobe"
    GetXtreamCodesDomains
    monitor=1
    flv_failed=()
    flv_recheck_time=()
    hls_failed=()
    hls_recheck_time=()
    while true
    do
        printf -v now '%(%s)T'
        if [ "$recheck_period" -gt 0 ] 
        then
            for((i=0;i<${#flv_recheck_time[@]};i++));
            do
                if [ "$now" -ge "${flv_recheck_time[i]}" ] 
                then
                    found=0
                    for flv_num in "${flv_nums_arr[@]}"
                    do
                        if [ "$flv_num" == "${flv_failed[i]}" ] 
                        then
                            found=1
                        fi
                    done
                    [ "$found" -eq 0 ] && flv_nums_arr+=("${flv_failed[i]}")
                fi
            done

            for((i=0;i<${#hls_recheck_time[@]};i++));
            do
                if [ "$now" -ge "${hls_recheck_time[i]}" ] 
                then
                    found=0
                    for dir_name in "${monitor_dir_names_chosen[@]}"
                    do
                        if [ "$dir_name" == "${hls_failed[i]}" ] 
                        then
                            found=1
                        fi
                    done
                    [ "$found" -eq 0 ] && monitor_dir_names_chosen+=("${hls_failed[i]}")
                fi
            done
        fi

        if [ "$anti_leech_yn" == "yes" ] && [ "$anti_leech_restart_nums" -gt 0 ] && [ "${rand_restart_flv_done:-}" != 0 ] && [ "${rand_restart_hls_done:-}" != 0 ] 
        then
            current_minute_old=${current_minute:-}
            current_hour_old=${current_hour:-25}
            printf -v current_time '%(%H:%M)T'
            current_hour=${current_time%:*}
            current_minute=${current_time#*:}

            if [ "${current_hour:0:1}" -eq 0 ] 
            then
                current_hour=${current_hour:1}
            fi
            if [ "${current_minute:0:1}" -eq 0 ] 
            then
                current_minute=${current_minute:1}
            fi

            if [ "$current_hour" != "$current_hour_old" ] 
            then
                minutes=()
                skip_hour=""
            fi

            if [ "${#minutes[@]}" -gt 0 ] && [ "$current_minute" -gt "$current_minute_old" ]
            then
                declare -a new_array
                for minute in "${minutes[@]}"
                do
                    if [ "$minute" -gt "$current_minute" ] 
                    then
                        new_array+=("$minute")
                    fi

                    if [ "$minute" -eq "$current_minute" ] 
                    then
                        rand_restart_flv_done=0
                        rand_restart_hls_done=0
                    fi
                done
                minutes=("${new_array[@]}")
                unset new_array
                [ "${#minutes[@]}" -eq 0 ] && skip_hour=$current_hour
            fi

            if [ "${#minutes[@]}" -eq 0 ] && [ "$current_minute" -lt 59 ] && [ "$current_hour" != "${skip_hour:-}" ]
            then
                rand_restart_flv_done=""
                rand_restart_hls_done=""
                minutes_left=$((59 - current_minute))
                restart_nums=$anti_leech_restart_nums
                [ "$restart_nums" -gt "$minutes_left" ] && restart_nums=$minutes_left
                minute_gap=$((minutes_left / anti_leech_restart_nums / 2))
                [ "$minute_gap" -eq 0 ] && minute_gap=1
                for((i=0;i<restart_nums;i++));
                do
                    while true 
                    do
                        rand_minute=$((RANDOM % 60))
                        if [ "$rand_minute" -gt "$current_minute" ] 
                        then
                            valid=1
                            for minute in "${minutes[@]}"
                            do
                                if [ "$minute" -eq "$rand_minute" ] 
                                then
                                    valid=0
                                    break
                                elif [ "$minute" -gt "$rand_minute" ] && [ "$((minute-rand_minute))" -lt "$minute_gap" ]
                                then
                                    valid=0
                                    break
                                elif [ "$rand_minute" -gt "$minute" ] && [ "$((rand_minute-minute))" -lt "$minute_gap" ]
                                then
                                    valid=0
                                    break
                                fi
                            done
                            if [ "$valid" -eq 1 ] 
                            then
                                break
                            fi
                        fi
                    done
                    minutes+=("$rand_minute")
                done
                printf '%s\n' "$current_time 计划重启时间 ${minutes[*]}" >> "$MONITOR_LOG"
            fi
        fi

        if [ -n "${flv_nums:-}" ] 
        then
            kind="flv"
            rand_found=0
            if [ -n "${rand_restart_flv_done:-}" ] && [ "$rand_restart_flv_done" -eq 0 ] && [ "${#flv_nums_arr[@]}" -eq 0 ]
            then
                rand_restart_flv_done=1
                rand_found=1
            fi
            for flv_num in "${flv_nums_arr[@]}"
            do
                chnl_flv_pull_link=${monitor_flv_pull_links[$((flv_num-1))]}
                chnl_flv_push_link=${monitor_flv_push_links[$((flv_num-1))]}

                audio=0
                video=0
                while IFS= read -r line 
                do
                    if [[ $line == *"codec_type=audio"* ]] 
                    then
                        audio=1
                    elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                    then
                        audio=0
                    elif [[ $line == *"codec_type=video"* ]] 
                    then
                        video=1
                    fi
                done < <($FFPROBE -i "${chnl_flv_pull_link:-$chnl_flv_push_link}" -rw_timeout 10000000 -show_streams -loglevel quiet || true)

                if [ "$audio" -eq 0 ] || [ "$video" -eq 0 ]
                then
                    GetChannelInfo
                    if [ -n "${flv_first_fail:-}" ] 
                    then
                        printf -v flv_fail_time '%(%s)T'
                        if [ $((flv_fail_time - flv_first_fail)) -gt "$flv_delay_seconds" ] 
                        then
                            flv_first_fail=""
                            printf -v date_now '%(%m-%d %H:%M:%S)T'
                            printf '%s\n' "$date_now $chnl_channel_name FLV 超时重启" >> "$MONITOR_LOG"
                            MonitorFlvRestartChannel
                        fi
                    else
                        if [ "$chnl_flv_status" == "off" ] 
                        then
                            printf -v date_now '%(%m-%d %H:%M:%S)T'
                            printf '%s\n' "$date_now $chnl_channel_name FLV 恢复启动" >> "$MONITOR_LOG"
                            MonitorFlvRestartChannel
                        else
                            printf -v flv_first_fail '%(%s)T'
                        fi

                        new_array=("$flv_num")
                        for element in "${flv_nums_arr[@]}"
                        do
                            [ "$element" != "$flv_num" ] && new_array+=("$element")
                        done
                        flv_nums_arr=("${new_array[@]}")
                        unset new_array
                    fi
                    break 1
                else
                    flv_first_fail=""

                    if [ -n "${rand_restart_flv_done:-}" ] && [ "$rand_restart_flv_done" -eq 0 ]
                    then
                        rand_found=1
                        printf -v date_now '%(%m-%d %H:%M:%S)T'
                        printf '%s\n' "$date_now $chnl_channel_name FLV 随机重启" >> "$MONITOR_LOG"
                        MonitorFlvRestartChannel
                    fi
                fi
            done
            if [ "$rand_found" -eq 1 ] 
            then
                rand_restart_flv_done=1
            fi
        else
            rand_restart_flv_done=1
        fi

        kind=""

        if ls -A $LIVE_ROOT/* > /dev/null 2>&1
        then
            exclude_command=""
            for exclude_path in "${exclude_paths[@]}"
            do
                exclude_command="$exclude_command -not \( -path $exclude_path -prune \)"
            done

            if [ -n "${hls_max_seg_size:-}" ] 
            then
                
                largest_file=$(find "$LIVE_ROOT" $exclude_command -type f -printf "%s %p\n" | sort -n | tail -1 || true)
                if [ -n "${largest_file:-}" ] 
                then
                    largest_file_size=${largest_file%% *}
                    largest_file_path=${largest_file#* }
                    output_dir_name=${largest_file_path#*$LIVE_ROOT/}
                    output_dir_name=${output_dir_name%%/*}
                    if [ "$largest_file_size" -gt $(( hls_max_seg_size * 1000000)) ]
                    then
                        GetChannelInfo
                        if [ -n "$chnl_live" ] 
                        then
                            printf '%s\n' "$chnl_channel_name 文件过大重启" >> "$MONITOR_LOG"
                            MonitorHlsRestartChannel
                        else
                            exclude_paths+=("$LIVE_ROOT/$output_dir_name")
                        fi
                    fi
                fi
            fi
        fi

        if [ "${#monitor_dir_names_chosen[@]}" -gt 0 ] 
        then
            rand_found=0
            if [ -z "${loop:-}" ] || [ "$loop" -eq 10 ]
            then
                loop=1
            else
                ((loop++))
            fi
            while IFS= read -r old_file_path
            do
                if [[ $old_file_path == *"_master.m3u8" ]] || [[ $old_file_path == *".key" ]] || [[ $old_file_path == *".keyinfo" ]]
                then
                    continue
                fi
                output_dir_name=${old_file_path#*$LIVE_ROOT/}
                output_dir_name=${output_dir_name%%/*}
                for dir_name in "${monitor_dir_names_chosen[@]}"
                do
                    if [ "$dir_name" == "$output_dir_name" ] 
                    then
                        GetChannelInfo
                        if [ -n "$chnl_live" ] 
                        then
                            printf '%s\n' "$chnl_channel_name 超时重启" >> "$MONITOR_LOG"
                            MonitorHlsRestartChannel
                            break 2
                        else
                            exclude_paths+=("$LIVE_ROOT/$output_dir_name")
                        fi
                    fi
                done
            done < <(find "$LIVE_ROOT/"* $exclude_command \! -newermt "-$hls_delay_seconds seconds" || true)

            GetChannelsInfo

            for output_dir_name in "${monitor_dir_names_chosen[@]}"
            do
                found=0
                for((i=0;i<chnls_count;i++));
                do
                    if [ "${chnls_output_dir_name[i]}" == "$output_dir_name" ] 
                    then
                        found=1

                        if [ "${chnls_status[i]}" == "off" ] 
                        then
                            if [ "${chnls_stream_link[i]:0:23}" == "https://www.youtube.com" ] || [ "${chnls_stream_link[i]:0:19}" == "https://youtube.com" ]
                            then
                                sleep 10
                            else
                                sleep 5
                            fi
                            chnl_status=""
                            GetChannelInfo
                            if [ -z "$chnl_status" ] 
                            then
                                declare -a new_array
                                for element in "${monitor_dir_names_chosen[@]}"
                                do
                                    [ "$element" != "$output_dir_name" ] && new_array+=("$element")
                                done
                                monitor_dir_names_chosen=("${new_array[@]}")
                                unset new_array
                                break 2
                            fi
                            if [ "$chnl_status" == "off" ] 
                            then
                                printf '%s\n' "$chnl_channel_name 开启" >> "$MONITOR_LOG"
                                MonitorHlsRestartChannel
                                break 2
                            fi
                        fi

                        if [ "${rand_restart_hls_done:-}" != 0 ] && [ "$anti_leech_yn" == "yes" ] && [ "${chnls_encrypt[i]}" == "yes" ] && [[ $((now-chnls_key_time[i])) -gt $hls_key_period ]] && ls -A "$LIVE_ROOT/$output_dir_name/"*.key > /dev/null 2>&1
                        then
                            while IFS= read -r old_key 
                            do
                                old_key_name=${old_key##*/}
                                old_key_name=${old_key_name%%.*}
                                [ "$old_key_name" != "${chnls_key_name[i]}" ] && rm -f "$old_key"
                            done < <(find "$LIVE_ROOT/$output_dir_name/"*.key \! -newermt "-$hls_key_expire_seconds seconds" || true)

                            new_key_name=$(RandStr)
                            if openssl rand 16 > "$LIVE_ROOT/$output_dir_name/$new_key_name.key" 
                            then
                                if [ "${chnls_encrypt_session[i]}" == "yes" ] 
                                then
                                    echo -e "/keys?key=$new_key_name&channel=$output_dir_name\n$LIVE_ROOT/$output_dir_name/$new_key_name.key\n$(openssl rand -hex 16)" > "$LIVE_ROOT/$output_dir_name/${chnls_keyinfo_name[i]}.keyinfo"
                                else
                                    echo -e "$new_key_name.key\n$LIVE_ROOT/$output_dir_name/$new_key_name.key\n$(openssl rand -hex 16)" > "$LIVE_ROOT/$output_dir_name/${chnls_keyinfo_name[i]}.keyinfo"
                                fi
                                JQ update "$CHANNELS_FILE" '(.channels[]|select(.pid=='"${chnls_pid[i]}"')|.key_name)="'"$new_key_name"'"
                                |(.channels[]|select(.pid=='"${chnls_pid[i]}"')|.key_time)='"$now"''
                            else
                                break 2
                            fi
                        fi

                        if [ "$loop" -eq 1 ] && { [ "$anti_leech_yn" == "no" ] || [ "${chnls_encrypt[i]}" == "no" ]; }
                        then
                            if [ "${chnls_encrypt[i]}" == "yes" ] && [ -e "$LIVE_ROOT/$output_dir_name/${chnls_keyinfo_name[i]}.keyinfo" ] && [ -e "$LIVE_ROOT/$output_dir_name/${chnls_key_name[i]}.key" ]
                            then
                                line_no=0
                                while IFS= read -r line 
                                do
                                    line_no=$((line_no+1))
                                    if [ "$line_no" -eq 3 ] 
                                    then
                                        iv_hex=$line
                                    fi
                                done < "$LIVE_ROOT/$output_dir_name/${chnls_keyinfo_name[i]}.keyinfo"

                                encrypt_key=$(hexdump -e '16/1 "%02x"' < "$LIVE_ROOT/$output_dir_name/${chnls_key_name[i]}.key")
                                encrypt_command="-key $encrypt_key -iv $iv_hex"
                            else
                                encrypt_command=""
                            fi

                            audio=0
                            video=0
                            video_bitrate=0
                            bitrate_check=0
                            f_count=1
                            for f in "$LIVE_ROOT/$output_dir_name/${chnls_seg_dir_name[i]}/"*.ts
                            do
                                ((f_count++))
                            done

                            f_num=$((f_count/2))
                            f_count=1

                            for f in "$LIVE_ROOT/$output_dir_name/${chnls_seg_dir_name[i]}/"*.ts
                            do
                                if [ "$f_count" -lt "$f_num" ] 
                                then
                                    ((f_count++))
                                    continue
                                fi
                                [ -n "$encrypt_command" ] && f="crypto:$f"
                                while IFS= read -r line 
                                do
                                    if [[ $line == *"codec_type=video"* ]] 
                                    then
                                        video=1
                                    elif [ "$bitrate_check" -eq 0 ] && [ "$video" -eq 1 ] && [[ $line == *"bit_rate="* ]] 
                                    then
                                        line=${line#*bit_rate=}
                                        video_bitrate=${line//N\/A/$hls_min_bitrates}
                                        bitrate_check=1
                                    elif [[ $line == *"codec_type=audio"* ]] 
                                    then
                                        audio=1
                                    elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                                    then
                                        audio=0
                                    fi
                                done < <($FFPROBE $encrypt_command -i "$f" -show_streams -loglevel quiet || true)
                                break
                            done

                            if [ "$audio" -eq 0 ] || [ "$video" -eq 0 ] || [[ $video_bitrate -lt $hls_min_bitrates ]]
                            then
                                [ -n "$encrypt_command" ] && f="crypto:$f"
                                fail_count=1
                                f_count=1
                                for f in "$LIVE_ROOT/$output_dir_name/${chnls_seg_dir_name[i]}/"*.ts
                                do
                                    if [ "$f_count" -lt "$f_num" ] 
                                    then
                                        ((f_count++))
                                        continue
                                    fi
                                    [ ! -e "$f" ] && continue
                                    audio=0
                                    video=0
                                    video_bitrate=0
                                    bitrate_check=0
                                    while IFS= read -r line 
                                    do
                                        if [[ $line == *"codec_type=video"* ]] 
                                        then
                                            video=1
                                        elif [ "$bitrate_check" -eq 0 ] && [ "$video" -eq 1 ] && [[ $line == *"bit_rate="* ]] 
                                        then
                                            line=${line#*bit_rate=}
                                            video_bitrate=${line//N\/A/$hls_min_bitrates}
                                            bitrate_check=1
                                        elif [[ $line == *"codec_type=audio"* ]] 
                                        then
                                            audio=1
                                        elif [[ $line == *"sample_fmt=unknown"* ]] || [[ $line == *"sample_rate=0"* ]] || [[ $line == *"channels=0"* ]] 
                                        then
                                            audio=0
                                        fi
                                    done < <($FFPROBE $encrypt_command -i "$f" -show_streams -loglevel quiet || true)

                                    if [ "$audio" -eq 0 ] || [ "$video" -eq 0 ] || [[ $video_bitrate -lt $hls_min_bitrates ]]
                                    then
                                        ((fail_count++))
                                    fi
                                    if [ "$fail_count" -gt 3 ] 
                                    then
                                        GetChannelInfo
                                        printf '%s\n' "$chnl_channel_name 比特率过低重启" >> "$MONITOR_LOG"
                                        MonitorHlsRestartChannel
                                        break 2
                                    fi
                                done
                            fi
                        fi
                        break 1
                    fi
                done

                if [ "$found" -eq 0 ] 
                then
                    declare -a new_array
                    for element in "${monitor_dir_names_chosen[@]}"
                    do
                        [ "$element" != "$output_dir_name" ] && new_array+=("$element")
                    done
                    monitor_dir_names_chosen=("${new_array[@]}")
                    unset new_array
                    break 1
                elif [ -n "${rand_restart_hls_done:-}" ] && [ "$rand_restart_hls_done" -eq 0 ] 
                then
                    rand_found=1
                    GetChannelInfo
                    printf '%s\n' "$chnl_channel_name HLS 随机重启" >> "$MONITOR_LOG"
                    MonitorHlsRestartChannel
                fi
            done

            if [ "$rand_found" -eq 1 ] 
            then
                rand_restart_hls_done=1
            fi
        else
            rand_restart_hls_done=1
        fi

        sleep 10
    done
}

AntiLeech()
{
    Println "是否开启防盗链? [y/N]"
    read -p "(默认: ${d_anti_leech}): " anti_leech_yn
    anti_leech_yn=${anti_leech_yn:-$d_anti_leech}
    if [[ $anti_leech_yn == [Yy] ]] 
    then
        anti_leech_yn="yes"

        Println "请输入每小时随机重启次数 (大于等于0)"
        while read -p "(默认: $d_anti_leech_restart_nums): " anti_leech_restart_nums
        do
            case $anti_leech_restart_nums in
                "") anti_leech_restart_nums=$d_anti_leech_restart_nums && break
                ;;
                *[!0-9]*) Println "$error 请输入正确的数字\n"
                ;;
                *) 
                    if [ "$anti_leech_restart_nums" -ge 0 ]
                    then
                        break
                    else
                        Println "$error 请输入正确的数字(大于等于0)\n"
                    fi
                ;;
            esac
        done

        if [ "$anti_leech_restart_nums" -gt 0 ] 
        then
            Println "是否下个小时开始随机重启？[y/N]"
            read -p "(默认: N): " anti_leech_restart_next_hour_yn
            anti_leech_restart_next_hour_yn=${anti_leech_restart_next_hour_yn:-N}
            if [[ $anti_leech_restart_next_hour_yn == [Yy] ]] 
            then
                printf -v current_hour '%(%-H)T'
                skip_hour=$current_hour
                minutes=()
            fi
        fi

        if [ -n "${flv_nums:-}" ] 
        then
            Println "是否每当重启 FLV 频道更改成随机的推流和拉流地址？[y/N]"
            read -p "(默认: $d_anti_leech_restart_flv_changes): " anti_leech_restart_flv_changes_yn
            anti_leech_restart_flv_changes_yn=${anti_leech_restart_flv_changes_yn:-$d_anti_leech_restart_flv_changes}
            if [[ $anti_leech_restart_flv_changes_yn == [Yy] ]] 
            then
                anti_leech_restart_flv_changes_yn="yes"
            else
                anti_leech_restart_flv_changes_yn="no"
            fi
        else
            anti_leech_restart_flv_changes_yn=$d_anti_leech_restart_flv_changes_yn
        fi

        if [ -n "$hls_nums" ] 
        then
            Println "是否每当重启 HLS 频道更改成随机的 m3u8 名称, 段名称, key 名称 ? [y/N]"
            read -p "(默认: $d_anti_leech_restart_hls_changes): " anti_leech_restart_hls_changes_yn
            anti_leech_restart_hls_changes_yn=${anti_leech_restart_hls_changes_yn:-$d_anti_leech_restart_hls_changes}
            if [[ $anti_leech_restart_hls_changes_yn == [Yy] ]] 
            then
                anti_leech_restart_hls_changes_yn="yes"
            else
                anti_leech_restart_hls_changes_yn="no"
            fi

            Println "每隔多少秒更改加密频道的 key ? "
            read -p "(默认: $d_hls_key_period): " hls_key_period
            hls_key_period=${hls_key_period:-$d_hls_key_period}
            hls_key_expire_seconds=$((hls_key_period+hls_delay_seconds))
        else
            anti_leech_restart_hls_changes_yn=$d_anti_leech_restart_hls_changes_yn
        fi
    else
        anti_leech_yn="no"
        anti_leech_restart_nums=$d_anti_leech_restart_nums
        anti_leech_restart_flv_changes_yn=$d_anti_leech_restart_flv_changes_yn
        anti_leech_restart_hls_changes_yn=$d_anti_leech_restart_hls_changes_yn
    fi
}

RecheckPeriod()
{
    Println "设置重启频道失败后定时检查直播源(如可用即开启频道)的间隔时间(s)"
    echo -e "$tip 输入 0 关闭检查\n"
    while read -p "(默认: $d_recheck_period_text): " recheck_period
    do
        case $recheck_period in
            "") recheck_period=$d_recheck_period && break
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$recheck_period" -ge 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于等于0)\n"
                fi
            ;;
        esac
    done
}

MonitorSet()
{
    flv_count=0
    monitor_channel_names=()
    monitor_stream_links=()
    monitor_flv_push_links=()
    monitor_flv_pull_links=()
    monitor_dir_names_chosen=()
    GetChannelsInfo
    for((i=0;i<chnls_count;i++));
    do
        if [ "${chnls_flv_status[i]}" == "on" ] && [ "${chnls_live[i]}" == "yes" ]
        then
            flv_count=$((flv_count+1))
            monitor_channel_names+=("${chnls_channel_name[i]}")
            monitor_stream_links+=("${chnls_stream_link[i]}")
            monitor_flv_push_links+=("${chnls_flv_push_link[i]}")
            monitor_flv_pull_links+=("${chnls_flv_pull_link[i]}")
        fi
    done
    
    if [ "$flv_count" -gt 0 ] 
    then
        GetDefault
        Println "请选择需要监控的 FLV 推流频道(多个频道用空格分隔 比如: 5 7 9-11)\n"

        result=""
        for((i=0;i<flv_count;i++));
        do
            if [ "$i" -lt 9 ] 
            then
                blank=" "
            else
                blank=""
            fi
            flv_pull_link=${monitor_flv_pull_links[i]}
            result=$result"  $green$((i+1)).$plain $blank${monitor_channel_names[i]}\n      源: ${monitor_stream_links[i]}\n      pull: ${flv_pull_link:-无}\n\n"
        done

        Println "$result"
        Println "  $green$((flv_count+1)).$plain 全部"
        Println "  $green$((flv_count+2)).$plain 不设置\n"
        while read -p "(默认: 不设置): " flv_nums
        do
            if [ -z "$flv_nums" ] || [ "$flv_nums" == $((flv_count+2)) ] 
            then
                flv_nums=""
                break
            fi

            if [ "$flv_nums" == $((flv_count+1)) ] 
            then
                flv_nums=""
                for((i=1;i<=flv_count;i++));
                do
                    [ -n "$flv_nums" ] && flv_nums="$flv_nums "
                    flv_nums="$flv_nums$i"
                done
            fi

            IFS=" " read -ra flv_nums_arr <<< "$flv_nums"

            error_no=0
            for flv_num in "${flv_nums_arr[@]}"
            do
                case "$flv_num" in
                    *"-"*)
                        flv_num_start=${flv_num%-*}
                        flv_num_end=${flv_num#*-}
                        if [[ $flv_num_start == *[!0-9]* ]] || [[ $flv_num_end == *[!0-9]* ]] || [ "$flv_num_start" -eq 0 ] || [ "$flv_num_end" -eq 0 ] || [ "$flv_num_end" -gt "$flv_count" ] || [ "$flv_num_start" -ge "$flv_num_end" ]
                        then
                            error_no=3
                        fi
                    ;;
                    *[!0-9]*)
                        error_no=1
                    ;;
                    *)
                        if [ "$flv_num" -lt 1 ] || [ "$flv_num" -gt "$flv_count" ] 
                        then
                            error_no=2
                        fi
                    ;;
                esac
            done

            case "$error_no" in
                1|2|3)
                    Println "$error 请输入正确的数字或直接回车 \n"
                ;;
                *)
                    declare -a new_array
                    for element in "${flv_nums_arr[@]}"
                    do
                        if [[ $element == *"-"* ]] 
                        then
                            start=${element%-*}
                            end=${element#*-}
                            for((i=start;i<=end;i++));
                            do
                                new_array+=("$i")
                            done
                        else
                            new_array+=("$element")
                        fi
                    done
                    flv_nums_arr=("${new_array[@]}")
                    unset new_array

                    Println "设置超时多少秒自动重启频道"
                    while read -p "(默认: $d_flv_delay_seconds秒): " flv_delay_seconds
                    do
                        case $flv_delay_seconds in
                            "") flv_delay_seconds=$d_flv_delay_seconds && break
                            ;;
                            *[!0-9]*) Println "$error 请输入正确的数字\n"
                            ;;
                            *) 
                                if [ "$flv_delay_seconds" -gt 0 ]
                                then
                                    break
                                else
                                    Println "$error 请输入正确的数字(大于0)\n"
                                fi
                            ;;
                        esac
                    done
                    break
                ;;
            esac
        done

        if [ -n "$flv_nums" ] 
        then
            Println "请输入尝试重启的次数"
            while read -p "(默认: $d_flv_restart_nums次): " flv_restart_nums
            do
                case $flv_restart_nums in
                    "") flv_restart_nums=$d_flv_restart_nums && break
                    ;;
                    *[!0-9]*) Println "$error 请输入正确的数字\n"
                    ;;
                    *) 
                        if [ "$flv_restart_nums" -gt 0 ]
                        then
                            break
                        else
                            Println "$error 请输入正确的数字(大于0)\n"
                        fi
                    ;;
                esac
            done
        fi
    fi

    if ! ls -A $LIVE_ROOT/* > /dev/null 2>&1
    then
        if [ "$flv_count" -eq 0 ] 
        then
            Println "$error 没有开启的频道！\n" && exit 1
        elif [ -z "${flv_delay_seconds:-}" ] 
        then
            Println "已取消...\n" && exit 1
        else
            RecheckPeriod
            AntiLeech
            JQ update "$CHANNELS_FILE" '(.default|.flv_delay_seconds)='"$flv_delay_seconds"'
            |(.default|.flv_restart_nums)='"$flv_restart_nums"'
            |(.default|.anti_leech)="'"$anti_leech_yn"'"
            |(.default|.anti_leech_restart_nums)='"$anti_leech_restart_nums"'
            |(.default|.anti_leech_restart_flv_changes)="'"$anti_leech_restart_flv_changes_yn"'"
            |(.default|.anti_leech_restart_hls_changes)="'"$anti_leech_restart_hls_changes_yn"'"
            |(.default|.recheck_period)='"$recheck_period"''
            return 0
        fi
    fi
    Println "请选择需要监控的 HLS 频道(多个频道用空格分隔 比如 5 7 9-11)\n"
    monitor_count=0
    monitor_dir_names=()
    exclude_paths=()
    [ -z "${d_hls_delay_seconds:-}" ] && GetDefault
    result=""
    for((i=0;i<chnls_count;i++));
    do
        if [ -e "$LIVE_ROOT/${chnls_output_dir_name[i]}" ] && [ "${chnls_live[i]}" == "yes" ] && [ "${chnls_seg_count[i]}" != 0 ]
        then
            monitor_count=$((monitor_count + 1))
            monitor_dir_names+=("${chnls_output_dir_name[i]}")
            result=$result"  $green$monitor_count.$plain ${chnls_channel_name[i]}\n\n"
        fi
    done

    Println "$result"
    Println "  $green$((monitor_count+1)).$plain 全部"
    Println "  $green$((monitor_count+2)).$plain 不设置\n"
    
    while read -p "(默认: 不设置): " hls_nums
    do
        if [ -z "$hls_nums" ] || [ "$hls_nums" == $((monitor_count+2)) ] 
        then
            hls_nums=""
            break
        fi
        IFS=" " read -ra hls_nums_arr <<< "$hls_nums"

        if [ "$hls_nums" == $((monitor_count+1)) ] 
        then
            monitor_dir_names_chosen=("${monitor_dir_names[@]}")

            Println "设置超时多少秒自动重启频道"
            echo -e "$tip 必须大于 段时长*段数目\n"
            while read -p "(默认: $d_hls_delay_seconds秒): " hls_delay_seconds
            do
                case $hls_delay_seconds in
                    "") hls_delay_seconds=$d_hls_delay_seconds && break
                    ;;
                    *[!0-9]*) Println "$error 请输入正确的数字\n"
                    ;;
                    *) 
                        if [ "$hls_delay_seconds" -gt 60 ]
                        then
                            break
                        else
                            Println "$error 请输入正确的数字(大于60)\n"
                        fi
                    ;;
                esac
            done
            break
        fi

        error_no=0
        for hls_num in "${hls_nums_arr[@]}"
        do
            case "$hls_num" in
                *"-"*)
                    hls_num_start=${hls_num%-*}
                    hls_num_end=${hls_num#*-}
                    if [[ $hls_num_start == *[!0-9]* ]] || [[ $hls_num_end == *[!0-9]* ]] || [ "$hls_num_start" -eq 0 ] || [ "$hls_num_end" -eq 0 ] || [ "$hls_num_end" -gt "$monitor_count" ] || [ "$hls_num_start" -ge "$hls_num_end" ]
                    then
                        error_no=3
                    fi
                ;;
                *[!0-9]*)
                    error_no=1
                ;;
                *)
                    if [ "$hls_num" -lt 1 ] || [ "$hls_num" -gt "$monitor_count" ] 
                    then
                        error_no=2
                    fi
                ;;
            esac
        done

        case "$error_no" in
            1|2)
                Println "$error 请输入正确的数字或直接回车 \n"
            ;;
            *)
                declare -a new_array
                for element in "${hls_nums_arr[@]}"
                do
                    if [[ $element == *"-"* ]] 
                    then
                        start=${element%-*}
                        end=${element#*-}
                        for((i=start;i<=end;i++));
                        do
                            new_array+=("$i")
                        done
                    else
                        new_array+=("$element")
                    fi
                done
                hls_nums_arr=("${new_array[@]}")
                unset new_array

                for hls_num in "${hls_nums_arr[@]}"
                do
                    monitor_dir_names_chosen+=("${monitor_dir_names[((hls_num - 1))]}")
                done

                Println "设置超时多少秒自动重启频道"
                echo -e "$tip 必须大于 段时长*段数目\n"
                while read -p "(默认: $d_hls_delay_seconds秒): " hls_delay_seconds
                do
                    case $hls_delay_seconds in
                        "") hls_delay_seconds=$d_hls_delay_seconds && break
                        ;;
                        *[!0-9]*) Println "$error 请输入正确的数字\n"
                        ;;
                        *) 
                            if [ "$hls_delay_seconds" -gt 60 ]
                            then
                                break
                            else
                                Println "$error 请输入正确的数字(大于60)\n"
                            fi
                        ;;
                    esac
                done

                break
            ;;
        esac
    done

    if [ -n "$hls_nums" ] 
    then
        Println "请输入最低比特率(kb/s),低于此数值会重启频道(除加密的频道)"
        while read -p "(默认: $d_hls_min_bitrates): " hls_min_bitrates
        do
            case $hls_min_bitrates in
                "") hls_min_bitrates=$d_hls_min_bitrates && break
                ;;
                *[!0-9]*) Println "$error 请输入正确的数字\n"
                ;;
                *) 
                    if [ "$hls_min_bitrates" -gt 0 ]
                    then
                        break
                    else
                        Println "$error 请输入正确的数字(大于0)\n"
                    fi
                ;;
            esac
        done

        hls_min_bitrates=$((hls_min_bitrates * 1000))
    fi

    Println "请输入允许的最大片段"
    while read -p "(默认: ${d_hls_max_seg_size}M): " hls_max_seg_size
    do
        case $hls_max_seg_size in
            "") hls_max_seg_size=$d_hls_max_seg_size && break
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$hls_max_seg_size" -gt 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于0)\n"
                fi
            ;;
        esac
    done

    Println "请输入尝试重启的次数"
    while read -p "(默认: $d_hls_restart_nums次): " hls_restart_nums
    do
        case $hls_restart_nums in
            "") hls_restart_nums=$d_hls_restart_nums && break
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$hls_restart_nums" -gt 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于0)\n"
                fi
            ;;
        esac
    done

    RecheckPeriod
    AntiLeech

    flv_delay_seconds=${flv_delay_seconds:-$d_flv_delay_seconds}
    flv_restart_nums=${flv_restart_nums:-$d_flv_restart_nums}
    hls_delay_seconds=${hls_delay_seconds:-$d_hls_delay_seconds}
    hls_min_bitrates=${hls_min_bitrates:-$d_hls_min_bitrates}
    hls_key_period=${hls_key_period:-$d_hls_key_period}
    JQ update "$CHANNELS_FILE" '(.default|.flv_delay_seconds)='"$flv_delay_seconds"'
    |(.default|.flv_restart_nums)='"$flv_restart_nums"'
    |(.default|.hls_delay_seconds)='"$hls_delay_seconds"'
    |(.default|.hls_min_bitrates)='"$((hls_min_bitrates / 1000))"'
    |(.default|.hls_max_seg_size)='"$hls_max_seg_size"'
    |(.default|.hls_restart_nums)='"$hls_restart_nums"'
    |(.default|.hls_key_period)='"$hls_key_period"'
    |(.default|.anti_leech)="'"$anti_leech_yn"'"
    |(.default|.anti_leech_restart_nums)='"$anti_leech_restart_nums"'
    |(.default|.anti_leech_restart_flv_changes)="'"$anti_leech_restart_flv_changes_yn"'"
    |(.default|.anti_leech_restart_hls_changes)="'"$anti_leech_restart_hls_changes_yn"'"
    |(.default|.recheck_period)='"$recheck_period"''
}

Progress(){
    echo -ne "$info 安装中，请等待..."
    while true
    do
        echo -n "."
        sleep 5
    done
}

InstallNginx()
{
    Println "$info 检查依赖，耗时可能会很长...\n"
    CheckRelease
    Progress &
    progress_pid=$!
    if [ "$release" == "rpm" ] 
    then
        yum -y install gcc gcc-c++ make >/dev/null 2>&1
        # yum groupinstall 'Development Tools'
        timedatectl set-timezone Asia/Shanghai >/dev/null 2>&1
        systemctl restart crond >/dev/null 2>&1
    else
        apt-get -y update >/dev/null 2>&1
        timedatectl set-timezone Asia/Shanghai >/dev/null 2>&1
        systemctl restart cron >/dev/null 2>&1
        apt-get -y install debconf-utils >/dev/null 2>&1
        echo '* libraries/restart-without-asking boolean true' | debconf-set-selections
        apt-get -y install software-properties-common pkg-config libssl-dev libghc-zlib-dev libcurl4-gnutls-dev libexpat1-dev unzip gettext build-essential >/dev/null 2>&1
    fi

    echo -n "...40%..."

    cd ~
    if [ ! -e "./pcre-8.44" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "https://ftp.pcre.org/pub/pcre/pcre-8.44.tar.gz" -qO "pcre-8.44.tar.gz"
        tar xzvf "pcre-8.44.tar.gz" >/dev/null 2>&1
    fi

    if [ ! -e "./zlib-1.2.11" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "https://www.zlib.net/zlib-1.2.11.tar.gz" -qO "zlib-1.2.11.tar.gz"
        tar xzvf "zlib-1.2.11.tar.gz" >/dev/null 2>&1
    fi

    if [ ! -e "./openssl-1.1.1g" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "https://www.openssl.org/source/openssl-1.1.1g.tar.gz" -qO "openssl-1.1.1g.tar.gz"
        tar xzvf "openssl-1.1.1g.tar.gz" >/dev/null 2>&1
    fi

    if [ ! -e "./nginx-http-flv-module-master" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "$FFMPEG_MIRROR_LINK/nginx-http-flv-module.zip" -qO "nginx-http-flv-module.zip"
        unzip "nginx-http-flv-module.zip" >/dev/null 2>&1
    fi

    while IFS= read -r line
    do
        if [[ $line == *"/download/"* ]] 
        then
            nginx_name=${line#*/download/}
            nginx_name=${nginx_name%%.tar.gz*}
        fi
    done < <( wget --timeout=10 --tries=3 --no-check-certificate "https://nginx.org/en/download.html" -qO- )

    if [ ! -e "./$nginx_name" ] 
    then
        wget --timeout=10 --tries=3 --no-check-certificate "https://nginx.org/download/$nginx_name.tar.gz" -qO "$nginx_name.tar.gz"
        tar xzvf "$nginx_name.tar.gz" >/dev/null 2>&1
    fi

    echo -n "...60%..."
    cd "$nginx_name/"
    ./configure --add-module=../nginx-http-flv-module-master --with-pcre=../pcre-8.44 --with-pcre-jit --with-zlib=../zlib-1.2.11 --with-openssl=../openssl-1.1.1g --with-openssl-opt=no-nextprotoneg --with-http_stub_status_module --with-http_ssl_module --with-http_realip_module --with-debug >/dev/null 2>&1
    echo -n "...80%..."
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    kill $progress_pid
    ln -sf /usr/local/nginx/sbin/nginx /usr/local/bin/
    echo -n "...100%" && echo
}

UninstallNginx()
{
    if [ ! -e "/usr/local/nginx" ] 
    then
        Println "$error Nginx 未安装 !\n" && exit 1
    fi

    Println "确定删除 nginx 包括所有配置文件，操作不可恢复？[y/N]"
    read -p "(默认: N): " nginx_uninstall_yn
    nginx_uninstall_yn=${nginx_uninstall_yn:-N}

    if [[ $nginx_uninstall_yn == [Yy] ]] 
    then
        nginx -s stop 2> /dev/null || true
        rm -rf /usr/local/nginx/
        Println "$info Nginx 卸载完成\n"
    else
        Println "已取消...\n" && exit 1
    fi
}

ToggleNginx()
{
    if [ ! -s "/usr/local/nginx/logs/nginx.pid" ] 
    then
        Println "nginx 未运行，是否开启？[Y/n]"
        read -p "(默认: Y): " nginx_start_yn
        nginx_start_yn=${nginx_start_yn:-Y}
        if [[ $nginx_start_yn == [Yy] ]] 
        then
            nginx
            Println "$info Nginx 已开启\n"
        else
            Println "已取消...\n" && exit 1
        fi
    else
        PID=$(< "/usr/local/nginx/logs/nginx.pid")
        if kill -0  "$PID" 2> /dev/null
        then
            Println "nginx 正在运行，是否关闭？[Y/n]"
            read -p "(默认: Y): " nginx_stop_yn
            nginx_stop_yn=${nginx_stop_yn:-Y}
            if [[ $nginx_stop_yn == [Yy] ]] 
            then
                nginx -s stop
                Println "$info Nginx 已关闭\n"
            else
                Println "已取消...\n" && exit 1
            fi
        else
            Println "nginx 未运行，是否开启？[Y/n]"
            read -p "(默认: Y): " nginx_start_yn
            nginx_start_yn=${nginx_start_yn:-Y}
            if [[ $nginx_start_yn == [Yy] ]] 
            then
                nginx
                Println "$info Nginx 已开启\n"
            else
                Println "已取消...\n" && exit 1
            fi
        fi
    fi
}

RestartNginx()
{
    PID=$(< "/usr/local/nginx/logs/nginx.pid")
    if kill -0  "$PID" 2> /dev/null 
    then
        nginx -s stop
        sleep 1
        nginx
    else
        nginx
    fi
}

AddXtreamCodesAccount()
{
    echo && read -p "请输入账号(需包含服务器地址)：" xtream_codes_input
    [ -z "$xtream_codes_input" ] && Println "已取消...\n" && exit 1

    if [[ $xtream_codes_input == *"username="* ]] 
    then
        domain=${xtream_codes_input#*http://}
        domain=${domain%%/*}
        username=${xtream_codes_input#*username=}
        username=${username%%&*}
        password=${xtream_codes_input#*password=}
        password=${password%%&*}
        ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
    elif [[ $xtream_codes_input =~ http://([^/]+)/([^/]+)/([^/]+)/ ]] 
    then
        if [ "${BASH_REMATCH[2]}" == "live" ] 
        then
            if [[ $line =~ http://([^/]+)/live/([^/]+)/([^/]+)/ ]] 
            then
                domain=${BASH_REMATCH[1]}
                username=${BASH_REMATCH[2]}
                password=${BASH_REMATCH[3]}
            else
                Println "$error 输入错误 !\n" && exit 1
            fi
        else
            domain=${BASH_REMATCH[1]}
            username=${BASH_REMATCH[2]}
            password=${BASH_REMATCH[3]}
        fi
        ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
    else
        Println "$error 输入错误 !\n" && exit 1
    fi

    [ -z "${ip:-}" ] && Println "$error 无法解析域名 !\n" && exit 1
    printf '%s\n' "$ip $domain $username:$password" >> "$XTREAM_CODES"

    if [ -e "$CHANNELS_FILE" ] 
    then
        while IFS= read -r line 
        do
            if [[ $line == *\"stream_link\":* ]] && [[ $line == *http://*/*/*/* ]]
            then
                line=${line#*: \"http://}
                chnl_domain=${line%%/*}
                if [ "$chnl_domain" == "$domain" ] 
                then
                    line=${line#*/}
                    username=${line%%/*}
                    if [ "$username" == "live" ] 
                    then
                        line=${line#*/}
                        username=${line%%/*}
                    fi
                    line=${line#*/}
                    password=${line%%/*}
                    printf '%s\n' "$ip $chnl_domain $username:$password" >> "$XTREAM_CODES"
                fi
            fi
        done < "$CHANNELS_FILE"
    fi

    Println "$info 账号添加成功 !\n"
}

ListXtreamCodes()
{
    [ ! -s "$XTREAM_CODES" ] && Println "$error 没有账号 !\n" && exit 1
    ips=()
    new_domains=()
    new_accounts=()
    while IFS= read -r line 
    do
        if [[ $line == *"username="* ]] 
        then
            domain=${line#*http://}
            domain=${domain%%/*}
            username=${line#*username=}
            username=${username%%&*}
            password=${line#*password=}
            password=${password%%&*}
            ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
            [ -z "$ip" ] && continue
            account="$username:$password"
        elif [[ $line =~ http://([^/]+)/([^/]+)/([^/]+)/ ]] 
        then
            if [ "${BASH_REMATCH[2]}" == "live" ] 
            then
                if [[ $line =~ http://([^/]+)/live/([^/]+)/([^/]+)/ ]] 
                then
                    domain=${BASH_REMATCH[1]}
                    username=${BASH_REMATCH[2]}
                    password=${BASH_REMATCH[3]}
                else
                    continue
                fi
            else
                domain=${BASH_REMATCH[1]}
                username=${BASH_REMATCH[2]}
                password=${BASH_REMATCH[3]}
            fi
            ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
            [ -z "$ip" ] && continue
            account="$username:$password"
        elif [[ ! $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]] 
        then
            if [[ $line =~ http://([^/]+)/ ]] 
            then
                stb_domain=${BASH_REMATCH[1]}
                continue
            elif [ -n "${stb_domain:-}" ] && [[ $line =~ (([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})) ]]
            then
                domain=$stb_domain
                ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
                [ -z "$ip" ] && continue
                mac_address=${BASH_REMATCH[1]}

                if [ -z "${test_mac:-}" ] 
                then
                    Println "$info 验证中 ..."
                    test_mac=1
                fi

                token=""
                access_token=""
                profile=""
                server="http://$domain"
                mac=$(Urlencode "$mac_address")
                timezone=$(Urlencode "Europe/Amsterdam")
                token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
                profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"

                token=$(wget --timeout=10 --tries=3 --user-agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)" --no-check-certificate \
                    --header="Cookie: mac=$mac; stb_lang=en; timezone=$timezone" "$token_url" -qO- \
                    | $JQ_FILE -r '.js.token' || true)
                if [ -z "$token" ] 
                then
                    Println "$error 无法连接 $domain"
                    stb_domain=""
                    continue
                fi
                access_token=$(wget --timeout=10 --tries=3 --user-agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)" --no-check-certificate \
                    --header="Authorization: Bearer $token" \
                    --header="Cookie: mac=$mac; stb_lang=en; timezone=$timezone" "$token_url" -qO- \
                    | $JQ_FILE -r '.js.token' || true)
                if [ -z "$access_token" ] 
                then
                    Println "$error 无法连接 $domain"
                    stb_domain=""
                    continue
                fi
                profile=$(wget --timeout=10 --tries=3 --user-agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)" --no-check-certificate \
                    --header="Authorization: Bearer $access_token" \
                    --header="Cookie: mac=$mac; stb_lang=en; timezone=$timezone" "$profile_url" -qO- || true)
                if [ -z "$profile" ] 
                then
                    Println "$error 无法连接 $domain"
                    stb_domain=""
                    continue
                fi

                if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
                then
                    Println "$error $mac_address 地址错误!"
                    continue
                else
                    account=$mac_address
                fi
            else
                stb_domain=""
                continue
            fi
        else
            ip=${line%% *}
            tmp_line=${line#* }
            domain_line=${tmp_line%% *}
            account_line=${tmp_line#* }
            IFS="|" read -ra domains <<< "$domain_line"
            IFS=" " read -ra accounts <<< "$account_line"

            found=0
            for((i=0;i<${#ips[@]};i++));
            do
                IFS='|' read -ra ips_index_arr <<< "${ips[i]}"
                for ips_index_ip in "${ips_index_arr[@]}"
                do
                    if [ "$ips_index_ip" == "$ip" ] 
                    then
                        found=1
                        for domain in "${domains[@]}"
                        do
                            if [[ ${new_domains[i]} != *"$domain"* ]] 
                            then
                                new_domains[i]="${new_domains[i]}|$domain"
                            fi
                        done
                        
                        for account in "${accounts[@]}"
                        do
                            if [[ ${new_accounts[i]} != *"$account"* ]] 
                            then
                                new_accounts[i]="${new_accounts[i]} $account"
                            fi
                        done
                        break
                    fi
                done

                if [ "$found" -eq 0 ] 
                then
                    for domain in "${domains[@]}"
                    do
                        if [[ ${new_domains[i]} == *"$domain"* ]] 
                        then
                            found=1
                            ips[i]="${ips[i]}|$ip"

                            for account in "${accounts[@]}"
                            do
                                if [[ ${new_accounts[i]} != *"$account"* ]] 
                                then
                                    new_accounts[i]="${new_accounts[i]} $account"
                                fi
                            done
                            break
                        fi
                    done
                fi
            done
            
            if [ "$found" -eq 0 ] 
            then
                ips+=("$ip")
                new_domains+=("$domain_line")
                new_accounts+=("$account_line")
            fi
            
            continue
        fi

        found=0
        for((i=0;i<${#ips[@]};i++));
        do
            if [ "${ips[i]}" == "$ip" ] 
            then
                found=1
                if [[ ${new_domains[i]} != *"$domain"* ]] 
                then
                    new_domains[i]="${new_domains[i]}|$domain"
                fi
                
                if [[ ${new_accounts[i]} != *"$account"* ]] 
                then
                    new_accounts[i]="${new_accounts[i]} $account"
                fi
                break
            fi
        done

        if [ "$found" -eq 0 ] 
        then
            for((i=0;i<${#new_domains[@]};i++));
            do
                if [[ ${new_domains[i]} == *"$domain"* ]] 
                then
                    found=1

                    if [[ ${ips[i]} != *"$ip"* ]] 
                    then
                        ips[i]="${ips[i]}|$ip"
                    fi

                    if [[ ${new_accounts[i]} != *"$account"* ]] 
                    then
                        new_accounts[i]="${new_accounts[i]} $account"
                    fi
                    break
                fi
            done
        fi

        if [ "$found" -eq 0 ] 
        then
            ips+=("$ip")
            new_domains+=("$domain")
            new_accounts+=("$account")
        fi
    done < <(awk '{gsub(/<[^>]*>/,""); print }' "$XTREAM_CODES")

    ips_count=${#ips[@]}

    if [ "$ips_count" -gt 0 ] 
    then
        print_list=""
        xtream_codes_list=""
        ips_acc_count=0
        ips_acc=()
        ips_mac_count=0
        ips_mac=()

        for((i=0;i<ips_count;i++));
        do
            print_list="$print_list${ips[i]} ${new_domains[i]} ${new_accounts[i]}\n"
            IFS=" " read -ra accounts <<< "${new_accounts[i]}"
            accounts_list=""
            macs_num=0
            accs_num=0
            for account in "${accounts[@]}"
            do
                if [ "${1:-}" == "mac" ] 
                then
                    if [[ $account =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
                    then
                        macs_num=$((macs_num+1))
                        accounts_list="$accounts_list${account}\n"
                    fi
                elif [[ ! $account =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
                then
                    accs_num=$((accs_num+1))
                    accounts_list="$accounts_list${account%:*}\r\e[20C${account#*:}\n"
                fi
            done
            if [ -n "$accounts_list" ] 
            then
                if [ "${1:-}" == "mac" ] 
                then
                    ips_mac+=("$i")
                    ips_mac_count=$((ips_mac_count+1))
                    xtream_codes_list="$xtream_codes_list$green$ips_mac_count.$plain IP: $green${ips[i]//|/, }$plain 域名: $green${new_domains[i]//|/, }$plain mac 地址个数: $green$macs_num$plain\n\n"
                else
                    ips_acc+=("$i")
                    ips_acc_count=$((ips_acc_count+1))
                    xtream_codes_list="$xtream_codes_list$green$ips_acc_count.$plain IP: $green${ips[i]//|/, }$plain 域名: $green${new_domains[i]//|/, }$plain 账号个数: $green$accs_num$plain\n\n"
                fi
            fi
        done

        printf '%b' "$print_list" > "$XTREAM_CODES"
        if [ "${1:-}" == "mac" ] && [ "$ips_mac_count" -eq 0 ]
        then
            Println "$error 请先添加 mac 地址！\n" && exit 1
        else
            Println "$xtream_codes_list"
        fi
    else
        Println "$error 没有账号！\n" && exit 1
    fi
}

ViewXtreamCodesAcc()
{
    ListXtreamCodes

    Println "请输入服务器的序号"
    while read -p "(默认: 取消): " server_num
    do
        case $server_num in
            "") Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$server_num" -gt 0 ] && [ "$server_num" -le "$ips_acc_count" ]
                then
                    ips_index=${ips_acc[$((server_num-1))]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    domain=${new_domains[ips_index]}

    if [[ $domain == *"|"* ]] 
    then
        IFS="|" read -ra domains <<< "$domain"
        domains_list=""
        domains_count=${#domains[@]}
        for((i=0;i<domains_count;i++));
        do
            domains_list="$domains_list$green$((i+1)).$plain ${domains[i]}\n\n"
        done
        Println "$domains_list"

        Println "请选择域名"
        while read -p "(默认: 取消): " domains_num
        do
            case $domains_num in
                "") Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*) Println "$error 请输入正确的数字\n"
                ;;
                *) 
                    if [ "$domains_num" -gt 0 ] && [ "$domains_num" -le "$domains_count" ]
                    then
                        domain=${domains[$((domains_num-1))]}
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done
    fi

    account=${new_accounts[ips_index]}
    IFS=" " read -ra accounts <<< "$account"

    accs=()
    for account in "${accounts[@]}"
    do
        if [[ ! $account =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
        then
            accs+=("$account")
        fi
    done

    GetXtreamCodesDomains
    GetXtreamCodesChnls

    accs_count=${#accs[@]}
    if [ "$accs_count" -gt 1 ] 
    then
        accs_list="账号: \n\n"
        for((i=0;i<accs_count;i++));
        do
            using=""
            if [ "$i" -lt 9 ] 
            then
                blank=" "
            else
                blank=""
            fi
            for xc_chnl in "${xc_chnls[@]}"
            do
                if [ "$xc_chnl" == "$domain/${accs[i]}" ] 
                then
                    using="${red}[使用中]$plain"
                    break
                fi
            done
            accs_list="$accs_list$blank$green$((i+1)).$plain ${accs[i]%:*}\r\e[20C${accs[i]#*:} $using\n\n"
        done
        Println "$accs_list"
    else
        using=""
        for xc_chnl in "${xc_chnls[@]}"
        do
            if [ "$xc_chnl" == "$domain/${accs[i]}" ] 
            then
                using="${red}[使用中]$plain"
                break
            fi
        done
        Println "账号: \n\n${green}1.$plain ${accs[0]%:*}\r\e[20C${accs[0]#*:} $using\n"
    fi
}

TestXtreamCodes()
{
    ListXtreamCodes

    Println "请输入服务器的序号"
    while read -p "(默认: 取消): " server_num
    do
        case $server_num in
            "") Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$server_num" -gt 0 ] && [ "$server_num" -le "$ips_acc_count" ]
                then
                    ips_index=${ips_acc[$((server_num-1))]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    Println "请输入测试的频道ID"
    while read -p "(默认: 取消): " channel_id
    do
        case $channel_id in
            "") Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$channel_id" -gt 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的频道ID(大于0)\n"
                fi
            ;;
        esac
    done

    chnls=()

    Println "输入 ffmpeg 代理, 比如 http://username:passsword@127.0.0.1:5555"
    read -p "(默认: 不设置): " proxy

    if [ -n "$proxy" ] 
    then
        proxy_command="-http_proxy $proxy"
        Println "代理服务器如果有正在使用的账号需要排除，输入代理服务器的 channels.json 链接或本地路径"
        read -p "(默认: 无): " proxy_channels_json
        if [ -n "$proxy_channels_json" ] 
        then
            if [ "${proxy_channels_json:0:1}" == "/" ] 
            then
                proxy_channels=$(< "$proxy_channels_json")
            else
                proxy_channels=$(wget --no-check-certificate "$proxy_channels_json" -qO-)
            fi
            while IFS= read -r line 
            do
                if [[ $line == *\"status\":* ]] 
                then
                    line=${line#*: \"}
                    status=${line%\",*}
                elif [[ $line == *\"stream_link\":* ]] && [[ $line == *http://*/*/*/* ]]
                then
                    line=${line#*: \"http://}
                    chnl_domain=${line%%/*}
                    line=${line#*/}
                    chnl_username=${line%%/*}
                    if [ "$chnl_username" == "live" ] 
                    then
                        line=${line#*/}
                        chnl_username=${line%%/*}
                    fi
                    line=${line#*/}
                    chnl_password=${line%%/*}
                elif [[ $line == *\"flv_status\":* ]] 
                then
                    line=${line#*: \"}
                    flv_status=${line%\",*}
                    if [ -n "${chnl_domain:-}" ] 
                    then
                        if [ "$status" == "on" ] || [ "$flv_status" == "on" ]
                        then
                            chnls+=("$chnl_domain/$chnl_username/$chnl_password")
                        fi
                    fi
                    chnl_domain=""
                fi
            done <<< "$proxy_channels"
        fi
    else
        proxy_command=""
    fi

    if [ -e "$CHANNELS_FILE" ] 
    then
        while IFS= read -r line 
        do
            if [[ $line == *\"status\":* ]] 
            then
                line=${line#*: \"}
                status=${line%\",*}
            elif [[ $line == *\"stream_link\":* ]] && [[ $line == *http://*/*/*/* ]]
            then
                line=${line#*: \"http://}
                chnl_domain=${line%%/*}
                line=${line#*/}
                chnl_username=${line%%/*}
                if [ "$chnl_username" == "live" ] 
                then
                    line=${line#*/}
                    chnl_username=${line%%/*}
                fi
                line=${line#*/}
                chnl_password=${line%%/*}
            elif [[ $line == *\"flv_status\":* ]] 
            then
                line=${line#*: \"}
                flv_status=${line%\",*}
                if [ -n "${chnl_domain:-}" ] 
                then
                    if [ "$status" == "on" ] || [ "$flv_status" == "on" ]
                    then
                        chnls+=("$chnl_domain/$chnl_username/$chnl_password")
                    fi
                fi
                chnl_domain=""
            fi
        done < "$CHANNELS_FILE"
    fi

    IFS="|" read -ra domains <<< "${new_domains[ips_index]}"
    IFS=" " read -ra accounts <<< "${new_accounts[ips_index]}"
    Println "IP: $green${ips[ips_index]}$plain 域名: $green${new_domains[ips_index]//|/ }$plain"
    Println "$green账号:$plain"

    FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
    FFPROBE="$FFMPEG_ROOT/ffprobe"

    for account in "${accounts[@]}"
    do
        username=${account%%:*}
        account=${account#*:}
        password=${account%%:*}

        found=0
        for domain in "${domains[@]}"
        do
            for chnl in "${chnls[@]}"
            do
                if [ "$domain/$username/$password" == "$chnl" ] 
                then
                    found=1
                    break 2
                fi
            done
        done

        # https://f-hauri.ch/vrac/diffU8test.sh
        if [ "$found" -eq 1 ] 
        then
            printf "$green%s$plain\r\e[12C%-21s%-21s\n" "[使用中]" "$username" "$password"
        else
            for domain in "${domains[@]}"
            do
                # curl --output /dev/null -m 3 --silent --fail -r 0-0
                if $FFPROBE $proxy_command -i "http://$domain/$username/$password/$channel_id" -rw_timeout 5000000 -show_streams -select_streams a -loglevel quiet > /dev/null
                then
                    printf "$green%s$plain\r\e[12C%-21s%-21s$green%s$plain\n%s\n\n" "[成功]" "$username" "$password" "$domain" "http://$domain/$username/$password/$channel_id"
                elif $FFPROBE $proxy_command -i "http://$domain/live/$username/$password/$channel_id.ts" -rw_timeout 5000000 -show_streams -select_streams a -loglevel quiet > /dev/null 
                then
                    printf "$green%s$plain\r\e[12C%-21s%-21s$green%s$plain\n%s\n\n" "[成功]" "$username" "$password" "$domain" "http://$domain/live/$username/$password/$channel_id.ts"
                else
                    printf "$red%s$plain\r\e[12C%-21s%-21s$red%s$plain\n%s" "[失败]" "$username" "$password" "$domain"
                fi
            done
        fi
    done
    echo
}

ViewXtreamCodesMac()
{
    ListXtreamCodes mac

    Println "请输入服务器的序号"
    while read -p "(默认: 取消): " server_num
    do
        case $server_num in
            "") Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$server_num" -gt 0 ] && [ "$server_num" -le "$ips_mac_count" ]
                then
                    ips_index=${ips_mac[$((server_num-1))]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    domain=${new_domains[ips_index]}

    if [[ $domain == *"|"* ]] 
    then
        IFS="|" read -ra domains <<< "$domain"
        domains_list=""
        domains_count=${#domains[@]}
        for((i=0;i<domains_count;i++));
        do
            domains_list="$domains_list$green$((i+1)).$plain ${domains[i]}\n\n"
        done
        Println "$domains_list"

        Println "请选择域名"
        while read -p "(默认: 取消): " domains_num
        do
            case $domains_num in
                "") Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*) Println "$error 请输入正确的数字\n"
                ;;
                *) 
                    if [ "$domains_num" -gt 0 ] && [ "$domains_num" -le "$domains_count" ]
                    then
                        domain=${domains[$((domains_num-1))]}
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done
    fi

    account=${new_accounts[ips_index]}
    IFS=" " read -ra accounts <<< "$account"

    macs=()
    for account in "${accounts[@]}"
    do
        if [[ $account =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
        then
            macs+=("$account")
        fi
    done

    GetXtreamCodesDomains
    GetXtreamCodesChnls

    macs_count=${#macs[@]}
    if [ "$macs_count" -gt 1 ] 
    then
        macs_list="mac 地址: \n\n"
        for((i=0;i<macs_count;i++));
        do
            using=""
            if [ "$i" -lt 9 ] 
            then
                blank=" "
            else
                blank=""
            fi
            for xc_chnl_mac in "${xc_chnls_mac[@]}"
            do
                if [ "$xc_chnl_mac" == "$domain/${macs[i]}" ] 
                then
                    using="${red}[使用中]$plain"
                    break
                fi
            done
            macs_list="$macs_list$blank$green$((i+1)).$plain ${macs[i]} $using\n\n"
        done
        Println "$macs_list"
    else
        using=""
        for xc_chnl_mac in "${xc_chnls_mac[@]}"
        do
            if [ "$xc_chnl_mac" == "$domain/${macs[i]}" ] 
            then
                using="${red}[使用中]$plain"
                break
            fi
        done
        Println "mac 地址: \n\n$green$((i+1)).$plain ${macs[0]} $using\n"
    fi
}

ViewXtreamCodesChnls()
{
    ListXtreamCodes mac

    Println "请输入服务器的序号"
    while read -p "(默认: 取消): " server_num
    do
        case $server_num in
            "") Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*) Println "$error 请输入正确的数字\n"
            ;;
            *) 
                if [ "$server_num" -gt 0 ] && [ "$server_num" -le "$ips_mac_count" ]
                then
                    ips_index=${ips_mac[$((server_num-1))]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    domain=${new_domains[ips_index]}

    if [[ $domain == *"|"* ]] 
    then
        IFS="|" read -ra domains <<< "$domain"
        domains_list=""
        domains_count=${#domains[@]}
        for((i=0;i<domains_count;i++));
        do
            domains_list="$domains_list$green$((i+1)).$plain ${domains[i]}\n\n"
        done
        Println "$domains_list"

        Println "请选择域名"
        while read -p "(默认: 取消): " domains_num
        do
            case $domains_num in
                "") Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*) Println "$error 请输入正确的数字\n"
                ;;
                *) 
                    if [ "$domains_num" -gt 0 ] && [ "$domains_num" -le "$domains_count" ]
                    then
                        domain=${domains[$((domains_num-1))]}
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done
    fi

    account=${new_accounts[ips_index]}
    IFS=" " read -ra accounts <<< "$account"

    macs=()
    for account in "${accounts[@]}"
    do
        if [[ $account =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]] 
        then
            macs+=("$account")
        fi
    done

    GetXtreamCodesDomains
    GetXtreamCodesChnls
        
    macs_count=${#macs[@]}
    if [ "$macs_count" -gt 1 ] 
    then
        macs_list="mac 地址: \n\n"
        for((i=0;i<macs_count;i++));
        do
            using=""
            if [ "$i" -lt 9 ] 
            then
                blank=" "
            else
                blank=""
            fi
            for xc_chnl_mac in "${xc_chnls_mac[@]}"
            do
                if [ "$xc_chnl_mac" == "$domain/${macs[i]}" ] 
                then
                    using="${red}[使用中]$plain"
                    break
                fi
            done
            macs_list="$macs_list$blank$green$((i+1)).$plain ${macs[i]} $using\n\n"
        done
        Println "$macs_list"

        Println "请选择 mac"
        while read -p "(默认: 取消): " macs_num
        do
            case $macs_num in
                "") Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*) Println "$error 请输入正确的数字\n"
                ;;
                *) 
                    if [ "$macs_num" -gt 0 ] && [ "$macs_num" -le "$macs_count" ]
                    then
                        mac_address=${macs[$((macs_num-1))]}
                        for xc_chnl_mac in "${xc_chnls_mac[@]}"
                        do
                            if [ "$xc_chnl_mac" == "$domain/$mac_address" ] 
                            then
                                Println "$error 此账号已经在使用!\n"
                                continue 2
                            fi
                        done
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done
    else
        mac_address=${macs[0]}
    fi

    token=""
    access_token=""
    profile=""
    user_agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)"
    server="http://$domain"
    mac=$(Urlencode "$mac_address")
    timezone=$(Urlencode "Europe/Amsterdam")
    cookies="mac=$mac; stb_lang=en; timezone=$timezone"
    token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
    profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"
    genres_url="$server/portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml"

    token=$(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
        --header="Cookie: $cookies" "$token_url" -qO- \
        | $JQ_FILE -r '.js.token' || true)
    if [ -z "$token" ] 
    then
        Println "$error 无法连接 $domain, 请重试!\n" && exit 1
    fi
    access_token=$(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
        --header="Authorization: Bearer $token" \
        --header="Cookie: $cookies" "$token_url" -qO- \
        | $JQ_FILE -r '.js.token' || true)
    if [ -z "$access_token" ] 
    then
        Println "$error 无法连接 $domain, 请重试!\n" && exit 1
    fi
    headers="Authorization: Bearer $access_token"
    profile=$(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
        --header="$headers" \
        --header="Cookie: $cookies" "$profile_url" -qO- || true)
    if [ -z "$profile" ] 
    then
        Println "$error 无法连接 $domain, 请重试!\n" && exit 1
    fi

    if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
    then
        Println "$error mac 地址错误!\n" && exit 1
    fi

    genres_list=""
    genres_count=0
    genres_id=()
    while IFS= read -r line
    do
        map_id=${line#*id: }
        map_id=${map_id%, title:*}
        map_title=${line#*, title: }
        map_title=${map_title%\"}
        genres_count=$((genres_count+1))
        genres_id+=("$map_id")
        genres_list="$genres_list$green$genres_count.$plain $map_title\n\n"
    done < <(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
        --header="$headers" \
        --header="Cookie: $cookies" "$genres_url" -qO- | $JQ_FILE '.js | to_entries | map("id: \(.value.id), title: \(.value.title)") | .[]')

    if [ -n "$genres_list" ] 
    then
        genres_list_pages=()
        FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
        FFPROBE="$FFMPEG_ROOT/ffprobe"
        while true 
        do
            Println "$genres_list\n"

            while read -p "输入分类序号(默认: 取消): " genres_num 
            do
                case "$genres_num" in
                    "")
                        Println "已取消...\n" && exit
                    ;;
                    *[!0-9]*)
                        Println "$error 请输入正确的序号\n"
                    ;;
                    *)
                        if [ "$genres_num" -gt 0 ] && [ "$genres_num" -le "$genres_count" ]
                        then
                            genres_index=$((genres_num-1))
                            break
                        else
                            Println "$error 请输入正确的序号\n"
                        fi
                    ;;
                esac
            done

            if [ -n "${genres_list_pages[genres_index]:-}" ] 
            then
                ordered_list_page=${genres_list_pages[genres_index]}
            else
                ordered_list_url="$server/portal.php?type=itv&action=get_ordered_list&genre=${genres_id[genres_index]}&force_ch_link_check=&fav=0&sortby=number&hd=0&p=1&JsHttpRequest=1-xml"
                ordered_list_page=$(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
                    --header="$headers" \
                    --header="Cookie: $cookies" "$ordered_list_url" -qO-)
                [ -z "$ordered_list_page" ] && Println "$error 返回错误, 请重试\n" && exit 1
                genres_list_pages[genres_index]="$ordered_list_page"
            fi

            exec 100< <($JQ_FILE -r '.js.total_items, .js.max_page_items' <<< "$ordered_list_page")
            read total_items <&100
            read max_page_items <&100
            exec 100<&-

            if [ "$total_items" == null ] || [ "${total_items:-0}" -eq 0 ] 
            then
                Println "$error 此分类没有频道!\n"
                continue
            fi

            if [ "$total_items" -le "$max_page_items" ] 
            then
                pages=1
            else
                pages=$((total_items / max_page_items))
                if [ "$total_items" -gt $((pages * max_page_items)) ] 
                then
                    pages=$((pages+1))
                fi
            fi

            page=1
            ordered_list_pages=()

            while true 
            do
                if [ "${#ordered_list_pages[@]}" -ge "$page" ] 
                then
                    page_index=$((page-1))
                    ordered_list_page=${ordered_list_pages[page_index]}
                else
                    if [ "$page" -gt 1 ] 
                    then
                        ordered_list_url="$server/portal.php?type=itv&action=get_ordered_list&genre=${genres_id[genres_index]}&force_ch_link_check=&fav=0&sortby=number&hd=0&p=$page&JsHttpRequest=1-xml"
                        ordered_list_page=$(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
                            --header="$headers" \
                            --header="Cookie: $cookies" "$ordered_list_url" -qO-)
                    fi
                    ordered_list_pages+=("$ordered_list_page")
                fi

                xc_chnls_id=()
                xc_chnls_name=()
                xc_chnls_cmd=()
                xc_chnls_list=""
                xc_chnls_count=0
                while IFS= read -r line
                do
                    xc_chnls_count=$((xc_chnls_count+1))
                    map_id=${line#*id: }
                    map_id=${map_id%, name:*}
                    map_name=${line#*, name: }
                    map_name=${map_name%, cmd:*}
                    map_cmd=${line#*, cmd: }
                    map_cmd=${map_cmd%\"}
                    map_cmd=${map_cmd#* }
                    xc_chnls_id+=("$map_id")
                    xc_chnls_name+=("$map_name")
                    xc_chnls_cmd+=("$map_cmd")
                    xc_chnls_list="$xc_chnls_list# $green$xc_chnls_count$plain $map_name\n\n"
                done < <($JQ_FILE '.js.data | to_entries | map("id: \(.value.id), name: \(.value.name), cmd: \(.value.cmd)") | .[]' <<< "$ordered_list_page")

                Println "$xc_chnls_list"
                echo -e "$tip 输入 a 返回上级页面"
                if [ "$pages" -gt 1 ] 
                then
                    Println "当前第 $page 页, 共 $pages 页"
                    if [ "$page" -eq 1 ] 
                    then
                        echo -e "$tip 输入 x 转到下一页"
                    elif [ "$page" -eq "$pages" ] 
                    then
                        echo -e "$tip 输入 z 转到上一页"
                    else
                        echo -e "$tip 输入 z 转到上一页, 输入 x 转到下一页"
                    fi
                fi

                echo && while read -p "输入频道序号: " xc_chnls_num 
                do
                    case "$xc_chnls_num" in
                        a)
                            continue 3
                        ;;
                        z)
                            if [ "$page" -gt 1 ]
                            then
                                page=$((page-1))
                                continue 2
                            else
                                Println "$error 没有上一页\n"
                            fi
                        ;;
                        x)
                            if [ "$page" -lt "$pages" ]
                            then
                                page=$((page+1))
                                continue 2
                            else
                                Println "$error 没有下一页\n"
                            fi
                        ;;
                        ""|*[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$xc_chnls_num" -gt 0 ] && [ "$xc_chnls_num" -le "$xc_chnls_count" ]
                            then
                                xc_chnls_index=$((xc_chnls_num-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                create_link_url="$server/portal.php?type=itv&action=create_link&cmd=${xc_chnls_cmd[xc_chnls_index]}&series=&forced_storage=undefined&disable_ad=0&download=0&JsHttpRequest=1-xml"

                stream_link=$(wget --timeout=10 --tries=3 --user-agent="$user_agent" --no-check-certificate \
                    --header="$headers" \
                    --header="Cookie: $cookies" "$create_link_url" -qO- \
                    | $JQ_FILE -r '.js.cmd')
                stream_link=${stream_link#* }
                IFS="/" read -ra s <<< "$stream_link"
                if [ "${s[3]}" == "live" ] 
                then
                    stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[5]}/${s[-1]}"
                else
                    stream_link="${s[0]}//${s[2]}/${s[3]}/${s[4]}/${s[-1]}"
                fi
                Println "$green${xc_chnls_name[xc_chnls_index]}:$plain $stream_link\n"
                $FFPROBE -i "$stream_link" -user_agent "$user_agent" \
                    -headers "$headers"$'\r\n' \
                    -cookies "$cookies" -hide_banner

                Println "是否添加此频道？[y/N]"
                read -p "(默认: N): " add_channel_yn
                add_channel_yn=${add_channel_yn:-N}
                if [[ $add_channel_yn == [Yy] ]] 
                then
                    Println "是否推流 flv ？[y/N]"
                    read -p "(默认: N): " add_channel_flv_yn
                    add_channel_flv_yn=${add_channel_flv_yn:-N}
                    if [[ $add_channel_flv_yn == [Yy] ]] 
                    then
                        kind="flv"
                    fi
                    xc=1
                    stream_links_input="$domain|$stream_link|${xc_chnls_cmd[xc_chnls_index]}|$mac_address"
                    AddChannel
                else
                    Println "是否继续？[y/N]"
                    read -p "(默认: N): " continue_yn
                    continue_yn=${continue_yn:-N}
                    if [[ $continue_yn == [Yy] ]] 
                    then
                        continue
                    fi
                fi
                break
            done
            break
        done
    else
        Println "$error 找不到分类!\n" && exit 1
    fi
}

AddXtreamCodesMac()
{
    echo && read -p "请输入服务器地址：" server
    [ -z "$server" ] && Println "已取消...\n" && exit 1

    domain=${server#*http://}
    domain=${domain%%/*}
    ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)

    [ -z "${ip:-}" ] && Println "$error 无法解析域名 !\n" && exit 1
    server="http://$domain"

    echo && read -p "请输入 mac 地址(多个地址空格分隔)：" mac_address
    [ -z "$mac_address" ] && Println "已取消...\n" && exit 1

    IFS=" " read -ra macs <<< "$mac_address"
    Println "$info 验证中..."

    add_mac_success=0
    for mac_address in "${macs[@]}"
    do
        token=""
        access_token=""
        profile=""
        mac=$(Urlencode "$mac_address")
        timezone=$(Urlencode "Europe/Amsterdam")
        token_url="$server/portal.php?type=stb&action=handshake&JsHttpRequest=1-xml"
        profile_url="$server/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"

        token=$(wget --timeout=10 --tries=3 --user-agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)" --no-check-certificate \
            --header="Cookie: mac=$mac; stb_lang=en; timezone=$timezone" "$token_url" -qO- \
            | $JQ_FILE -r '.js.token' || true)
        if [ -z "$token" ] 
        then
            if [ "$add_mac_success" -eq 0 ] 
            then
                Println "$error 无法连接 $domain, 请重试!\n" && exit 1
            else
                Println "$error $mac_address 遇到错误, 请重试!"
                continue
            fi
        fi
        access_token=$(wget --timeout=10 --tries=3 --user-agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)" --no-check-certificate \
            --header="Authorization: Bearer $token" \
            --header="Cookie: mac=$mac; stb_lang=en; timezone=$timezone" "$token_url" -qO- \
            | $JQ_FILE -r '.js.token' || true)
        if [ -z "$access_token" ] 
        then
            if [ "$add_mac_success" -eq 0 ] 
            then
                Println "$error 无法连接 $domain, 请重试!\n" && exit 1
            else
                Println "$error $mac_address 遇到错误, 请重试!"
                continue
            fi
        fi
        profile=$(wget --timeout=10 --tries=3 --user-agent="Mozilla/5.0 (QtEmbedded; U; Linux; C)" --no-check-certificate \
            --header="Authorization: Bearer $access_token" \
            --header="Cookie: mac=$mac; stb_lang=en; timezone=$timezone" "$profile_url" -qO- || true)
        if [ -z "$profile" ] 
        then
            if [ "$add_mac_success" -eq 0 ] 
            then
                Println "$error 无法连接 $domain, 请重试!\n" && exit 1
            else
                Println "$error $mac_address 遇到错误, 请重试!"
                continue
            fi
        fi

        if [[ $($JQ_FILE -r '.js.id' <<< "$profile") == null ]] 
        then
            Println "$error $mac_address 地址错误!\n"
            continue
        fi

        add_mac_success=1
        printf '%s\n' "$ip $domain $mac_address" >> "$XTREAM_CODES"
    done
}

GetServerIp()
{
    ip=$(dig +short myip.opendns.com @resolver1.opendns.com || true)
    [ -z "$ip" ] && ip=$(curl --silent ipv4.icanhazip.com)
    [ -z "$ip" ] && ip=$(curl --silent api.ip.sb/ip)
    [ -z "$ip" ] && ip=$(curl --silent ipinfo.io/ip)
    echo "$ip"
}

NginxConfigServerHttpPort()
{
    Println "输入 http 端口"
    echo -e "$tip 也可以输入 IP:端口 组合\n"
    read -p "(默认: 80): " server_http_port
    server_http_port=${server_http_port:-80}
}

NginxConfigServerHttpsPort()
{
    Println "输入 https 端口"
    echo -e "$tip 也可以输入 IP:端口 组合\n"
    read -p "(默认: 443): " server_https_port
    server_https_port=${server_https_port:-443}
}

NginxConfigServerRoot()
{
    Println "设置公开的根目录"
    while read -p "(默认: /usr/local/nginx/html): " server_root 
    do
        if [ -z "$server_root" ] 
        then
            server_root="/usr/local/nginx/html"
            break
        elif [ "${server_root:0:1}" != "/" ] 
        then
            Println "$error 输入错误\n"
        else
            if [ "${server_root: -1}" == "/" ] 
            then
                server_root=${server_root:0:-1}
            fi

            mkdir -p "$server_root"
            break
        fi
    done
}

NginxConfigServerLiveRoot()
{
    Println "设置公开目录下的(live目录 - HLS输出目录)位置"
    while read -p "(默认: $server_root/): " server_live_root 
    do
        if [ -z "$server_live_root" ] 
        then
            server_live_root=$server_root
            ln -sf "$LIVE_ROOT" "$server_live_root/"
            break
        elif [ "${server_live_root:0:1}" != "/" ] 
        then
            Println "$error 输入错误\n"
        else
            if [ "${server_live_root: -1}" == "/" ] 
            then
                server_live_root=${server_live_root:0:-1}
            fi

            mkdir -p "$server_live_root"
            ln -sf "$LIVE_ROOT" "$server_live_root/"
            break
        fi
    done
}

NginxConfigBlockAliyun()
{
    Println "是否屏蔽所有阿里云ip段 [y/N]"
    read -p "(默认: N): " block_aliyun_yn
    block_aliyun_yn=${block_aliyun_yn:-N}
    if [[ $block_aliyun_yn == [Yy] ]] 
    then
        Println "输入本机IP"
        echo -e "$tip 多个IP用空格分隔\n"

        while read -p "(默认: 自动检测): " server_ip
        do
            server_ip=${server_ip:-$(GetServerIp)}
            if [ -z "$server_ip" ]
            then
                Println "$error 无法获取本机IP，请手动输入\n"
            else
                Println "$info      本机IP: $server_ip\n"
                break
            fi
        done

        start=0
        deny_aliyun="
            location ${server_live_root#*$server_root}/${LIVE_ROOT##*/} {"

        IFS=" " read -ra server_ips <<< "$server_ip"
        for ip in "${server_ips[@]}"
        do
            deny_aliyun="$deny_aliyun
                allow $ip;"
        done

        while IFS= read -r line 
        do
            if [[ $line == *"ipTabContent"* ]] 
            then
                start=1
            elif [ "$start" -eq 1 ] && [[ $line == *"AS45102"* ]] 
            then
                line=${line#*AS45102\/}
                ip=${line%\"*}
                deny_aliyun="$deny_aliyun
                deny $ip;"
            elif [ "$start" -eq 1 ] && [[ $line == *"</tbody>"* ]] 
            then
                break
            fi
        done < <(wget --no-check-certificate https://ipinfo.io/AS45102 -qO-)
        deny_aliyun="$deny_aliyun
                allow all;"
        deny_aliyun="$deny_aliyun
            }

"
    fi
}

NginxCheckDomains()
{
    if [ ! -e "/usr/local/nginx" ] 
    then
        Println "$error Nginx 未安装 ! 输入 nx 安装 nginx\n" && exit 1
    fi
    mkdir -p "/usr/local/nginx/conf/sites_crt/"
    mkdir -p "/usr/local/nginx/conf/sites_available/"
    mkdir -p "/usr/local/nginx/conf/sites_enabled/"
    conf=""
    server_conf=""
    server_found=0
    server_flag=0
    server_localhost=0
    server_localhost_found=0
    server_domains=()
    http_found=0
    http_flag=0
    sites_found=0
    rtmp_found=0
    while IFS= read -r line 
    do
        lead=${line%%[^[:blank:]]*}
        first_char=${line#${lead}}
        first_char=${first_char:0:1}

        if [[ $line == *"rtmp {"* ]] && [[ $first_char != "#" ]]
        then
            rtmp_found=1
        fi

        if [[ $line == *"http {"* ]] && [[ $first_char != "#" ]]
        then
            http_found=1
        fi

        if [[ $http_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            http_flag=$((http_flag+1))
        fi

        if [[ $http_found -eq 1 ]] && [[ $line == *"sites_enabled/*.conf"* ]] 
        then
            sites_found=1
        fi

        if [[ $http_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            http_flag=$((http_flag-1))
            if [[ $http_flag -eq 0 ]] 
            then
                if [[ $sites_found -eq 0 ]] 
                then
                    line="    include sites_enabled/*.conf;\n$line"
                fi
                if [[ $server_localhost_found -eq 0 ]] 
                then
                    line="
    server {
        listen       80;
        server_name  localhost;

        access_log logs/access.log;

        location /flv {
            flv_live on;
            chunked_transfer_encoding  on;
        }

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }\n\n$line"
                fi
                http_found=0
            fi
        fi

        if [[ $http_found -eq 1 ]] && [[ $line == *"server {"* ]] && [[ $first_char != "#" ]]
        then
            server_conf=""
            server_found=1
            server_localhost=0
            server_domains=()
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            server_flag=$((server_flag+1))
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            server_flag=$((server_flag-1))
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"server_name "* ]] 
        then
            server_names=${line#*server_name }
            server_names=${server_names%;*}
            lead=${server_names%%[^[:blank:]]*}
            server_names=${server_names#${lead}}
            IFS=" " read -ra server_names_array <<< "$server_names"
            for server_name in "${server_names_array[@]}"
            do
                if [[ $server_name == "localhost" ]]
                then
                    server_localhost=1
                    server_localhost_found=1
                else
                    server_domains+=("$server_name")
                fi
            done

            if [[ $server_localhost -eq 1 ]] 
            then
                line="${line%%server_name*}server_name localhost;"
            fi
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"ssl_certificate"* ]] 
        then
            CERT_FILE=${line%;*}
            CERT_FILE=${CERT_FILE##* }
            new_crt_name="$server_names.${CERT_FILE##*.}"
            [ -e "$CERT_FILE" ] && mv "$CERT_FILE" "/usr/local/nginx/conf/sites_crt/$new_crt_name"
            line=${line%;*}
            line=${line% *}
            line="$line /usr/local/nginx/conf/sites_crt/$new_crt_name;"
        fi

        if [[ $server_found -eq 1 ]] 
        then
            [ -n "$server_conf" ] && server_conf="$server_conf\n"
            server_conf="$server_conf$line"
            if [[ $server_flag -eq 0 ]] && [[ $line == *"}"* ]] 
            then
                server_found=0
                if [[ ${#server_domains[@]} -gt 0 ]] 
                then
                    for server_domain in "${server_domains[@]}"
                    do
                        server_domain_conf=""
                        while IFS= read -r server_domain_line 
                        do
                            if [[ $server_domain_line == *"server_name "* ]] 
                            then
                                server_domain_line="${server_domain_line%%server_name*}server_name $server_domain;"
                            fi
                            [ -n "$server_domain_conf" ] && server_domain_conf="$server_domain_conf\n"
                            server_domain_conf="$server_domain_conf$server_domain_line"
                        done < <(echo -e "$server_conf")
                        echo -e "$server_domain_conf\n" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
                        ln -sf "/usr/local/nginx/conf/sites_available/$server_domain.conf" "/usr/local/nginx/conf/sites_enabled/"
                    done
                fi
                if [[ $server_localhost -eq 0 ]] && [[ ${#server_domains[@]} -gt 0 ]]
                then
                    continue
                else
                    line=$server_conf
                fi
            fi
        fi

        if [[ $server_found -eq 0 ]] 
        then
            [ -n "$conf" ] && conf="$conf\n"
            conf="$conf$line"
        fi
    done < "/usr/local/nginx/conf/nginx.conf"
    if [[ $rtmp_found -eq 1 ]] 
    then
        echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"
    else
        echo -e "$conf

rtmp_auto_push on;
rtmp_auto_push_reconnect 1s;
rtmp_socket_dir /tmp;

rtmp {
    out_queue   4096;
    out_cork    8;
    max_streams   128;
    timeout   15s;
    drop_idle_publisher   10s;
    log_interval    120s;
    log_size    1m;

    server {
        listen 1935;
        server_name 127.0.0.1;
        access_log  logs/flv.log;

        application flv {
            live on;
            gop_cache on;
        }
    }
}" > "/usr/local/nginx/conf/nginx.conf"
    fi
}

NginxConfigCorsHost()
{
    Println "$info 配置 cors..."
    cors_domains=""
    if ls -A "/usr/local/nginx/conf/sites_available/"* > /dev/null 2>&1
    then
        for f in "/usr/local/nginx/conf/sites_available/"*
        do
            domain=${f##*/}
            domain=${domain%.conf}
            if [[ $domain =~ ^[A-Za-z0-9.]*$ ]] 
            then
                cors_domains="$cors_domains
        \"~http://$domain\" http://$domain;
        \"~https://$domain\" https://$domain;"
            fi
        done
    fi
    server_ip=$(GetServerIp)
    cors_domains="$cors_domains
        \"~http://$server_ip\" http://$server_ip;"
    if ! grep -q "map \$http_origin \$corsHost" < "/usr/local/nginx/conf/nginx.conf"
    then
        conf=""
        found=0
        while IFS= read -r line 
        do
            if [ "$found" -eq 0 ] && [[ $line == *"server {"* ]]
            then
                lead=${line%%[^[:blank:]]*}
                first_char=${line#${lead}}
                first_char=${first_char:0:1}
                if [[ $first_char != "#" ]] 
                then
                    line="
    map \$http_origin \$corsHost {
        default *;$cors_domains
    }\n\n$line"
                    found=1
                fi
            fi
            [ -n "$conf" ] && conf="$conf\n"
            conf="$conf$line"
        done < "/usr/local/nginx/conf/nginx.conf"
        echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"
    else
        conf=""
        found=0
        while IFS= read -r line 
        do
            if [ "$found" -eq 0 ] && [[ $line == *"map \$http_origin \$corsHost"* ]]
            then
                found=1
                continue
            fi
            if [ "$found" -eq 1 ] && [[ $line == *"}"* ]] 
            then
                line="    map \$http_origin \$corsHost {\n        default *;$cors_domains\n    }"
                found=0
            fi
            if [ "$found" -eq 1 ] 
            then
                continue
            fi
            [ -n "$conf" ] && conf="$conf\n"
            conf="$conf$line"
        done < "/usr/local/nginx/conf/nginx.conf"
        echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"
    fi
}

NginxConfigSsl()
{
    conf=""
    found=0
    while IFS= read -r line 
    do
        if [ "$found" -eq 0 ] && { [[ $line == *"ssl_session_cache "* ]] || [[ $line == *"ssl_session_timeout "* ]] || [[ $line == *"ssl_prefer_server_ciphers "* ]] || [[ $line == *"ssl_protocols "* ]] || [[ $line == *"ssl_ciphers "* ]] || [[ $line == *"ssl_stapling "* ]] || [[ $line == *"ssl_stapling_verify "* ]] || [[ $line == *"resolver "* ]]; }
        then
            continue
        fi
        if [ "$found" -eq 0 ] && [[ $line == *"server {"* ]]
        then
            lead=${line%%[^[:blank:]]*}
            first_char=${line#${lead}}
            first_char=${first_char:0:1}
            if [[ $first_char != "#" ]] 
            then
                line="
    ssl_session_cache           shared:SSL:10m;
    ssl_session_timeout         10m;
    ssl_prefer_server_ciphers   on;
    ssl_protocols               TLSv1.2 TLSv1.3;
    ssl_ciphers                 HIGH:!aNULL:!MD5;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8;

$line"
                found=1
            fi
        fi
        [ -n "$conf" ] && conf="$conf\n"
        conf="$conf$line"
    done < "/usr/local/nginx/conf/nginx.conf"
    PrettyConfig
    echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"
}

NginxListDomains()
{
    nginx_domains_list=""
    nginx_domains_count=0
    nginx_domains=()
    nginx_domains_status=()
    if ls -A "/usr/local/nginx/conf/sites_available/"* > /dev/null 2>&1
    then
        for f in "/usr/local/nginx/conf/sites_available/"*
        do
            nginx_domains_count=$((nginx_domains_count+1))
            domain=${f##*/}
            domain=${domain%.conf}
            if [ -e "/usr/local/nginx/conf/sites_enabled/$domain.conf" ] 
            then
                domain_status=1
                domain_status_text="$green [开启] $plain"
            else
                domain_status=0
                domain_status_text="$red [关闭] $plain"
            fi
            nginx_domains_list=$nginx_domains_list"$green$nginx_domains_count.$plain $domain $domain_status_text\n\n"
            nginx_domains+=("$domain")
            nginx_domains_status+=("$domain_status")
        done
    fi
    [ -n "$nginx_domains_list" ] && Println "$green域名列表:$plain\n\n$nginx_domains_list"
    return 0
}

NginxListDomain()
{
    nginx_domain_list=""
    nginx_domain_server_found=0
    nginx_domain_server_flag=0
    nginx_domain_servers_count=0
    nginx_domain_servers_https_port=()
    nginx_domain_servers_http_port=()
    nginx_domain_servers_root=()
    while IFS= read -r line 
    do
        if [[ $line == *"server {"* ]] 
        then
            nginx_domain_server_found=1
            https_ports=""
            http_ports=""
            nodejs_found=0
            flv_found=0
            root=""
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            nginx_domain_server_flag=$((nginx_domain_server_flag+1))
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            nginx_domain_server_flag=$((nginx_domain_server_flag-1))
            if [[ $nginx_domain_server_flag -eq 0 ]] 
            then
                nginx_domain_server_found=0
                nginx_domain_servers_count=$((nginx_domain_servers_count+1))
                nginx_domain_servers_https_port+=("$https_ports")
                nginx_domain_servers_http_port+=("$http_ports")
                nginx_domain_servers_root+=("$root")
                if [[ $flv_found -eq 1 ]] 
                then
                    flv_status="$green已配置$plain"
                else
                    flv_status="$red未配置$plain"
                fi
                if [[ $nodejs_found -eq 1 ]] 
                then
                    nodejs_status="$green已配置$plain"
                else
                    nodejs_status="$red未配置$plain"
                fi
                nginx_domain_list=$nginx_domain_list"$green$nginx_domain_servers_count.$plain https 端口: $green${https_ports:-无}$plain, http 端口: $green${http_ports:-无}$plain, flv: $flv_status, nodejs: $nodejs_status\n\n"
            fi
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *" ssl;"* ]]
        then
            https_port=${line#*listen}
            https_port=${https_port// ssl;/}
            lead=${https_port%%[^[:blank:]]*}
            https_port=${https_port#${lead}}
            https_ports="$https_ports$https_port "
        elif [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"listen "* ]] 
        then
            http_port=${line#*listen}
            http_port=${http_port%;*}
            lead=${http_port%%[^[:blank:]]*}
            http_port=${http_port#${lead}}
            [ -n "$http_ports" ] && http_ports="$http_ports "
            http_ports="$http_ports$http_port"
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"location /flv "* ]]
        then
            flv_found=1
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"root "* ]]
        then
            root=${line#*root}
            root=${root%;*}
            lead=${root%%[^[:blank:]]*}
            root=${root#${lead}}
            if [[ ${root:0:1} != "/" ]] 
            then
                root="/usr/local/nginx/$root"
            fi
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"proxy_pass http://nodejs"* ]]
        then
            nodejs_found=1
        fi
    done < "/usr/local/nginx/conf/sites_available/${nginx_domains[nginx_domains_index]}.conf"

    if [ "${action:-}" == "edit" ] 
    then
        nginx_domain_update_crt_number=$((nginx_domain_servers_count+1))
        nginx_domain_add_server_number=$((nginx_domain_servers_count+2))
        nginx_domain_edit_server_number=$((nginx_domain_servers_count+3))
        nginx_domain_delete_server_number=$((nginx_domain_servers_count+4))
        nginx_domain_list="$nginx_domain_list$green$nginx_domain_update_crt_number.$plain 更新证书\n\n"
        nginx_domain_list="$nginx_domain_list$green$nginx_domain_add_server_number.$plain 添加配置\n\n"
        nginx_domain_list="$nginx_domain_list$green$nginx_domain_edit_server_number.$plain 修改配置\n\n"
        nginx_domain_list="$nginx_domain_list$green$nginx_domain_delete_server_number.$plain 删除配置\n\n"
    fi

    Println "域名 $green${nginx_domains[nginx_domains_index]}$plain 配置:\n\n$nginx_domain_list"
}

NginxDomainServerToggleFlv()
{
    nginx_domain_server_found=0
    nginx_domain_server_flag=0
    conf=""
    while IFS= read -r line 
    do
        if [[ $line == *"server {"* ]] 
        then
            nginx_domain_server_found=1
            https_ports=""
            http_ports=""
            flv_flag=0
            flv_found=0
            flv_add=0
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            nginx_domain_server_flag=$((nginx_domain_server_flag+1))
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            nginx_domain_server_flag=$((nginx_domain_server_flag-1))
            if [[ $nginx_domain_server_flag -eq 0 ]] 
            then
                nginx_domain_server_found=0
                if [[ $flv_add -eq 0 ]] && [[ $flv_found -eq 0 ]] && [[ $https_ports == "${nginx_domain_servers_https_port[nginx_domain_server_index]}" ]] && [[ $http_ports == "${nginx_domain_servers_http_port[nginx_domain_server_index]}" ]] 
                then
                    line="
        location /flv {
            flv_live on;
            chunked_transfer_encoding  on;
        }\n$line"
                fi
            fi
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *" ssl;"* ]]
        then
            https_port=${line#*listen}
            https_port=${https_port// ssl;/}
            lead=${https_port%%[^[:blank:]]*}
            https_port=${https_port#${lead}}
            https_ports="$https_ports$https_port "
        elif [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"listen "* ]] 
        then
            http_port=${line#*listen}
            http_port=${http_port%;*}
            lead=${http_port%%[^[:blank:]]*}
            http_port=${http_port#${lead}}
            [ -n "$http_ports" ] && http_ports="$http_ports "
            http_ports="$http_ports$http_port"
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"location /flv "* ]] && [[ $https_ports == "${nginx_domain_servers_https_port[nginx_domain_server_index]}" ]] && [[ $http_ports == "${nginx_domain_servers_http_port[nginx_domain_server_index]}" ]] 
        then
            flv_flag=1
            flv_found=1
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $flv_flag -eq 1 ]] 
        then
            if [[ $line == *"}"* ]] 
            then
                flv_flag=0
            fi
            continue
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $flv_add -eq 0 ]] && [[ $line == *"location "* ]] && [[ $line != *"location /flv "* ]] && [[ $flv_found -eq 0 ]] && [[ $https_ports == "${nginx_domain_servers_https_port[nginx_domain_server_index]}" ]] && [[ $http_ports == "${nginx_domain_servers_http_port[nginx_domain_server_index]}" ]] 
        then
            flv_add=1
            line="        location /flv {
            flv_live on;
            chunked_transfer_encoding  on;
        }\n\n$line"
        fi

        if [ "${last_line:-}" == "#" ] && [ "$line" == "" ]
        then
            continue
        fi
        last_line="$line#"
        [ -n "$conf" ] && conf="$conf\n"
        conf="$conf$line"
    done < "/usr/local/nginx/conf/sites_available/${nginx_domains[nginx_domains_index]}.conf"
    unset last_line
    echo -e "$conf" > "/usr/local/nginx/conf/sites_available/${nginx_domains[nginx_domains_index]}.conf"
    Println "$info flv 配置修改成功\n"
}

NginxDomainServerToggleNodejs()
{
    nginx_domain_server_found=0
    nginx_domain_server_flag=0
    conf=""
    while IFS= read -r line 
    do
        if [[ $line == *"server {"* ]] 
        then
            nginx_domain_server_found=1
            https_ports=""
            http_ports=""
            nodejs_flag=0
            nodejs_found=0
            location_found=0
            add_header_found=0
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            nginx_domain_server_flag=$((nginx_domain_server_flag+1))
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            nginx_domain_server_flag=$((nginx_domain_server_flag-1))
            if [[ $nginx_domain_server_flag -eq 0 ]] 
            then
                nginx_domain_server_found=0
                if [[ $location_found -eq 0 ]] && [[ $https_ports == "${nginx_domain_servers_https_port[nginx_domain_server_index]}" ]] && [[ $http_ports == "${nginx_domain_servers_http_port[nginx_domain_server_index]}" ]]
                then
                    line="
        location / {
            root   ${server_root#*/usr/local/nginx/};
            index  index.html index.htm;
        }\n$line"
                    if [[ $nodejs_found -eq 0 ]]
                    then
                        if [ -n "$https_ports" ] && [ -n "$http_ports" ]
                        then
                            scheme="\$scheme"
                            proxy_cookie_path=""
                        elif [ -n "$https_ports" ] 
                        then
                            scheme="https"
                            proxy_cookie_path="\n            proxy_cookie_path / /\$samesite_none;"
                        else
                            scheme="http"
                            proxy_cookie_path=""
                        fi

                        line="
        location = / {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location = /channels {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location = /channels.json {
            return 302 /channels;
        }

        location = /remote {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location = /remote.json {
            return 302 /remote;
        }

        location = /keys {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location ~ \.(keyinfo|key)$ {
            return 403;
        }\n$line"
                    fi
                fi
            fi
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *" ssl;"* ]]
        then
            https_port=${line#*listen}
            https_port=${https_port// ssl;/}
            lead=${https_port%%[^[:blank:]]*}
            https_port=${https_port#${lead}}
            https_ports="$https_ports$https_port "
        elif [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"listen "* ]] 
        then
            http_port=${line#*listen}
            http_port=${http_port%;*}
            lead=${http_port%%[^[:blank:]]*}
            http_port=${http_port#${lead}}
            [ -n "$http_ports" ] && http_ports="$http_ports "
            http_ports="$http_ports$http_port"
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"add_header "* ]] 
        then
            add_header_found=1
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"location = / {"* ]] && [[ $https_ports == "${nginx_domain_servers_https_port[nginx_domain_server_index]}" ]] && [[ $http_ports == "${nginx_domain_servers_http_port[nginx_domain_server_index]}" ]] 
        then
            nodejs_flag=1
            nodejs_found=1
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $nodejs_flag -eq 1 ]] 
        then
            if [[ $line == *"}"* ]] 
            then
                nodejs_flag=0
            fi
            [[ "${enable_nodejs:-0}" -eq 1 ]] || continue
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && { [[ $line == *"location = /channels.json "* ]] || [[ $line == *"location = /remote "* ]] || [[ $line == *"location = /remote.json "* ]] || [[ $line == *"location = /keys "* ]] || [[ $line == *"location ~ \.(keyinfo|key)"* ]]; }
        then
            nodejs_flag=1
            [[ "${enable_nodejs:-0}" -eq 1 ]] || continue
        fi

        if [[ $nginx_domain_server_found -eq 1 ]] && [[ $line == *"location / "* ]]
        then
            location_found=1
            if [[ $nodejs_found -eq 0 ]] && [[ $https_ports == "${nginx_domain_servers_https_port[nginx_domain_server_index]}" ]] && [[ $http_ports == "${nginx_domain_servers_http_port[nginx_domain_server_index]}" ]]
            then
                if [ -n "$https_ports" ] && [ -n "$http_ports" ]
                then
                    scheme="\$scheme"
                    proxy_cookie_path=""
                elif [ -n "$https_ports" ] 
                then
                    scheme="https"
                    proxy_cookie_path="\n            proxy_cookie_path / /\$samesite_none;"
                else
                    scheme="http"
                    proxy_cookie_path=""
                fi

                line="        location = / {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location = /channels {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location = /channels.json {
            return 302 /channels;
        }

        location = /remote {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location = /remote.json {
            return 302 /remote;
        }

        location = /keys {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_cache_bypass 1;
            proxy_no_cache 1;$proxy_cookie_path
            proxy_cookie_domain localhost ${nginx_domains[nginx_domains_index]};
        }

        location ~ \.(keyinfo|key)$ {
            return 403;
        }\n\n$line"
                if [[ $add_header_found -eq 0 ]] 
                then
                    line="        add_header Access-Control-Allow-Origin \$corsHost;
        add_header Vary Origin;
        add_header X-Frame-Options SAMEORIGIN;
        add_header Access-Control-Allow-Credentials true;
        add_header Cache-Control no-cache;\n\n$line"
                fi
            fi
        fi

        if [ "${last_line:-}" == "#" ] && [ "$line" == "" ]
        then
            continue
        fi
        last_line="$line#"
        [ -n "$conf" ] && conf="$conf\n"
        conf="$conf$line"
    done < "/usr/local/nginx/conf/sites_available/${nginx_domains[nginx_domains_index]}.conf"
    unset last_line
    echo -e "$conf" > "/usr/local/nginx/conf/sites_available/${nginx_domains[nginx_domains_index]}.conf"
    Println "$info nodejs 配置修改成功\n"
}

NginxDomainUpdateCrt()
{
    Println "$info 更新证书..."
    if [ ! -e "$HOME/.acme.sh/acme.sh" ] 
    then
        Println "$info 检查依赖..."
        CheckRelease
        if [ "$release" == "rpm" ] 
        then
            yum -y install socat > /dev/null
        else
            apt-get -y install socat > /dev/null
        fi
        bash <(curl --silent -m 10 https://get.acme.sh) > /dev/null
    fi

    nginx -s stop 2> /dev/null || true
    sleep 1

    ~/.acme.sh/acme.sh --force --issue -d "${nginx_domains[nginx_domains_index]}" --standalone -k ec-256 > /dev/null
    ~/.acme.sh/acme.sh --force --installcert -d "${nginx_domains[nginx_domains_index]}" --fullchainpath /usr/local/nginx/conf/sites_crt/"${nginx_domains[nginx_domains_index]}".crt --keypath /usr/local/nginx/conf/sites_crt/"${nginx_domains[nginx_domains_index]}".key --ecc > /dev/null

    nginx
    Println "$info 证书更新完成..."
}

NginxEditDomain()
{
    NginxListDomains

    echo "输入序号"
    while read -p "(默认: 取消): " nginx_domains_index
    do
        case "$nginx_domains_index" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_domains_index" -gt 0 ] && [ "$nginx_domains_index" -le "$nginx_domains_count" ]
                then
                    nginx_domains_index=$((nginx_domains_index-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    action="edit"

    NginxListDomain

    echo "输入序号"
    while read -p "(默认: 取消): " nginx_domain_server_num
    do
        case "$nginx_domain_server_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            $nginx_domain_update_crt_number)
                NginxDomainUpdateCrt
                exit 0
            ;;
            $nginx_domain_add_server_number)
                NginxDomainAddServer
                exit 0
            ;;
            $nginx_domain_edit_server_number)
                NginxDomainEditServer
                exit 0
            ;;
            $nginx_domain_delete_server_number)
                NginxDomainDeleteServer
                exit 0
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_domain_server_num" -gt 0 ] && [ "$nginx_domain_server_num" -le "$nginx_domain_servers_count" ]
                then
                    nginx_domain_server_index=$((nginx_domain_server_num-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    Println "选择操作

  ${green}1.$plain 开关 flv 设置
  ${green}2.$plain 开关 nodejs 设置
  ${green}3.$plain 修改 http 端口
  ${green}4.$plain 修改 https 端口
    \n"
    while read -p "(默认：取消): " nginx_domain_server_action_num 
    do
        case $nginx_domain_server_action_num in
            "") 
                Println "已取消...\n" && exit 1
            ;;
            1) 
                NginxDomainServerToggleFlv
                break
            ;;
            2) 
                server_root=${nginx_domain_servers_root[nginx_domain_server_index]}
                if [ -z "$server_root" ] 
                then
                    NginxConfigServerRoot
                    NginxConfigServerLiveRoot
                fi
                NginxDomainServerToggleNodejs
                break
            ;;
            3) 
                NginxDomainServerEditHttpPorts
                break
            ;;
            4) 
                NginxDomainServerEditHttpsPorts
                break
            ;;
            *) Println "$error 输入错误\n"
            ;;
        esac
    done
}

NginxToggleDomain()
{
    NginxListDomains

    echo "输入序号"
    while read -p "(默认: 取消): " nginx_domains_index
    do
        case "$nginx_domains_index" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_domains_index" -gt 0 ] && [ "$nginx_domains_index" -le "$nginx_domains_count" ]
                then
                    nginx_domains_index=$((nginx_domains_index-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    server_domain=${nginx_domains[nginx_domains_index]}
    if [ "${nginx_domains_status[nginx_domains_index]}" -eq 1 ] 
    then
        NginxDisableDomain
        Println "$info $server_domain 关闭成功\n"
    else
        NginxEnableDomain
        Println "$info $server_domain 开启成功\n"
    fi
}

NginxDeleteDomain()
{
    NginxListDomains

    echo "输入序号"
    while read -p "(默认: 取消): " nginx_domains_index
    do
        case "$nginx_domains_index" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_domains_index" -gt 0 ] && [ "$nginx_domains_index" -le "$nginx_domains_count" ]
                then
                    nginx_domains_index=$((nginx_domains_index-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    server_domain=${nginx_domains[nginx_domains_index]}
    if [ "${nginx_domains_status[nginx_domains_index]}" -eq 1 ] 
    then
        NginxDisableDomain
    fi
    rm -f "/usr/local/nginx/conf/sites_available/$server_domain.conf"
    Println "$info $server_domain 删除成功\n"
}

DomainInstallCert()
{
    if [ -e "/usr/local/nginx/conf/sites_crt/$server_domain.crt" ] && [ -e "/usr/local/nginx/conf/sites_crt/$server_domain.key" ]
    then
        Println "$info 检测到证书已存在，是否重新安装证书 ? [y/N]"
        read -p "(默认: N): " reinstall_crt_yn
        reinstall_crt_yn=${reinstall_crt_yn:-N}
        if [[ $reinstall_crt_yn == [Nn] ]] 
        then
            return 0
        fi
    fi

    Println "$info 安装证书..."

    if [ ! -e "$HOME/.acme.sh/acme.sh" ] 
    then
        Println "$info 检查依赖..."
        CheckRelease
        if [ "$release" == "rpm" ] 
        then
            yum -y install socat > /dev/null
        else
            apt-get -y install socat > /dev/null
        fi
        bash <(curl --silent -m 10 https://get.acme.sh) > /dev/null
    fi

    nginx -s stop 2> /dev/null || true
    sleep 1

    ~/.acme.sh/acme.sh --force --issue -d "$server_domain" --standalone -k ec-256 > /dev/null
    ~/.acme.sh/acme.sh --force --installcert -d "$server_domain" --fullchainpath "/usr/local/nginx/conf/sites_crt/$server_domain.crt" --keypath "/usr/local/nginx/conf/sites_crt/$server_domain.key" --ecc > /dev/null

    nginx
    Println "$info 证书安装完成..."
}

PrettyConfig()
{
    last_line=""
    new_conf=""
    while IFS= read -r line 
    do
        if [ "$last_line" == "#" ] && [ "$line" == "" ]
        then
            continue
        fi
        last_line="$line#"
        [ -n "$new_conf" ] && new_conf="$new_conf\n"
        new_conf="$new_conf$line"
    done < <(echo -e "$conf")
    unset last_line
    conf=$new_conf
}

NginxConfigLocalhost()
{
    NginxCheckDomains
    NginxConfigSsl

    NginxConfigServerHttpPort
    NginxConfigServerRoot
    NginxConfigServerLiveRoot
    NginxConfigBlockAliyun

    conf=""

    server_conf=""
    server_found=0
    server_flag=0
    block_aliyun_done=0

    while IFS= read -r line 
    do
        new_line=""

        if [[ $line == *"server {"* ]] 
        then
            lead=${line%%[^[:blank:]]*}
            first_char=${line#${lead}}
            first_char=${first_char:0:1}
            if [[ $first_char != "#" ]] 
            then
                server_conf=""
                server_conf_new=""
                server_found=1
                localhost_found=0
                location_found=0
                skip_location=0
                flv_found=0
            fi
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            server_flag=$((server_flag+1))
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            server_flag=$((server_flag-1))
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *"listen "* ]] 
        then
            new_line="${line%%listen*}listen $server_http_port;"
        fi

        if [[ $server_found -eq 1 ]] && [[ $line == *" localhost;"* ]] 
        then
            localhost_found=1
        fi

        if [[ $server_found -eq 1 ]] && [[ $localhost_found -eq 1 ]] && [[ ${enable_nodejs:-0} -eq 1 ]] && [[ $location_found -eq 0 ]] && { [[ $line == *"location = / "* ]] || [[ $line == *"location = /channels.json "* ]] || [[ $line == *"location = /remote "* ]] || [[ $line == *"location = /remote.json "* ]] || [[ $line == *"location = /keys "* ]] || [[ $line == *"location ~ \.(keyinfo|key)"* ]] || [[ $skip_location -eq 1 ]]; }
        then
            if [[ $line == *"location = / "* ]] || [[ $line == *"location = /channels.json "* ]] || [[ $line == *"location = /remote "* ]] || [[ $line == *"location = /remote.json "* ]] || [[ $line == *"location = /keys "* ]] || [[ $line == *"location ~ \.(keyinfo|key)"* ]] 
            then
                skip_location=1
            elif [[ $line == *"}"* ]] 
            then
                skip_location=0
            fi
            continue
        fi

        if [[ $server_found -eq 1 ]] && [[ $localhost_found -eq 1 ]] && [[ $line == *"location /flv "* ]]
        then
            flv_found=1
        fi

        if [[ $server_found -eq 1 ]] && [[ $localhost_found -eq 1 ]] && [[ $flv_found -eq 1 ]]
        then
            if [[ $line == *"}"* ]] 
            then
                flv_found=0
            fi
            continue
        fi

        if [[ $server_found -eq 1 ]] && [[ $localhost_found -eq 1 ]] && [[ $line == *"add_header "* ]]
        then
            continue
        fi

        if [[ $server_found -eq 1 ]] && [[ $location_found -eq 1 ]] && [[ $line == *"}"* ]]
        then
            location_found=0
        fi

        if [[ $server_found -eq 1 ]] && [[ $localhost_found -eq 1 ]] && [[ $location_found -eq 0 ]] && [[ $line == *"location "* ]] && [[ $line == *" / "* ]] 
        then
            if [[ ${enable_nodejs:-0} -eq 1 ]] 
            then
                enable_nodejs=0
                server_ip=${server_ip:-$(GetServerIp)}
                line="        location = / {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto http;

            proxy_cache_bypass 1;
            proxy_no_cache 1;
            proxy_cookie_domain localhost $server_ip;
        }

        location = /channels {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto http;

            proxy_cache_bypass 1;
            proxy_no_cache 1;
            proxy_cookie_domain localhost $server_ip;
        }

        location = /channels.json {
            return 302 /channels;
        }

        location = /remote {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto http;

            proxy_cache_bypass 1;
            proxy_no_cache 1;
            proxy_cookie_domain localhost $server_ip;
        }

        location = /remote.json {
            return 302 /remote;
        }

        location = /keys {
            proxy_redirect off;
            proxy_pass http://nodejs;
            proxy_read_timeout 10s;
            proxy_send_timeout 10s;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto http;

            proxy_cache_bypass 1;
            proxy_no_cache 1;
            proxy_cookie_domain localhost $server_ip;
        }

        location ~ \.(keyinfo|key)$ {
            return 403;
        }\n\n$line"
            fi
            line="        add_header Access-Control-Allow-Origin \$corsHost;
        add_header Vary Origin;
        add_header X-Frame-Options SAMEORIGIN;
        add_header Access-Control-Allow-Credentials true;
        add_header Cache-Control no-cache;

        location /flv {
            flv_live on;
            chunked_transfer_encoding  on;
        }\n\n$line"
            location_found=1
        fi

        if [[ $server_found -eq 1 ]] && [[ $location_found -eq 1 ]] && [[ $block_aliyun_done -eq 0 ]] && [[ $line == *"{"* ]]
        then
            line="$line${deny_aliyun:-}"
            block_aliyun_done=1
        fi

        if [[ $server_found -eq 1 ]] && [[ $location_found -eq 1 ]] && [[ $line == *"root "* ]]
        then
            line="${line%%root*}root   ${server_root#*/usr/local/nginx/};"
        fi

        if [[ $server_found -eq 1 ]] 
        then
            [ -n "$server_conf" ] && server_conf="$server_conf\n"
            server_conf="$server_conf$line"
            [ -n "$server_conf_new" ] && server_conf_new="$server_conf_new\n"
            if [ -n "$new_line" ] 
            then
                server_conf_new="$server_conf_new$new_line"
            else
                server_conf_new="$server_conf_new$line"
            fi
            if [[ $server_flag -eq 0 ]] && [[ $line == *"}"* ]] 
            then
                server_found=0

                if [[ $localhost_found -eq 1 ]]
                then
                    line=$server_conf_new
                else
                    line=$server_conf
                fi
            fi
        fi

        if [[ $server_found -eq 0 ]] 
        then
            [ -n "$conf" ] && conf="$conf\n"
            conf="$conf$line"
        fi
    done < "/usr/local/nginx/conf/nginx.conf"

    PrettyConfig
    echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"

    NginxConfigCorsHost
    nginx -s stop 2> /dev/null || true
    nginx
    Println "$info localhost 配置成功\n"
}

NginxEnableDomain()
{
    ln -sf "/usr/local/nginx/conf/sites_available/$server_domain.conf" "/usr/local/nginx/conf/sites_enabled/$server_domain.conf"
    nginx -s stop 2> /dev/null || true
    nginx
}

NginxDisableDomain()
{
    rm -f "/usr/local/nginx/conf/sites_enabled/$server_domain.conf"
    nginx -s stop 2> /dev/null || true
    nginx
}

NginxAppendHttpConf()
{
    printf '%s' "    server {
        listen      $server_http_port;
        server_name $server_domain;

        access_log logs/access.log;

        add_header Access-Control-Allow-Origin \$corsHost;
        add_header Vary Origin;
        add_header X-Frame-Options SAMEORIGIN;
        add_header Access-Control-Allow-Credentials true;
        add_header Cache-Control no-cache;

        location / {${deny_aliyun:-}
            root   ${server_root#*/usr/local/nginx/};
            index  index.html index.htm;
        }
    }

" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAppendHttpRedirectConf()
{
    echo && read -p "输入网址: " http_redirect_address
    printf '%s' "    server {
        listen      $server_http_port;
        server_name $server_domain;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Connection \"\";

        location / {
            return 301 $http_redirect_address\$request_uri;
        }
    }

" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAppendHttpRedirectToHttpsConf()
{
    printf '%s' "    server {
        listen      $server_http_port;
        server_name $server_domain;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Connection \"\";

        location / {
            return 301 https://$server_domain\$request_uri;
        }
    }

" > "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAppendHttpsConf()
{
    printf '%s' "    server {
        listen      $server_https_port ssl;
        server_name $server_domain;

        access_log logs/access.log;

        ssl_certificate      /usr/local/nginx/conf/sites_crt/$server_domain.crt;
        ssl_certificate_key  /usr/local/nginx/conf/sites_crt/$server_domain.key;

        add_header Access-Control-Allow-Origin \$corsHost;
        add_header Vary Origin;
        add_header X-Frame-Options SAMEORIGIN;
        add_header Access-Control-Allow-Credentials true;
        add_header Cache-Control no-cache;

        location / {${deny_aliyun:-}
            root   ${server_root#*/usr/local/nginx/};
            index  index.html index.htm;
        }
    }

" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAppendHttpsRedirectConf()
{
    echo && read -p "输入网址: " https_redirect_address
    printf '%s' "    server {
        listen      $server_https_port;
        server_name $server_domain;

        access_log off;

        ssl_certificate      /usr/local/nginx/conf/sites_crt/$server_domain.crt;
        ssl_certificate_key  /usr/local/nginx/conf/sites_crt/$server_domain.key;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Connection \"\";

        location / {
            return 301 $https_redirect_address\$request_uri;
        }
    }

" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAppendHttpHttpsRedirectConf()
{
    echo && read -p "输入网址: " http_https_redirect_address
    printf '%s' "    server {
        listen      $server_http_port;
        listen      $server_https_port;
        server_name $server_domain;

        access_log off;

        ssl_certificate      /usr/local/nginx/conf/sites_crt/$server_domain.crt;
        ssl_certificate_key  /usr/local/nginx/conf/sites_crt/$server_domain.key;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Connection \"\";

        location / {
            return 301 $http_https_redirect_address\$request_uri;
        }
    }

" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAppendHttpHttpsConf()
{
    printf '%s' "    server {
        listen      $server_http_port;
        listen      $server_https_port ssl;
        server_name $server_domain;

        access_log logs/access.log;

        ssl_certificate      /usr/local/nginx/conf/sites_crt/$server_domain.crt;
        ssl_certificate_key  /usr/local/nginx/conf/sites_crt/$server_domain.key;

        add_header Access-Control-Allow-Origin \$corsHost;
        add_header Vary Origin;
        add_header X-Frame-Options SAMEORIGIN;
        add_header Access-Control-Allow-Credentials true;
        add_header Cache-Control no-cache;

        location / {${deny_aliyun:-}
            root   ${server_root#*/usr/local/nginx/};
            index  index.html index.htm;
        }
    }

" > "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

NginxAddDomain()
{
    NginxCheckDomains
    NginxListDomains
    NginxConfigSsl

    Println "输入指向本机的IP或域名"
    echo -e "$tip 多个域名用空格分隔\n"
    read -p "(默认: 取消): " domains

    if [ -n "$domains" ] 
    then
        IFS=" " read -ra new_domains <<< "$domains"
        for server_domain in "${new_domains[@]}"
        do
            if [ -e "/usr/local/nginx/conf/sites_available/$server_domain.conf" ] 
            then
                Println "$error $server_domain 已存在"
                continue
            fi

            if [[ $server_domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! $server_domain =~ ^[A-Za-z0-9.]*$ ]]
            then
                server_num=1
            else
                Println "选择网站类型

  ${green}1.$plain http
  ${green}2.$plain http => https
  ${green}3.$plain http +  https
 \n"
                read -p "请输入数字 [1-3]：" server_num
            fi

            case $server_num in
                1) 
                    NginxConfigServerHttpPort
                    Println "是否设置跳转到其它网址 ? [y/N]"
                    read -p "(默认: N): " http_redirect_yn
                    http_redirect_yn=${http_redirect_yn:-N}
                    if [[ $http_redirect_yn == "Y" ]] 
                    then
                        NginxAppendHttpRedirectConf
                    else
                        NginxConfigServerRoot
                        NginxConfigServerLiveRoot
                        NginxConfigBlockAliyun
                        NginxAppendHttpConf
                    fi
                    NginxConfigCorsHost
                    NginxEnableDomain
                    Println "$info $server_domain 配置成功\n"
                ;;
                2) 
                    DomainInstallCert

                    Println "是否设置 http 跳转 https ? [Y/n]"
                    read -p "(默认: Y): " http_to_https_yn
                    http_to_https_yn=${http_to_https_yn:-Y}
                    if [[ $http_to_https_yn == [Yy] ]] 
                    then
                        Println "$info 设置 $server_domain http 配置"
                        NginxConfigServerHttpPort
                        NginxAppendHttpRedirectToHttpsConf
                    fi

                    NginxConfigServerHttpsPort
                    Println "是否设置 https 跳转到其它网址 ? [y/N]"
                    read -p "(默认: N): " https_redirect_yn
                    https_redirect_yn=${https_redirect_yn:-N}
                    if [[ $https_redirect_yn == [Yy] ]] 
                    then
                        NginxAppendHttpsRedirectConf
                    else
                        NginxConfigServerRoot
                        NginxConfigServerLiveRoot
                        NginxConfigBlockAliyun
                        NginxAppendHttpsConf
                    fi
                    NginxConfigCorsHost
                    NginxEnableDomain
                    Println "$info $server_domain 配置成功\n"
                ;;
                3) 
                    DomainInstallCert
                    Println "http 和 https 是否使用相同的目录? [Y/n]"
                    read -p "(默认: Y): " http_https_same_dir_yn
                    http_https_same_dir_yn=${http_https_same_dir_yn:-Y}

                    if [[ $http_https_same_dir_yn == [Yy] ]] 
                    then
                        NginxConfigServerHttpPort
                        NginxConfigServerHttpsPort
                        Println "是否设置跳转到其它网址 ? [y/N]"
                        read -p "(默认: N): " http_https_redirect_yn
                        http_https_redirect_yn=${http_https_redirect_yn:-N}
                        if [[ $http_https_redirect_yn == "Y" ]] 
                        then
                            NginxAppendHttpHttpsRedirectConf
                        else
                            NginxConfigServerRoot
                            NginxConfigServerLiveRoot
                            NginxConfigBlockAliyun
                            NginxAppendHttpHttpsConf
                        fi
                    else
                        NginxConfigServerHttpPort
                        Println "是否设置 http 跳转到其它网址 ? [y/N]"
                        read -p "(默认: N): " http_redirect_yn
                        http_redirect_yn=${http_redirect_yn:-N}
                        if [[ $http_redirect_yn == [Yy] ]] 
                        then
                            NginxAppendHttpRedirectConf
                            NginxConfigServerHttpsPort

                            Println "是否设置 https 跳转到其它网址 ? [y/N]"
                            read -p "(默认: N): " https_redirect_yn
                            https_redirect_yn=${https_redirect_yn:-N}

                            if [[ $https_redirect_yn == [Yy] ]] 
                            then
                                NginxAppendHttpsRedirectConf
                            else
                                NginxConfigServerRoot
                                NginxConfigServerLiveRoot
                                NginxConfigBlockAliyun
                                NginxAppendHttpsConf
                            fi
                        else
                            NginxConfigServerRoot
                            NginxConfigServerLiveRoot
                            NginxConfigBlockAliyun

                            server_http_root=$server_root
                            server_http_live_root=$server_live_root
                            server_http_deny=$deny_aliyun

                            NginxConfigServerHttpsPort
                            Println "是否设置 https 跳转到其它网址 ? [y/N]"
                            read -p "(默认: N): " https_redirect_yn
                            https_redirect_yn=${https_redirect_yn:-N}

                            if [[ $https_redirect_yn == [Yy] ]] 
                            then
                                NginxAppendHttpConf
                                NginxAppendHttpsRedirectConf
                            else
                                server_root=""
                                server_live_root=""
                                deny_aliyun=""
                                NginxConfigServerRoot
                                NginxConfigServerLiveRoot
                                NginxConfigBlockAliyun

                                server_https_root=$server_root
                                server_https_live_root=$server_live_root
                                server_https_deny=$deny_aliyun

                                if [ "$server_http_root" == "$server_https_root" ] && [ "$server_http_live_root" == "$server_https_live_root" ] && [ "$server_http_deny" == "$server_https_deny" ]
                                then
                                    NginxAppendHttpHttpsConf
                                else
                                    NginxAppendHttpConf
                                    NginxAppendHttpsConf
                                fi
                            fi
                        fi
                    fi
                    NginxConfigCorsHost
                    NginxEnableDomain
                    Println "$info $server_domain 配置成功\n"
                ;;
                *) Println "已取消...\n" && exit 1
                ;;
            esac
        done
    else
        Println "已取消...\n" && exit 1
    fi
}

InstallNodejs()
{
    Println "$info 检查依赖，耗时可能会很长..."
    CheckRelease
    Progress &
    progress_pid=$!
    if [ "$release" == "rpm" ] 
    then
        yum -y install gcc-c++ make >/dev/null 2>&1
        # yum groupinstall 'Development Tools'
        if bash <(curl -sL https://rpm.nodesource.com/setup_10.x) > /dev/null
        then
            yum -y install nodejs >/dev/null 2>&1
        fi
    else
        if bash <(curl -sL https://deb.nodesource.com/setup_10.x) > /dev/null 
        then
            apt-get install -y nodejs >/dev/null 2>&1
        fi
    fi

    kill $progress_pid
    echo -n "...100%" && Println "$info nodejs 安装完成"
}

NodejsInstallMongodb()
{
    Println "$info 安装 mongodb, 请等待..."
    ulimit -f unlimited
    ulimit -t unlimited
    ulimit -v unlimited
    ulimit -n 64000
    ulimit -m unlimited
    ulimit -u 32000
    CheckRelease
    if [ "$release" == "rpm" ] 
    then
        printf '%s' "
[mongodb-org-4.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc
" > "/etc/yum.repos.d/mongodb-org-4.2.repo"
        yum install -y mongodb-org >/dev/null 2>&1
    else
        if ! wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | apt-key add - > /dev/null 2>&1
        then
            apt-get install gnupg >/dev/null 2>&1
            wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | apt-key add - > /dev/null
        fi

        if grep -q "xenial" < "/etc/apt/sources.list"
        then
            echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.2.list
        else
            echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.2.list
        fi

        apt-get -y update >/dev/null 2>&1
        apt-get install -y mongodb-org >/dev/null 2>&1
    fi

    if [[ $(ps --no-headers -o comm 1) == "systemd" ]] 
    then
        if ! systemctl start mongod > /dev/null 2>&1
        then
            systemctl daemon-reload
            systemctl start mongod > /dev/null 2>&1
        fi
    else
        service mongod start
    fi
    sleep 3
    Println "$info mongodb 安装成功"
}

NginxConfigSameSiteNone()
{
    if ! grep -q "map \$http_user_agent \$samesite_none" < "/usr/local/nginx/conf/nginx.conf"
    then
        conf=""
        found=0
        while IFS= read -r line 
        do
            if [ "$found" -eq 0 ] && [[ $line == *"server "* ]]
            then
                lead=${line%%[^[:blank:]]*}
                first_char=${line#${lead}}
                first_char=${first_char:0:1}
                if [[ $first_char != "#" ]] 
                then
                    line="
    map \$http_user_agent \$samesite_none {
        default \"; Secure\";
        \"~Chrom[^ \/]+\/8[\d][\.\d]*\" \"; Secure; SameSite=None\";
    }\n\n$line"
                    found=1
                fi
            fi
            [ -n "$conf" ] && conf="$conf\n"
            conf="$conf$line"
        done < "/usr/local/nginx/conf/nginx.conf"
        echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"
    fi
}

NginxConfigUpstream()
{
    conf=""
    upstream_found=0
    server_found=0
    while IFS= read -r line 
    do
        if [[ $line == *"upstream nodejs "* ]] 
        then
            upstream_found=2
        fi
        if [[ $upstream_found -eq 2 ]]
        then
            if [[ $line == *"server 127.0.0.1:"* ]] 
            then
                line="${line%server *}server 127.0.0.1:$nodejs_port;"
            elif [[ $line == *"}"* ]] 
            then
                upstream_found=1
            fi
        fi
        if [[ $upstream_found -eq 0 ]] && [[ $server_found -eq 0 ]] && [[ $line == *"server "* ]]
        then
            lead=${line%%[^[:blank:]]*}
            first_char=${line#${lead}}
            first_char=${first_char:0:1}
            if [[ $first_char != "#" ]] 
            then
                line="
    upstream nodejs {
        #ip_hash;
        server 127.0.0.1:$nodejs_port;
    }\n\n$line"
                server_found=1
            fi
        fi
        [ -n "$conf" ] && conf="$conf\n"
        conf="$conf$line"
    done < "/usr/local/nginx/conf/nginx.conf"
    echo -e "$conf" > "/usr/local/nginx/conf/nginx.conf"
}

NodejsConfig()
{
    enable_nodejs=1
    NginxCheckDomains
    NginxListDomains
    [ "$nginx_domains_count" -eq 0 ] && Println "$green域名列表:$plain\n\n无\n\n"
    config_localhost_num=$((nginx_domains_count+1))
    add_new_domain_num=$((nginx_domains_count+2))
    echo -e "$green$config_localhost_num.$plain 使用本地 IP\n\n$green$add_new_domain_num.$plain 添加域名\n\n"

    echo "输入序号"
    while read -p "(默认: $config_localhost_num): " nginx_domains_index
    do
        case "$nginx_domains_index" in
            ""|$config_localhost_num)
                nginx_domains_index=$config_localhost_num
                NginxConfigLocalhost
                break
            ;;
            $add_new_domain_num)
                NginxAddDomain
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_domains_index" -gt 0 ] && [ "$nginx_domains_index" -le "$add_new_domain_num" ]
                then
                    nginx_domains_index=$((nginx_domains_index-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    if [[ $nginx_domains_index -lt $nginx_domains_count ]] 
    then
        NginxListDomain

        echo "输入序号"
        while read -p "(默认: 取消): " nginx_domain_server_num
        do
            case "$nginx_domain_server_num" in
                "")
                    Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*)
                    Println "$error 请输入正确的序号\n"
                ;;
                *)
                    if [ "$nginx_domain_server_num" -gt 0 ] && [ "$nginx_domain_server_num" -le "$nginx_domain_servers_count" ]
                    then
                        nginx_domain_server_index=$((nginx_domain_server_num-1))
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done
        server_root=${nginx_domain_servers_root[nginx_domain_server_index]}
        if [ -z "$server_root" ] 
        then
            NginxConfigServerRoot
        fi
        NginxConfigServerLiveRoot
        NginxDomainServerToggleNodejs
        NginxConfigSsl
    fi

    NginxConfigSameSiteNone
    nodejs_port=$(GetFreePort)
    NginxConfigUpstream

    username=$(RandStr)
    password=$(RandStr)

    if [[ ! -x $(command -v mongo) ]] 
    then
        NodejsInstallMongodb
    fi

    if [[ $(ps --no-headers -o comm 1) == "systemd" ]] 
    then
        mongo admin --eval "db.getSiblingDB('admin').createUser({user: '${username}', pwd: '${password}', roles: ['root']})"
        systemctl restart mongod
    else
        mongo admin --eval "db.getSiblingDB('admin').createUser({user: '${username}', pwd: '${password}', roles: ['root']})"
        service mongod restart
    fi

    mkdir -p "$NODE_ROOT"
    echo "
const express = require('express');
const session = require('express-session');
const MongoDBStore = require('connect-mongodb-session')(session);

const store = new MongoDBStore({
    uri: 'mongodb://$username:$password@127.0.0.1/admin',
    databaseName: 'encrypt',
    collection: 'sessions'
});

const app = express();
const port = $nodejs_port;

app.set('trust proxy', 1);
app.use(session({name: '$(RandStr)', resave: false, saveUninitialized: true, secret: '$(RandStr)', store: store, cookie: { domain: 'localhost', maxAge: 60 * 60 * 1000, httpOnly: true }}));

app.get('/', function(req, res){
    sessionData = req.session || {};
    sessionData.websiteUser = true;
    res.sendFile('$server_root/index.html');
});

app.get('/remote', function(req, res){
    sessionData = req.session || {};
    sessionData.websiteUser = true;
    res.sendFile('$server_root/channels.json');
});

app.get('/channels', function(req, res){
    sessionData = req.session;
    if (!sessionData.websiteUser){
        res.send('error');
        return;
    }
    res.sendFile('$server_root/channels.json');
});

app.get('/keys', function(req, res){
    sessionData = req.session;
    if (!sessionData.websiteUser){
        res.send('error');
        return;
    }
    let keyName = req.query.key;
    let channelDirName = req.query.channel;
    if (keyName && channelDirName){
        res.sendFile('$server_live_root/${LIVE_ROOT##*/}/' + channelDirName + '/' + keyName + '.key');
    }
});

app.listen(port, () => console.log(\`App listening on port \${port}!\`))

" > "$NODE_ROOT/index.js"

    $JQ_FILE -n \
'{
  "name": "node",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1",
    "start": "node index.js"
  },
  "author": "",
  "license": "ISC",
  "dependencies": {
    "connect-mongodb-session": "^2.3.1",
    "express": "^4.17.1",
    "express-session": "^1.17.0"
  }
}' > "$NODE_ROOT/package.json"

    if [[ ! -x $(command -v git) ]] 
    then
        Println "$info 安装 git..."
        CheckRelease
        if [ "$release" == "rpm" ] 
        then
            yum -y install git > /dev/null
        elif [ "$release" == "ubu" ] 
        then
            add-apt-repository ppa:git-core/ppa -y > /dev/null 
            apt-get -y update
            apt-get -y install git > /dev/null
        else
            apt-get -y install git > /dev/null
        fi
        Println "$info git 安装成功...\n"
    fi

    cd "$NODE_ROOT"
    npm install
    npm install -g pm2
    pm2 start "$NODE_ROOT/index.js"
    Println "$info nodejs 配置完成"
}

Usage()
{
    usage=""
    while IFS= read -r line && [ "$line" ] ;do
        [ "${line:1:1}" = " " ] && usage="$usage${line:2}\n"
    done < "$0"
    Println "$usage\n"
    exit
}

UpdateSelf()
{
    GetDefault
    if [ "$d_version" != "$sh_ver" ] 
    then
        major_ver=${d_version%%.*}
        minor_ver=${d_version#*.}
        minor_ver=${minor_ver%%.*}

        if [ "$major_ver" -eq 1 ] && [ "$minor_ver" -lt 25 ]
        then
            Println "$info 需要先关闭所有频道，请稍等...\n"
            StopChannelsForce
        fi
        Println "$info 更新中，请稍等...\n"
        printf -v update_date '%(%m-%d)T'
        cp -f "$CHANNELS_FILE" "${CHANNELS_FILE}_$update_date"

        GetChannelsInfo

        d_input_flags=${d_input_flags//-timeout 2000000000/-rw_timeout 10000000}
        default=$(
        $JQ_FILE -n --arg proxy "$d_proxy" --arg user_agent "$d_user_agent" \
            --arg headers "$d_headers" --arg cookies "$d_cookies" \
            --arg playlist_name "$d_playlist_name" --arg seg_dir_name "$d_seg_dir_name" \
            --arg seg_name "$d_seg_name" --arg seg_length "$d_seg_length" \
            --arg seg_count "$d_seg_count" --arg video_codec "$d_video_codec" \
            --arg audio_codec "$d_audio_codec" --arg video_audio_shift "$d_video_audio_shift" \
            --arg quality "$d_quality" --arg bitrates "$d_bitrates" \
            --arg const "$d_const_yn" --arg encrypt "$d_encrypt_yn" \
            --arg encrypt_session "$d_encrypt_session_yn" \
            --arg keyinfo_name "$d_keyinfo_name" --arg key_name "$d_key_name" \
            --arg input_flags "$d_input_flags" \
            --arg output_flags "$d_output_flags" --arg sync "$d_sync_yn" \
            --arg sync_file "$d_sync_file" --arg sync_index "$d_sync_index" \
            --arg sync_pairs "$d_sync_pairs" --arg schedule_file "$d_schedule_file" \
            --arg flv_delay_seconds "$d_flv_delay_seconds" --arg flv_restart_nums "$d_flv_restart_nums" \
            --arg hls_delay_seconds "$d_hls_delay_seconds" --arg hls_min_bitrates "$d_hls_min_bitrates" \
            --arg hls_max_seg_size "$d_hls_max_seg_size" --arg hls_restart_nums "$d_hls_restart_nums" \
            --arg hls_key_period "$d_hls_key_period" --arg anti_ddos_port "$d_anti_ddos_port" \
            --arg anti_ddos_syn_flood "$d_anti_ddos_syn_flood_yn" --arg anti_ddos_syn_flood_delay_seconds "$d_anti_ddos_syn_flood_delay_seconds" \
            --arg anti_ddos_syn_flood_seconds "$d_anti_ddos_syn_flood_seconds" --arg anti_ddos "$d_anti_ddos_yn" \
            --arg anti_ddos_seconds "$d_anti_ddos_seconds" --arg anti_ddos_level "$d_anti_ddos_level" \
            --arg anti_leech "$d_anti_leech_yn" --arg anti_leech_restart_nums "$d_anti_leech_restart_nums" \
            --arg anti_leech_restart_flv_changes "$d_anti_leech_restart_flv_changes_yn" --arg anti_leech_restart_hls_changes "$d_anti_leech_restart_hls_changes_yn" \
            --arg recheck_period "$d_recheck_period" --arg version "$sh_ver" \
            '{
                proxy: $proxy,
                user_agent: $user_agent,
                headers: $headers,
                cookies: $cookies,
                playlist_name: $playlist_name,
                seg_dir_name: $seg_dir_name,
                seg_name: $seg_name,
                seg_length: $seg_length | tonumber,
                seg_count: $seg_count | tonumber,
                video_codec: $video_codec,
                audio_codec: $audio_codec,
                video_audio_shift: $video_audio_shift,
                quality: $quality,
                bitrates: $bitrates,
                const: $const,
                encrypt: $encrypt,
                encrypt_session: $encrypt_session,
                keyinfo_name: $keyinfo_name,
                key_name: $key_name,
                input_flags: $input_flags,
                output_flags: $output_flags,
                sync: $sync,
                sync_file: $sync_file,
                sync_index: $sync_index,
                sync_pairs: $sync_pairs,
                schedule_file: $schedule_file,
                flv_delay_seconds: $flv_delay_seconds | tonumber,
                flv_restart_nums: $flv_restart_nums | tonumber,
                hls_delay_seconds: $hls_delay_seconds | tonumber,
                hls_min_bitrates: $hls_min_bitrates | tonumber,
                hls_max_seg_size: $hls_max_seg_size | tonumber,
                hls_restart_nums: $hls_restart_nums | tonumber,
                hls_key_period: $hls_key_period | tonumber,
                anti_ddos_port: $anti_ddos_port,
                anti_ddos_syn_flood: $anti_ddos_syn_flood,
                anti_ddos_syn_flood_delay_seconds: $anti_ddos_syn_flood_delay_seconds | tonumber,
                anti_ddos_syn_flood_seconds: $anti_ddos_syn_flood_seconds | tonumber,
                anti_ddos: $anti_ddos,
                anti_ddos_seconds: $anti_ddos_seconds | tonumber,
                anti_ddos_level: $anti_ddos_level | tonumber,
                anti_leech: $anti_leech,
                anti_leech_restart_nums: $anti_leech_restart_nums | tonumber,
                anti_leech_restart_flv_changes: $anti_leech_restart_flv_changes,
                anti_leech_restart_hls_changes: $anti_leech_restart_hls_changes,
                recheck_period: $recheck_period | tonumber,
                version: $version
            }'
        )

        JQ replace "$CHANNELS_FILE" default "$default"

        new_channels=""

        for((i=0;i<chnls_count;i++));
        do
            [ -n "$new_channels" ] && new_channels="$new_channels,"

            new_input_flags=${chnls_input_flags[i]//-timeout 2000000000/-rw_timeout 10000000}
            new_channel=$(
            $JQ_FILE -n --arg pid "${chnls_pid[i]}" --arg status "${chnls_status[i]}" \
                --arg stream_link "${chnls_stream_links[i]}" --arg live "${chnls_live[i]}" \
                --arg proxy "${chnls_proxy[i]}" --arg user_agent "${chnls_user_agent[i]}" \
                --arg headers "${chnls_headers[i]}" --arg cookies "${chnls_cookies[i]}" \
                --arg output_dir_name "${chnls_output_dir_name[i]}" --arg playlist_name "${chnls_playlist_name[i]}" \
                --arg seg_dir_name "${chnls_seg_dir_name[i]}" --arg seg_name "${chnls_seg_name[i]}" \
                --arg seg_length "${chnls_seg_length[i]}" --arg seg_count "${chnls_seg_count[i]}" \
                --arg video_codec "${chnls_video_codec[i]}" --arg audio_codec "${chnls_audio_codec[i]}" \
                --arg video_audio_shift "${chnls_video_audio_shift[i]}" --arg quality "${chnls_quality[i]}" \
                --arg bitrates "${chnls_bitrates[i]}" --arg const "${chnls_const[i]}" \
                --arg encrypt "${chnls_encrypt[i]}" --arg encrypt_session "${chnls_encrypt_session[i]}" \
                --arg keyinfo_name "${chnls_keyinfo_name[i]}" \
                --arg key_name "${chnls_key_name[i]}" --arg key_time "${chnls_key_time[i]}" \
                --arg input_flags "$new_input_flags" --arg output_flags "${chnls_output_flags[i]}" \
                --arg channel_name "${chnls_channel_name[i]}" --arg channel_time "${chnls_channel_time[i]}" \
                --arg sync "${chnls_sync[i]}" \
                --arg sync_file "${chnls_sync_file[i]}" --arg sync_index "${chnls_sync_index[i]}" \
                --arg sync_pairs "${chnls_sync_pairs[i]}" --arg flv_status "${chnls_flv_status[i]}" \
                --arg flv_push_link "${chnls_flv_push_link[i]}" --arg flv_pull_link "${chnls_flv_pull_link[i]}" \
                '{
                    pid: $pid | tonumber,
                    status: $status,
                    stream_link: $stream_link,
                    live: $live,
                    proxy: $proxy,
                    user_agent: $user_agent,
                    headers: $headers,
                    cookies: $cookies,
                    output_dir_name: $output_dir_name,
                    playlist_name: $playlist_name,
                    seg_dir_name: $seg_dir_name,
                    seg_name: $seg_name,
                    seg_length: $seg_length | tonumber,
                    seg_count: $seg_count | tonumber,
                    video_codec: $video_codec,
                    audio_codec: $audio_codec,
                    video_audio_shift: $video_audio_shift,
                    quality: $quality,
                    bitrates: $bitrates,
                    const: $const,
                    encrypt: $encrypt,
                    encrypt_session: $encrypt_session,
                    keyinfo_name: $keyinfo_name,
                    key_name: $key_name,
                    key_time: $key_time | tonumber,
                    input_flags: $input_flags,
                    output_flags: $output_flags,
                    channel_name: $channel_name,
                    channel_time: $channel_time | tonumber,
                    sync: $sync,
                    sync_file: $sync_file,
                    sync_index: $sync_index,
                    sync_pairs: $sync_pairs,
                    flv_status: $flv_status,
                    flv_push_link: $flv_push_link,
                    flv_pull_link: $flv_pull_link
                }'
            )

            new_channels="$new_channels$new_channel"
        done

        JQ replace "$CHANNELS_FILE" channels "[$new_channels]"
    fi
    printf '%s' "" > ${LOCK_FILE}
}

if [ -e "$IPTV_ROOT" ] && [ ! -e "$LOCK_FILE" ] 
then
    UpdateSelf
fi

V2rayConfigInstall()
{
    printf -v update_date '%(%m-%d)T'
    cp -f "$V2_CONFIG" "${V2_CONFIG}_$update_date"
    while IFS= read -r line 
    do
        if [[ $line == *"port"* ]] 
        then
            port=${line#*: }
            port=${port%,*}
        elif [[ $line == *"id"* ]] 
        then
            id=${line#*: \"}
            id=${id%\"*}
            break
        fi
    done < "$V2_CONFIG"

    $JQ_FILE -n --arg port "${port:-$(GetFreePort)}" --arg id "${id:-$($V2CTL_FILE uuid)}" --arg path "${path:-/$(RandStr)}" \
'{
  "log": {
    "access": "none",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "error"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": $port | tonumber,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": $id,
            "level": 0,
            "alterId": 64,
            "email": "name@localhost"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": $path
        }
      },
      "tag": "nginx-1"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "PolicyObject": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 2,
        "downlinkOnly": 5,
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}' > "$V2_CONFIG"
}

V2rayConfigUpdate()
{
    if [ ! -e "$V2_CONFIG" ] 
    then
        Println "$error v2ray 未安装...\n" && exit 1
    fi
    if ! grep -q '"tag": "nginx-1"' < "$V2_CONFIG"
    then
        if grep -q '"path": "' < "$V2_CONFIG" 
        then
            while IFS= read -r line 
            do
                if [[ $line == *"path"* ]] 
                then
                    path=${line#*: \"}
                    path=${path%\"*}
                    break
                fi
            done < "$V2_CONFIG"
        fi
        V2rayConfigInstall
        Println "$info v2ray 配置文件已更新\n"
    fi
}

V2rayGetInbounds()
{
    inbounds_count=0
    inbounds_nginx_count=0
    inbounds_nginx_index=()
    inbounds_forward_count=0
    inbounds_listen=()
    inbounds_port=()
    inbounds_protocol=()
    inbounds_network=()
    inbounds_path=()
    inbounds_tag=()
    inbounds_timeout=()
    inbounds_allow_transparent=()
    inbounds_user_level=()

    while IFS= read -r inbound
    do
        map_listen=${inbound#*listen: }
        map_listen=${map_listen%, port:*}
        map_port=${inbound#*, port: }
        map_port=${map_port%, protocol:*}
        map_protocol=${inbound#*, protocol: }
        map_protocol=${map_protocol%, network:*}
        map_network=${inbound#*, network: }
        map_network=${map_network%, path:*}
        [ "$map_network" == null ] && map_network=""
        map_path=${inbound#*, path: }
        map_path=${map_path%, tag:*}
        [ "$map_path" == null ] && map_path=""
        map_tag=${inbound#*, tag: }
        map_tag=${map_tag%, timeout:*}
        if [ "${map_tag:0:6}" == "nginx-" ] 
        then
            inbounds_nginx_count=$((inbounds_nginx_count+1))
            inbounds_nginx_index+=("$inbounds_count")
        else
            inbounds_forward_count=$((inbounds_forward_count+1))
        fi
        map_timeout=${inbound#*, timeout: }
        map_timeout=${map_timeout%, allowTransparent:*}
        [ "$map_timeout" == null ] && map_timeout=""
        map_allow_transparent=${inbound#*, allowTransparent: }
        map_allow_transparent=${map_allow_transparent%, userLevel:*}
        [ "$map_allow_transparent" == null ] && map_allow_transparent=""
        map_user_level=${inbound#*, userLevel: }
        map_user_level=${map_user_level%\"}
        [ "$map_user_level" == null ] && map_user_level=""

        inbounds_listen+=("$map_listen")
        inbounds_port+=("$map_port")
        inbounds_protocol+=("$map_protocol")
        inbounds_network+=("$map_network")
        inbounds_path+=("$map_path")
        inbounds_tag+=("$map_tag")
        inbounds_timeout+=("$map_timeout")
        inbounds_allow_transparent+=("$map_allow_transparent")
        inbounds_user_level+=("$map_user_level")
        inbounds_count=$((inbounds_count+1))
    done < <($JQ_FILE '.inbounds | to_entries | map("listen: \(.value.listen), port: \(.value.port), protocol: \(.value.protocol), network: \(.value.streamSettings.network), path: \(.value.streamSettings.wsSettings.path), tag: \(.value.tag), timeout: \(.value.settings.timeout), allowTransparent: \(.value.settings.allowTransparent), userLevel: \(.value.settings.userLevel)") | .[]' "$V2_CONFIG")

    return 0
}

V2rayGetOutbounds()
{
    outbounds_count=0
    outbounds_index=0
    outbounds_vmess_count=0
    outbounds_http_count=0
    outbounds_https_count=0
    outbounds_protocol=()
    outbounds_tag=()
    outbounds_security=()
    outbounds_allow_insecure=()
    outbounds_proxy_settings_tag=()

    while IFS= read -r outbound
    do
        map_protocol=${outbound#*protocol: }
        map_protocol=${map_protocol%, tag:*}
        map_tag=${outbound#*, tag: }
        map_tag=${map_tag%, proxy_settings_tag:*}
        [ "$map_tag" == null ] && map_tag=""
        map_proxy_settings_tag=${outbound#*, proxy_settings_tag: }
        map_proxy_settings_tag=${map_proxy_settings_tag%, security:*}
        [ "$map_proxy_settings_tag" == null ] && map_proxy_settings_tag=""
        map_security=${outbound#*, security: }
        map_security=${map_security%, allowInsecure:*}
        [ "$map_security" == null ] && map_security=""
        map_allow_insecure=${outbound#*, allowInsecure: }
        map_allow_insecure=${map_allow_insecure%\"}
        [ "$map_allow_insecure" == null ] && map_allow_insecure=""

        if [ -n "$map_tag" ] 
        then
            if [ -n "$map_proxy_settings_tag" ] 
            then
                outbounds_proxy_settings_tag+=("$map_proxy_settings_tag")
            else
                outbounds_proxy_settings_tag+=("")
            fi
            if [ "$map_tag" != "blocked" ] 
            then
                outbounds_count=$((outbounds_count+1))
                if [ "$map_protocol" == "vmess" ] 
                then
                    outbounds_vmess_count=$((outbounds_vmess_count+1))
                elif [ "$map_protocol" == "http" ] 
                then
                    if [ -n "$map_security" ] 
                    then
                        outbounds_https_count=$((outbounds_https_count+1))
                    else
                        outbounds_http_count=$((outbounds_http_count+1))
                    fi
                fi
                outbounds_protocol+=("$map_protocol")
                outbounds_tag+=("$map_tag")
                outbounds_security+=("$map_security")
                outbounds_allow_insecure+=("$map_allow_insecure")
            fi
        fi

        outbounds_index=$((outbounds_index+1))

    done < <($JQ_FILE '.outbounds | to_entries | map("protocol: \(.value.protocol), tag: \(.value.tag), proxy_settings_tag: \(.value.proxySettings.tag), security: \(.value.streamSettings.security), allowInsecure: \(.value.streamSettings.tlsSettings.allowInsecure)") | .[]' "$V2_CONFIG")

    outbounds_proxy_forward=()
    for((i=0;i<${#outbounds_tag[@]};i++));
    do
        found=0
        for((j=0;j<${#outbounds_proxy_settings_tag[@]};j++));
        do
            if [ "${outbounds_proxy_settings_tag[j]}" == "${outbounds_tag[i]}" ] 
            then
                found=1
                outbounds_proxy_forward+=("true")
                break
            fi
        done

        if [ "$found" -eq 0 ] 
        then
            outbounds_proxy_forward+=("false")
        fi
    done
}

V2rayGetRules()
{
    rules_outbound_tag=()
    while IFS= read -r outbound_tag 
    do
        rules_outbound_tag+=("$outbound_tag")
    done < <($JQ_FILE '.routing.rules | to_entries | map("\(.value.outboundTag)") | .[]' "$V2_CONFIG")
    rules_count=${#rules_outbound_tag[@]}
}

V2rayGetLevels()
{
    levels_id=()
    levels_handshake=()
    levels_connIdle=()
    levels_uplinkOnly=()
    levels_downlinkOnly=()
    levels_statsUserUplink=()
    levels_statsUserDownlink=()
    levels_bufferSize=()
    while IFS= read -r level 
    do
        map_id=${level#*id: }
        map_id=${map_id%, handshake:*}
        map_handshake=${level#*, handshake: }
        map_handshake=${map_handshake%, connIdle:*}
        map_connIdle=${level#*, connIdle: }
        map_connIdle=${map_connIdle%, uplinkOnly:*}
        map_uplinkOnly=${level#*, uplinkOnly: }
        map_uplinkOnly=${map_uplinkOnly%, downlinkOnly:*}
        map_downlinkOnly=${level#*, downlinkOnly: }
        map_downlinkOnly=${map_downlinkOnly%, statsUserUplink:*}
        map_statsUserUplink=${level#*, statsUserUplink: }
        map_statsUserUplink=${map_statsUserUplink%, statsUserDownlink:*}
        map_statsUserDownlink=${level#*, statsUserDownlink: }
        map_statsUserDownlink=${map_statsUserDownlink%, bufferSize:*}
        map_bufferSize=${level#*, bufferSize: }
        map_bufferSize=${map_bufferSize%\"}
        [ "$map_bufferSize" == null ] && map_bufferSize=""

        levels_id+=("$map_id")
        levels_handshake+=("$map_handshake")
        levels_connIdle+=("$map_connIdle")
        levels_uplinkOnly+=("$map_uplinkOnly")
        levels_downlinkOnly+=("$map_downlinkOnly")
        levels_statsUserUplink+=("$map_statsUserUplink")
        levels_statsUserDownlink+=("$map_statsUserDownlink")
        levels_bufferSize+=("$map_bufferSize")
    done < <($JQ_FILE '.PolicyObject.levels | to_entries | map("id: \(.key), handshake: \(.value.handshake), connIdle: \(.value.connIdle), uplinkOnly: \(.value.uplinkOnly), downlinkOnly: \(.value.downlinkOnly), statsUserUplink: \(.value.statsUserUplink), statsUserDownlink: \(.value.statsUserDownlink), bufferSize: \(.value.bufferSize)") | .[]' "$V2_CONFIG")
    levels_count=${#levels_id[@]}
}

V2rayListForward()
{
    V2rayGetInbounds
    V2rayGetOutbounds

    echo && Println "=== 入站转发账号组数 $green $inbounds_forward_count $plain\n"

    inbounds_forward_list=""
    index=0
    for((i=0;i<inbounds_count;i++));
    do
        if [[ ${inbounds_tag[i]} == "nginx-"* ]] 
        then
            continue
        fi

        index=$((index+1))
        if [ "$index" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi

        if [ -n "${inbounds_network[i]}" ] 
        then
            stream_settings_list="\n     网络: $green${inbounds_network[i]}$plain 路径: $green${inbounds_path[i]}$plain 加密: $green否$plain"
        else
            stream_settings_list=""
        fi

        if [ -n "${inbounds_timeout[i]}" ] 
        then
            http_list="\n     超时: $green${inbounds_timeout[i]}$plain 转发所有请求: $green${inbounds_allow_transparent[i]}$plain 等级: $green${inbounds_user_level[i]}$plain"
        else
            http_list=""
        fi

        inbounds_forward_list=$inbounds_forward_list"# $green$index$plain $blank组名: $green${inbounds_tag[i]}$plain 协议: $green${inbounds_protocol[i]}$plain 地址: $green${inbounds_listen[i]}:${inbounds_port[i]}$plain$stream_settings_list$http_list\n\n"
    done
    [ -n "$inbounds_forward_list" ] && echo -e "$inbounds_forward_list\n"

    Println "=== 出站转发账号组数 $green $outbounds_count $plain\n"

    outbounds_list=""
    for((i=0;i<outbounds_count;i++));
    do
        if [ "$i" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi

        if [ -n "${outbounds_security[i]}" ] 
        then
            protocol="https"
            stream_settings_list="\n     security: $green${outbounds_security[i]}$plain 检测证书有效性: $green${outbounds_allow_insecure[i]}$plain"
        else
            protocol=${outbounds_protocol[i]}
            stream_settings_list=""
        fi

        if [ -n "${outbounds_proxy_settings_tag[i]}" ] 
        then
            proxy_list="\n     前置代理: $green终$plain"
        elif [ "${outbounds_proxy_forward[i]}" == "true" ] 
        then
            proxy_list="\n     前置代理: $green始$plain"
        else
            proxy_list=""
        fi

        outbounds_list=$outbounds_list"# $green$((i+inbounds_forward_count+1))$plain $blank组名: $green${outbounds_tag[i]}$plain 协议: $green$protocol$plain$stream_settings_list$proxy_list\n\n"
    done
    [ -n "$outbounds_list" ] && echo -e "$outbounds_list\n"
    return 0
}

V2rayListNginx()
{
    V2rayGetInbounds

    [ "$inbounds_nginx_count" -eq 0 ] && Println "$error 没有账号组\n" && exit 1

    Println "\n=== Nginx 账号组数 $green $inbounds_nginx_count $plain"

    nginx_list=""

    for((i=0;i<inbounds_nginx_count;i++));
    do
        inbounds_index=${inbounds_nginx_index[i]}
        if [ "$i" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi
        if [ -n "${inbounds_network[inbounds_index]}" ] 
        then
            stream_settings_list="\n     网络: $green${inbounds_network[inbounds_index]}$plain 路径: $green${inbounds_path[inbounds_index]}$plain 加密: $green否$plain"
        else
            stream_settings_list=""
        fi
        nginx_list=$nginx_list"# $green$((i+1))$plain $blank组名: $green${inbounds_tag[inbounds_index]}$plain 协议: $green${inbounds_protocol[inbounds_index]}$plain 地址: $green${inbounds_listen[inbounds_index]}:${inbounds_port[inbounds_index]}$plain$stream_settings_list\n\n"
    done

    Println "$nginx_list\n"
}

V2rayDeleteNginx()
{
    echo "输入序号"
    while read -p "(默认: 取消): " nginx_num
    do
        case "$nginx_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_num" -gt 0 ] && [ "$nginx_num" -le $inbounds_nginx_count ]
                then
                    nginx_num=$((nginx_num-1))
                    nginx_index=${inbounds_nginx_index[nginx_num]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    jq_path='["inbounds"]'
    JQ delete "$V2_CONFIG" "$nginx_index"
    Println "$info 账号组删除成功\n"
}

V2rayStatus()
{
    if service v2ray status > /dev/null 2>&1
    then
        Println "v2ray: $green开启$plain\n"
    else
        Println "v2ray: $red关闭$plain\n"
    fi
}

V2rayListNginxAccounts()
{
    echo "输入序号"
    while read -p "(默认: 取消): " nginx_num
    do
        case "$nginx_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_num" -gt 0 ] && [ "$nginx_num" -le $inbounds_nginx_count ]
                then
                    nginx_num=$((nginx_num-1))
                    nginx_index=${inbounds_nginx_index[nginx_num]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    accounts_count=0
    accounts_list=""
    while IFS=' ' read -r map_id map_level map_alter_id map_email
    do
        accounts_count=$((accounts_count+1))
        if [ "$accounts_count" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi
        accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}ID: $green$map_id$plain 等级: $green$map_level$plain alterId: $green$map_alter_id$plain 邮箱: $green$map_email$plain\n\n"
    done < <($JQ_FILE -r '.inbounds['"$nginx_index"'].settings.clients | to_entries | map("\(.value.id) \(.value.level) \(.value.alterId) \(.value.email)") | .[]' "$V2_CONFIG")

    V2rayListDomainsInbound

    if [ -n "$accounts_list" ] 
    then
        echo "可用账号:"
        Println "$accounts_list\n"
    else
        Println "此账号组没有账号\n"
    fi
}

V2raySetNginxTag()
{
    echo "输入组名"
    read -p "(默认：随机): " tag
    i=0
    while true 
    do
        i=$((i+1))
        tag="nginx-$i"
        if ! grep -q '"tag": "'"$tag"'"' < "$V2_CONFIG"
        then
            break
        fi
    done
    Println "	组名: $green $tag $plain\n"
}

V2rayAddNginx()
{
    listen="127.0.0.1"
    echo
    V2raySetPort
    protocol="vmess"
    V2raySetNginxTag
    V2raySetStreamSettings

    new_inbound=$(
    $JQ_FILE -n --arg listen "$listen" --arg port "$port" \
        --arg protocol "$protocol" --arg network "$network" \
        --arg path "$path" --arg tag "$tag" \
    '{
        "listen": $listen,
        "port": $port | tonumber,
        "protocol": $protocol,
        "settings": {
            "clients": []
        },
        "streamSettings": {
        "network": $network,
        "wsSettings": {
            "path": $path
        }
        },
        "tag": $tag
    }')

    JQ add "$V2_CONFIG" inbounds "[$new_inbound]"

    Println "$info 账号组添加成功\n"
}

V2rayAddNginxAccount()
{
    [ "$inbounds_nginx_count" -eq 0 ] && Println "$error 没有账号组, 请先添加组\n" && exit 1
    echo -e "输入组序号"
    while read -p "(默认: 取消): " nginx_num
    do
        case "$nginx_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_num" -gt 0 ] && [ "$nginx_num" -le $inbounds_nginx_count ]
                then
                    nginx_num=$((nginx_num-1))
                    nginx_index=${inbounds_nginx_index[nginx_num]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    V2raySetLevel
    V2raySetId
    V2raySetAlterId
    V2raySetEmail
    jq_path='["inbounds",'"$nginx_index"',"settings","clients"]'
    new_account=$(
    $JQ_FILE -n --arg id "$id" --arg level "$level" \
        --arg alterId "$alter_id" --arg email "$email" \
    '{
        "id": $id,
        "level": $level | tonumber,
        "alterId": $alterId | tonumber,
        "email": $email
    }')

    JQ add "$V2_CONFIG" "[$new_account]"
    Println "$info 账号添加成功\n"
}

V2rayDeleteNginxAccount()
{
    echo "输入序号"
    while read -p "(默认: 取消): " nginx_num
    do
        case "$nginx_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_num" -gt 0 ] && [ "$nginx_num" -le $inbounds_nginx_count ]
                then
                    nginx_num=$((nginx_num-1))
                    nginx_index=${inbounds_nginx_index[nginx_num]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    accounts_count=0
    accounts_list=""
    while IFS=' ' read -r map_id map_level map_alter_id map_email
    do
        accounts_count=$((accounts_count+1))
        if [ "$accounts_count" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi
        accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}ID: $green$map_id$plain 等级: $green$map_level$plain alterId: $green$map_alter_id$plain 邮箱: $green$map_email$plain\n\n"
    done < <($JQ_FILE -r '.inbounds['"$nginx_index"'].settings.clients | to_entries | map("\(.value.id) \(.value.level) \(.value.alterId) \(.value.email)") | .[]' "$V2_CONFIG")

    if [ -z "$accounts_list" ] 
    then
        Println "$error 此账户组没有账号\n" && exit 1
    else
        V2rayListDomainsInbound
        accounts_list=$accounts_list"# $green$((accounts_count+1))$plain ${blank}删除所有账号"
        echo -e "可用账号:\n\n$accounts_list\n"
        echo "输入序号"
        while read -p "(默认: 取消): " accounts_index
        do
            case "$accounts_index" in
                "")
                    Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*)
                    Println "$error 请输入正确的序号\n"
                ;;
                *)
                    if [ "$accounts_index" -gt 0 ] && [ "$accounts_index" -le $((accounts_count+1)) ]
                    then
                        accounts_index=$((accounts_index-1))
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done

        if [ "$accounts_index" == "$accounts_count" ] 
        then
            jq_path='["inbounds",'"$match_index"',"settings","clients"]'
            JQ replace "$V2_CONFIG" "[]"
        else
            jq_path='["inbounds",'"$match_index"',"settings","clients"]'
            JQ delete "$V2_CONFIG" "$accounts_index"
        fi
        Println "$info 账号删除成功\n"
    fi
}

GetFreePort() {
    read lport uport < /proc/sys/net/ipv4/ip_local_port_range
    while true
    do
        candidate=$((lport+RANDOM%(uport-lport)))
        if ! ( echo -n "" >/dev/tcp/127.0.0.1/"$candidate" )  >/dev/null 2>&1
        then
            echo "$candidate"
            break
        fi
    done
}

V2raySetListen()
{
    if [ "$forward_num" -eq 1 ] || [ "$forward_num" -eq 3 ]
    then
        Println "是否对外公开 ? [y/N]"
        read -p "(默认: N): " public_address_yn
        public_address_yn=${public_address_yn:-N}
        if [[ $public_address_yn == [Yy] ]]
        then
            listen="0.0.0.0"
        else
            listen="127.0.0.1"
        fi
    else
        listen="0.0.0.0"
    fi

    Println "	监听地址: $green $listen $plain\n"
}

V2raySetAddress()
{
    echo "输入服务器地址(ip或域名)"
    read -p "(默认：取消): " address
    [ -z "$address" ] && Println "已取消...\n" && exit 1
    Println "	服务器地址: $green $address $plain\n"
}

V2raySetPort()
{
    echo "请输入端口"
    while read -p "(默认: 随机生成): " port
    do
        case "$port" in
            "")
                port=$(GetFreePort)
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字！(1-65535) \n"
            ;;
            *)
                if [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
                then
                    if ( echo -n "" >/dev/tcp/127.0.0.1/"$port" )  >/dev/null 2>&1
                    then
                        Println "$error 端口已被其他程序占用！请重新输入！ \n"
                    else
                        break
                    fi
                else
                    Println "$error 请输入正确的数字！(1-65535) \n"
                fi
            ;;
        esac
    done

    Println "	端口: $green $port $plain\n"
}

V2raySetOutboundsPort()
{
    echo "请输入端口"
    while read -p "(默认: 取消): " port
    do
        case "$port" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字！\n"
            ;;
            *)
                if [ "$port" -gt 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字！\n"
                fi
            ;;
        esac
    done
    Println "	端口: $green $port $plain\n"
}

V2raySetProtocol()
{
    echo -e "选择协议

  ${green}1.$plain vmess
  ${green}2.$plain http
 \n"
    while true 
    do
        if [ "$forward_num" -eq 1 ] 
        then
            read -p "(默认：2): " protocol_num
            protocol_num=${protocol_num:-2}
        else
            read -p "(默认：1): " protocol_num
            protocol_num=${protocol_num:-1}
        fi
        case $protocol_num in
            1) 
                protocol="vmess"
                break
            ;;
            2) 
                protocol="http"
                break
            ;;
            *) Println "$error 输入错误\n"
            ;;
        esac
    done

    Println "	协议: $green $protocol $plain\n"
}

V2raySetStreamSettings()
{
    echo -e "选择网络类型

  ${green}1.$plain tcp
  ${green}2.$plain kcp
  ${green}3.$plain ws
  ${green}4.$plain http
  ${green}5.$plain domainsocket
  ${green}6.$plain quic\n"
    while read -p "(默认：3): " network_num 
    do
        case $network_num in
            1) 
                network="tcp"
                break
            ;;
            2) 
                network="kcp"
                break
            ;;
            ""|3) 
                network="ws"
                break
            ;;
            4) 
                network="http"
                break
            ;;
            5) 
                network="domainsocket"
                break
            ;;
            6) 
                network="quic"
                break
            ;;
            *) Println "$error 输入错误\n"
            ;;
        esac
    done
    Println "	网络: $green $protocol $plain\n"
    if [ "$network" == "ws" ] 
    then
        path="/$(RandStr)"
        echo -e "	路径: $green $path $plain\n"
    fi
}

V2raySetId()
{
    echo "输入 id"
    read -p "(默认：随机): " id
    id=${id:-$($V2CTL_FILE uuid)}

    Println "	id: $green $id $plain\n"
}

V2raySetAlterId()
{
    echo -e "请输入 alterId"
    while read -p "(默认: 64): " alter_id
    do
        case "$alter_id" in
            "")
                alter_id=64
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字(0-65535) \n"
            ;;
            *)
                if [ "$alter_id" -ge 0 ] && [ "$alter_id" -le 65535 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(0-65535)\n"
                fi
            ;;
        esac
    done
    Println "	alterId: $green $alter_id $plain\n"
}

V2raySetEmail()
{
    echo "输入邮箱"
    read -p "(默认：随机): " email
    email=${email:-$(RandStr)@localhost}

    Println "	邮箱: $green $email $plain\n"
}

V2raySetTimeout()
{
    echo -e "入站数据的时间限制(秒)"
    while read -p "(默认: 60): " timeout
    do
        case "$timeout" in
            "")
                timeout=60
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的数字(大于0) \n"
            ;;
            *)
                if [ "$timeout" -gt 0 ]
                then
                    break
                else
                    Println "$error 请输入正确的数字(大于0)\n"
                fi
            ;;
        esac
    done
    Println "	timeout: $green $timeout $plain\n"
}

V2raySetAllowTransparent()
{
    echo "转发所有 HTTP 请求, 而非只是代理请求 ? [y/N]"
    echo -e "$tip 若配置不当，开启此选项会导致死循环\n"
    read -p "(默认: N): " allow_transparent_yn
    allow_transparent_yn=${allow_transparent_yn:-N}
    if [[ $allow_transparent_yn == [Yy] ]]
    then
        allow_transparent="true"
    else
        allow_transparent="false"
    fi
    Println "	allowTransparent: $green $allow_transparent $plain\n" 
}

V2raySetAllowInsecure()
{
    echo "是否检测证书有效性 ? [Y/n]"
    echo -e "$tip 在自定义证书的情况开可以关闭\n"
    read -p "(默认: Y): " allow_insecure_yn
    allow_insecure_yn=${allow_insecure_yn:-Y}
    if [[ $allow_insecure_yn == [Yy] ]]
    then
        allow_insecure="false"
    else
        allow_insecure="true"
    fi
    Println "	allowInsecure: $green $allow_insecure $plain\n" 
}

V2rayListLevels()
{
    V2rayGetLevels
    Println "\n=== 用户等级数 $green $levels_count $plain"

    levels_list=""
    for((i=0;i<levels_count;i++));
    do
        if [ "$i" -lt 9 ] 
        then
            blank=" "
        else
            blank=""
        fi

        if [ -n "${levels_bufferSize[i]}" ] 
        then
            buffer_size=${levels_bufferSize[i]}
            buffer_size_list=" bufferSize: $green${buffer_size}$plain"
        else
            buffer_size=""
            buffer_size_list=" bufferSize: $green自动$plain"
        fi

        levels_list=$levels_list"# $green$((i+1))$plain $blank等级: $green${levels_id[i]}$plain 握手: $green${levels_handshake[i]}$plain 超时: $green${levels_connIdle[i]}$plain\n     下行中断: $green${levels_uplinkOnly[i]}$plain 上行中断: $green${levels_downlinkOnly[i]}$plain\n     上行流量统计: $green${levels_statsUserUplink[i]}$plain 下行流量统计: $green${levels_statsUserDownlink[i]}$plain$buffer_size_list\n\n"
    done
    Println "$levels_list\n"
    return 0
}

V2raySetLevel()
{
    V2rayListLevels
    echo -e "选择等级"
    while read -p "(默认: 1): " level
    do
        case "$level" in
            "")
                level=0
                break
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$level" -gt 0 ] && [ "$level" -le $((levels_count+1)) ]
                then
                    level=$((level-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done
    Println "	等级: $green $level $plain\n"
}

V2raySetHttpAccount()
{
    echo "输入用户名"
    read -p "(默认：随机): " user
    user=${user:-$(RandStr)}

    Println "	用户名: $green $user $plain\n"

    echo "输入密码"
    read -p "(默认：随机): " pass
    pass=${pass:-$(RandStr)}

    Println "	密码: $green $pass $plain\n"
}

GetFreeTag()
{
    while true 
    do
        free_tag=$(RandStr)
        if ! grep -q '"tag": "'"$free_tag"'"' < "$V2_CONFIG"
        then
            echo "$free_tag"
            break
        fi
    done
}

V2raySetTag()
{
    echo "输入组名"
    read -p "(默认：随机): " tag
    tag=${tag//nginx-/}
    tag=${tag:-$(GetFreeTag)}

    Println "	组名: $green $tag $plain\n"
}

V2raySetSecurity()
{
    echo -e "选择加密方式

  ${green}1.$plain aes-128-gcm
  ${green}2.$plain chacha20-poly1305
  ${green}3.$plain auto
  ${green}4.$plain none
    \n"
    while read -p "(默认：3): " security_num 
    do
        case $security_num in
            1) 
                security="aes-128-gcm"
                break
            ;;
            2) 
                security="chacha20-poly1305"
                break
            ;;
            ""|3) 
                security="auto"
                break
            ;;
            *) Println "$error 输入错误\n"
            ;;
        esac
    done
    Println "	加密方式: $green $security $plain\n"
}

V2rayAddInbound()
{
    V2raySetListen
    V2raySetPort
    V2raySetProtocol
    V2raySetLevel
    V2raySetTag

    if [ "$protocol" == "vmess" ] 
    then
        V2raySetStreamSettings

        new_inbound=$(
        $JQ_FILE -n --arg listen "$listen" --arg port "$port" \
            --arg protocol "$protocol" --arg network "$network" \
            --arg path "$path" --arg tag "$tag" \
        '{
            "listen": $listen,
            "port": $port | tonumber,
            "protocol": "vmess",
            "settings": {
                "clients": []
            },
            "streamSettings": {
            "network": $network,
            "wsSettings": {
                "path": $path
            }
            },
            "tag": $tag
        }')
    else
        V2raySetTimeout
        V2raySetAllowTransparent

        new_inbound=$(
        $JQ_FILE -n --arg listen "$listen" --arg port "$port" \
            --arg protocol "$protocol" --arg timeout "$timeout" \
            --arg allowTransparent "$allow_transparent" --arg userLevel "$level" --arg tag "$tag" \
        '{
            "listen": $listen,
            "port": $port | tonumber,
            "protocol": "http",
            "settings": {
                "timeout": $timeout | tonumber,
                "accounts": [],
                "allowTransparent": $allowTransparent | test("true"),
                "userLevel": $userLevel | tonumber
            },
            "tag": $tag
        }')
    fi

    JQ add "$V2_CONFIG" inbounds "[$new_inbound]"

    Println "$info 入站转发组添加成功\n"
}

V2rayAddOutbound()
{
    V2raySetTag
    V2raySetProtocol

    echo "是否是前置代理 ? [y/N]"
    read -p "(默认: N): " forward_proxy_yn
    forward_proxy_yn=${forward_proxy_yn:-N}
    if [[ $forward_proxy_yn == [Yy] ]]
    then
        Println "是否是 https 前置代理 ? [y/N]"
        read -p "(默认: N): " forward_proxy_https_yn
        forward_proxy_https_yn=${forward_proxy_https_yn:-N}
        if [[ $forward_proxy_https_yn == [Yy] ]] 
        then
            V2raySetAllowInsecure
            new_outbound=$(
            $JQ_FILE -n --arg protocol "$protocol" --arg tag "$tag" --arg allowInsecure "$allow_insecure" \
            '{
                "protocol": $protocol,
                "settings": {
                    "servers": []
                },
                "streamSettings": {
                    "security": "tls",
                    "tlsSettings": {
                    "allowInsecure": $allowInsecure | test("true")
                    }
                },
                "tag": $tag
            }')
        else
            new_outbound=$(
            $JQ_FILE -n --arg protocol "$protocol" --arg tag "$tag" \
            '{
                "protocol": $protocol,
                "settings": {
                    "servers": []
                },
                "tag": $tag
            }')
        fi
        while true 
        do
            new_outbound_proxy_tag=$(GetFreeTag)
            [ "$new_outbound_proxy_tag" != "$tag" ] && break
        done

        new_outbound_proxy=$(
        $JQ_FILE -n --arg proxy_tag "$tag" --arg tag "$new_outbound_proxy_tag" \
        '{
            "protocol": "vmess",
            "settings": {
                "vnext": []
            },
            "proxySettings": {
                "tag": $proxy_tag  
            }
            "tag": $tag
        }')
        JQ add "$V2_CONFIG" outbounds "[$new_outbound_proxy]"
    elif [ "$protocol" == "vmess" ] 
    then
        new_outbound=$(
        $JQ_FILE -n --arg protocol "$protocol" --arg tag "$tag" \
        '{
            "protocol": $protocol,
            "settings": {
                "vnext": []
            },
            "tag": $tag
        }')
    else
        new_outbound=$(
        $JQ_FILE -n --arg protocol "$protocol" --arg tag "$tag" \
        '{
            "protocol": $protocol,
            "settings": {
                "servers": []
            },
            "tag": $tag
        }')
    fi

    JQ add "$V2_CONFIG" outbounds "[$new_outbound]"

    Println "$info 出站转发组添加成功\n"
}

V2rayAddRoutingRules()
{
    jq_path='["routing","rules"]'
    new_rule=$(
    $JQ_FILE -n --arg inbound_tag "$inbound_tag" --arg outbound_tag "$outbound_tag" \
    '{
        "type": "field",
        "inboundTag": [
          $inbound_tag
        ],
        "outboundTag": $outbound_tag
    }')
    JQ add "$V2_CONFIG" "[$new_rule]"
    Println "$info 路由设置成功\n"
}

V2rayAddForward()
{
    Println "选择此服务器在 代理转发链 中的位置

  ${green}1.$plain $red起始服务器$plain <=> 中转服务器 <=> 目标服务器
  ${green}2.$plain 起始服务器 <=> $red中转服务器$plain <=> 目标服务器
  ${green}3.$plain 起始服务器 <=> 中转服务器 <=> $red目标服务器$plain
 \n"
    read -p "请输入数字 [1-3]：" forward_num
    case $forward_num in
        1|2) 
            V2rayAddInbound
            inbound_tag=$tag
            Println "$info 设置出站转发组\n"
            V2rayAddOutbound
            outbound_tag=$tag
            V2rayAddRoutingRules
        ;;
        3) 
            V2rayAddInbound
        ;;
        *) Println "已取消...\n" && exit 1
        ;;
    esac
}

V2rayDeleteForward()
{
    forward_count=$((inbounds_forward_count+outbounds_count))
    [ "$forward_count" -eq 0 ] && Println "$error 没有转发账号组\n" && exit 1
    echo -e "输入需要删除的组序号"
    while read -p "(默认: 取消): " delete_forward_num
    do
        case "$delete_forward_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$delete_forward_num" -gt 0 ] && [ "$delete_forward_num" -le $forward_count ]
                then
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    if [ "$delete_forward_num" -gt "$inbounds_forward_count" ] 
    then
        jq_path='["outbounds"]'
        match_index=$((delete_forward_num-inbounds_forward_count-1))
        match="${outbounds_tag[match_index]}"
    else
        jq_path='["inbounds"]'
        match_index=$((delete_forward_num+inbounds_nginx_count-1))
        match="${inbounds_tag[match_index]}"
    fi

    JQ delete "$V2_CONFIG" tag "\"$match\""
    Println "$info 转发账号组删除成功\n"
}

V2rayAddForwardAccount()
{
    forward_count=$((inbounds_forward_count+outbounds_count))
    [ "$forward_count" -eq 0 ] && Println "$error 没有转发账号组, 请先添加组\n" && exit 1
    echo -e "输入组序号"
    while read -p "(默认: 取消): " add_forward_account_num
    do
        case "$add_forward_account_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$add_forward_account_num" -gt 0 ] && [ "$add_forward_account_num" -le $forward_count ]
                then
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    V2raySetLevel

    if [ "$add_forward_account_num" -gt "$inbounds_forward_count" ] 
    then
        match_index=$((add_forward_account_num-inbounds_forward_count-1))
        outbounds_index=$((match_index+2))
        V2raySetAddress
        V2raySetOutboundsPort
        if [ "${outbounds_protocol[match_index]}" == "vmess" ] 
        then
            V2raySetId
            V2raySetAlterId
            V2raySetSecurity

            found=0
            vnext_index=0

            while IFS="=" read -r map_address map_port 
            do
                vnext_index=$((vnext_index+1))
                if [ "$map_address" == "$address" ] && [ "$map_port" == "$port" ]
                then
                    found=1
                    break
                fi
            done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.vnext | to_entries | map("\(.value.address)=\(.value.port)") | .[]' "$V2_CONFIG")

            if [ "$found" -eq 0 ] 
            then
                jq_path='["outbounds",'"$outbounds_index"',"settings","vnext"]'
                new_account=$(
                $JQ_FILE -n --arg address "$address" --arg port "$port" \
                    --arg id "$id" --arg alterId "$alter_id" \
                    --arg security "$security" --arg level "$level" \
                '{
                    "address": $address,
                    "port": $port | tonumber,
                    "users": [
                        {
                            "id": $id,
                            "alterId": $alterId | tonumber,
                            "security": $security,
                            "level": $level | tonumber
                        }
                    ]
                }')
            else
                jq_path='["outbounds",'"$outbounds_index"',"settings","vnext",'"$((vnext_index-1))"']'
                new_account=$(
                $JQ_FILE -n --arg id "$id" --arg alterId "$alter_id" \
                    --arg security "$security" --arg level "$level" \
                '{
                    "id": $id,
                    "alterId": $alterId | tonumber,
                    "security": $security,
                    "level": $level | tonumber
                }')
            fi

        else
            V2raySetHttpAccount

            found=0
            servers_index=0

            while IFS="=" read -r map_address map_port 
            do
                servers_index=$((servers_index+1))
                if [ "$map_address" == "$address" ] && [ "$map_port" == "$port" ]
                then
                    found=1
                    break
                fi
            done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.servers | to_entries | map("\(.value.address)=\(.value.port)") | .[]' "$V2_CONFIG")

            if [ "$found" -eq 0 ] 
            then
                jq_path='["outbounds",'"$outbounds_index"',"settings","servers"]'
                new_account=$(
                $JQ_FILE -n --arg address "$address" --arg port "$port" \
                    --arg user "$user" --arg pass "$pass" \
                '{
                    "address": $address,
                    "port": $port | tonumber,
                    "users": [
                        {
                            "user": $user,
                            "pass": $pass
                        }
                    ]
                }')
            else
                jq_path='["outbounds",'"$outbounds_index"',"settings","servers",'"$((servers_index-1))"']'
                new_account=$(
                $JQ_FILE -n --arg user "$user" --arg pass "$pass" \
                '{
                    "user": $user,
                    "pass": $pass
                }')
            fi
        fi
    else
        match_index=$((add_forward_account_num+inbounds_nginx_count-1))
        if [ "${inbounds_protocol[match_index]}" == "vmess" ] 
        then
            V2raySetId
            V2raySetAlterId
            V2raySetEmail
            jq_path='["inbounds",'"$match_index"',"settings","clients"]'
            new_account=$(
            $JQ_FILE -n --arg id "$id" --arg level "$level" \
                --arg alterId "$alter_id" --arg email "$email" \
            '{
                "id": $id,
                "level": $level | tonumber,
                "alterId": $alterId | tonumber,
                "email": $email
            }')
        else
            V2raySetHttpAccount
            jq_path='["inbounds",'"$match_index"',"settings","accounts"]'
            new_account=$(
            $JQ_FILE -n --arg user "$user" --arg pass "$pass" \
            '{
                "user": $user,
                "pass": $pass
            }')
        fi
    fi
    JQ add "$V2_CONFIG" "[$new_account]"
    Println "$info 转发账号添加成功\n"
}

V2rayDeleteForwardAccount()
{
    forward_count=$((inbounds_forward_count+outbounds_count))
    [ "$forward_count" -eq 0 ] && Println "$error 没有转发账号组\n" && exit 1
    echo -e "输入组序号"
    while read -p "(默认: 取消): " delete_forward_account_num
    do
        case "$delete_forward_account_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$delete_forward_account_num" -gt 0 ] && [ "$delete_forward_account_num" -le $forward_count ]
                then
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    if [ "$delete_forward_account_num" -gt "$inbounds_forward_count" ] 
    then
        match_index=$((delete_forward_account_num-inbounds_forward_count-1))
        outbounds_index=$((match_index+2))

        if [ "${outbounds_protocol[match_index]}" == "vmess" ] 
        then
            vnext_count=0
            vnext_list=""
            while IFS="=" read -r map_address map_port
            do
                vnext_count=$((vnext_count+1))
                if [ "$vnext_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                vnext_list=$vnext_list"# $green$vnext_count$plain $blank服务器: $green$map_address$plain 端口: $green$map_port$plain\n\n"
            done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.vnext | to_entries | map("\(.value.address)=\(.value.port)") | .[]' "$V2_CONFIG")

            if [ -z "$vnext_list" ] 
            then
                Println "$error 此转发账号组里没有账号\n" && exit 1
            else
                echo -e "$vnext_list"
                echo "输入服务器序号"
                while read -p "(默认: 取消): " vnext_index
                do
                    case "$vnext_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$vnext_index" -gt 0 ] && [ "$vnext_index" -le "$vnext_count" ]
                            then
                                vnext_index=$((vnext_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                accounts_list=""
                accounts_count=0
                while IFS=' ' read -r map_id map_alter_id map_security map_level
                do
                    accounts_count=$((accounts_count+1))
                    if [ "$accounts_count" -lt 9 ] 
                    then
                        blank=" "
                    else
                        blank=""
                    fi
                    accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}ID: $green$map_id$plain alterId: $green$map_alter_id$plain 加密方式: $green$map_security$plain 等级: $green$map_level$plain\n\n"
                done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.vnext['"$vnext_index"'].users | to_entries | map("\(.value.id) \(.value.alterId) \(.value.security) \(.value.level)") | .[]' "$V2_CONFIG")

                if [ -z "$accounts_list" ] 
                then
                    Println "此服务器没有账号，是否删除此服务器 ? [y/N]"
                    read -p "(默认: N): " delete_server_yn
                    delete_server_yn=${delete_server_yn:-N}
                    if [[ $delete_server_yn == [Yy] ]] 
                    then
                        jq_path='["outbounds",'"$outbounds_index"',"settings","vnext"]'
                        JQ delete "$V2_CONFIG" "$vnext_index"
                        Println "$info 服务器删除成功\n"
                    else
                        Println "已取消\n" && exit 1
                    fi
                else
                    accounts_list=$accounts_list"# $green$((accounts_count+1))$plain ${blank}删除所有账号\n\n"
                    accounts_list=$accounts_list"# $green$((accounts_count+2))$plain ${blank}删除此服务器"
                    Println "$accounts_list\n"
                    echo "输入序号"
                    while read -p "(默认: 取消): " accounts_index
                    do
                        case "$accounts_index" in
                            "")
                                Println "已取消...\n" && exit 1
                            ;;
                            *[!0-9]*)
                                Println "$error 请输入正确的序号\n"
                            ;;
                            *)
                                if [ "$accounts_index" -gt 0 ] && [ "$accounts_index" -le $((accounts_count+2)) ]
                                then
                                    accounts_index=$((accounts_index-1))
                                    break
                                else
                                    Println "$error 请输入正确的序号\n"
                                fi
                            ;;
                        esac
                    done

                    if [ "$accounts_index" == "$((accounts_count+1))" ] 
                    then
                        jq_path='["outbounds",'"$outbounds_index"',"settings","vnext"]'
                        JQ delete "$V2_CONFIG" "$vnext_index"
                        Println "$info 服务器删除成功\n"
                    elif [ "$accounts_index" == "$accounts_count" ] 
                    then
                        jq_path='["outbounds",'"$outbounds_index"',"settings","vnext",'"$vnext_index"',"users"]'
                        JQ replace "$V2_CONFIG" "[]"
                        Println "$info 账号删除成功\n"
                    else
                        jq_path='["outbounds",'"$outbounds_index"',"settings","vnext",'"$vnext_index"',"users"]'
                        JQ delete "$V2_CONFIG" "$accounts_index"
                        Println "$info 账号删除成功\n"
                    fi
                fi
            fi
        else
            servers_count=0
            servers_list=""
            while IFS="=" read -r map_address map_port
            do
                servers_count=$((servers_count+1))
                if [ "$servers_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                servers_list=$servers_list"# $green$servers_count$plain $blank服务器: $green$map_address$plain 端口: $green$map_port$plain\n\n"
            done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.servers | to_entries | map("\(.value.address)=\(.value.port)") | .[]' "$V2_CONFIG")

            if [ -z "$servers_list" ] 
            then
                Println "$error 此转发账号组里没有账号\n" && exit 1
            else
                Println "$servers_list"
                echo "输入服务器序号"
                while read -p "(默认: 取消): " servers_index
                do
                    case "$servers_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$servers_index" -gt 0 ] && [ "$servers_index" -le "$servers_count" ]
                            then
                                servers_index=$((servers_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                accounts_list=""
                accounts_count=0
                while IFS= read -r line
                do
                    accounts_count=$((accounts_count+1))
                    if [ "$accounts_count" -lt 9 ] 
                    then
                        blank=" "
                    else
                        blank=""
                    fi
                    map_user=${line#*user: }
                    map_user=${map_user%, pass: *}
                    map_pass=${line#*, pass: }
                    map_pass=${map_pass%\"}
                    accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}用户名: $green$map_user$plain 密码: $green$map_pass$plain\n\n"
                done < <($JQ_FILE '.outbounds['"$outbounds_index"'].settings.servers['"$servers_index"'].users | to_entries | map("user: \(.value.user), pass: \(.value.pass)") | .[]' "$V2_CONFIG")

                if [ -z "$accounts_list" ] 
                then
                    Println "此服务器没有账号，是否删除此服务器 ? [y/N]"
                    read -p "(默认: N): " delete_server_yn
                    delete_server_yn=${delete_server_yn:-N}
                    if [[ $delete_server_yn == [Yy] ]] 
                    then
                        jq_path='["outbounds",'"$outbounds_index"',"settings","servers"]'
                        JQ delete "$V2_CONFIG" "$servers_index"
                        Println "$info 服务器删除成功\n"
                    else
                        Println "已取消\n" && exit 1
                    fi
                else
                    accounts_list=$accounts_list"# $green$((accounts_count+1))$plain ${blank}删除所有账号\n\n"
                    accounts_list=$accounts_list"# $green$((accounts_count+2))$plain ${blank}删除此服务器"
                    Println "$accounts_list\n"
                    echo "输入序号"
                    while read -p "(默认: 取消): " accounts_index
                    do
                        case "$accounts_index" in
                            "")
                                Println "已取消...\n" && exit 1
                            ;;
                            *[!0-9]*)
                                Println "$error 请输入正确的序号\n"
                            ;;
                            *)
                                if [ "$accounts_index" -gt 0 ] && [ "$accounts_index" -le $((accounts_count+2)) ]
                                then
                                    accounts_index=$((accounts_index-1))
                                    break
                                else
                                    Println "$error 请输入正确的序号\n"
                                fi
                            ;;
                        esac
                    done

                    if [ "$accounts_index" == "$((accounts_count+1))" ] 
                    then
                        jq_path='["outbounds",'"$outbounds_index"',"settings","servers"]'
                        JQ delete "$V2_CONFIG" "$servers_index"
                        Println "$info 服务器删除成功\n"
                    elif [ "$accounts_index" == "$accounts_count" ] 
                    then
                        jq_path='["outbounds",'"$outbounds_index"',"settings","servers",'"$servers_index"',"users"]'
                        JQ replace "$V2_CONFIG" "[]"
                        Println "$info 账号删除成功\n"
                    else
                        jq_path='["outbounds",'"$outbounds_index"',"settings","servers",'"$servers_index"',"users"]'
                        JQ delete "$V2_CONFIG" "$accounts_index"
                        Println "$info 账号删除成功\n"
                    fi
                fi
            fi
        fi
    else
        match_index=$((delete_forward_account_num+inbounds_nginx_count-1))
        if [ "${inbounds_protocol[match_index]}" == "vmess" ] 
        then
            accounts_count=0
            accounts_list=""
            while IFS=' ' read -r map_id map_alter_id map_security map_level
            do
                accounts_count=$((accounts_count+1))
                if [ "$accounts_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}ID: $green$map_id$plain alterId: $green$map_alter_id$plain 加密方式: $green$map_security$plain 等级: $green$map_level$plain\n\n"
            done < <($JQ_FILE -r '.inbounds['"$match_index"'].settings.clients | to_entries | map("\(.value.id) \(.value.alterId) \(.value.security) \(.value.level)") | .[]' "$V2_CONFIG")

            if [ -z "$accounts_list" ] 
            then
                Println "$error 此账户组没有账号\n" && exit 1
            else
                accounts_list=$accounts_list"# $green$((accounts_count+1))$plain ${blank}删除所有账号"
                Println "$accounts_list\n"
                echo "输入序号"
                while read -p "(默认: 取消): " accounts_index
                do
                    case "$accounts_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$accounts_index" -gt 0 ] && [ "$accounts_index" -le $((accounts_count+1)) ]
                            then
                                accounts_index=$((accounts_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                if [ "$accounts_index" == "$accounts_count" ] 
                then
                    jq_path='["inbounds",'"$match_index"',"settings","clients"]'
                    JQ replace "$V2_CONFIG" "[]"
                else
                    jq_path='["inbounds",'"$match_index"',"settings","clients"]'
                    JQ delete "$V2_CONFIG" "$accounts_index"
                fi
                Println "$info 账号删除成功\n"
            fi
        else
            accounts_list=""
            accounts_count=0
            while IFS= read -r line
            do
                accounts_count=$((accounts_count+1))
                if [ "$accounts_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                map_user=${line#*user: }
                map_user=${map_user%, pass: *}
                map_pass=${line#*, pass: }
                map_pass=${map_pass%\"}
                accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}用户名: $green$map_user$plain 密码: $green$map_pass$plain\n\n"
            done < <($JQ_FILE '.inbounds['"$match_index"'].settings.accounts | to_entries | map("user: \(.value.user), pass: \(.value.pass)") | .[]' "$V2_CONFIG")

            if [ -z "$accounts_list" ] 
            then
                 Println "$error 此账户组没有账号\n" && exit 1
            else
                accounts_list=$accounts_list"# $green$((accounts_count+1))$plain ${blank}删除所有账号"
                Println "$accounts_list\n"
                echo "输入序号"
                while read -p "(默认: 取消): " accounts_index
                do
                    case "$accounts_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$accounts_index" -gt 0 ] && [ "$accounts_index" -le $((accounts_count+1)) ]
                            then
                                accounts_index=$((accounts_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                if [ "$accounts_index" == "$accounts_count" ] 
                then
                    jq_path='["inbounds",'"$match_index"',"settings","accounts"]'
                    JQ replace "$V2_CONFIG" "[]"
                else
                    jq_path='["inbounds",'"$match_index"',"settings","accounts"]'
                    JQ delete "$V2_CONFIG" "$accounts_index"
                fi
                Println "$info 账号删除成功\n"
            fi
        fi
    fi
}

V2rayListForwardAccount()
{
    forward_count=$((inbounds_forward_count+outbounds_count))
    [ "$forward_count" -eq 0 ] && Println "$error 没有转发账号组\n" && exit 1
    echo -e "输入组序号"
    while read -p "(默认: 取消): " list_forward_account_num
    do
        case "$list_forward_account_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$list_forward_account_num" -gt 0 ] && [ "$list_forward_account_num" -le $forward_count ]
                then
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    if [ "$list_forward_account_num" -gt "$inbounds_forward_count" ] 
    then
        match_index=$((list_forward_account_num-inbounds_forward_count-1))
        outbounds_index=$((match_index+2))

        if [ "${outbounds_protocol[match_index]}" == "vmess" ] 
        then
            vnext_count=0
            vnext_list=""
            while IFS="=" read -r map_address map_port
            do
                vnext_count=$((vnext_count+1))
                if [ "$vnext_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                vnext_list=$vnext_list"# $green$vnext_count$plain $blank服务器: $green$map_address$plain 端口: $green$map_port$plain\n\n"
            done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.vnext | to_entries | map("\(.value.address)=\(.value.port)") | .[]' "$V2_CONFIG")

            if [ -z "$vnext_list" ] 
            then
                Println "$error 此转发账号组里没有账号\n" && exit 1
            else
                Println "$vnext_list"
                echo "输入服务器序号"
                while read -p "(默认: 取消): " vnext_index
                do
                    case "$vnext_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$vnext_index" -gt 0 ] && [ "$vnext_index" -le "$vnext_count" ]
                            then
                                vnext_index=$((vnext_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                accounts_list=""
                accounts_count=0
                while IFS=' ' read -r map_id map_alter_id map_security map_level
                do
                    accounts_count=$((accounts_count+1))
                    if [ "$accounts_count" -lt 9 ] 
                    then
                        blank=" "
                    else
                        blank=""
                    fi
                    accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}ID: $green$map_id$plain alterId: $green$map_alter_id$plain 加密方式: $green$map_security$plain 等级: $green$map_level$plain\n\n"
                done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.vnext['"$vnext_index"'].users | to_entries | map("\(.value.id) \(.value.alterId) \(.value.security) \(.value.level)") | .[]' "$V2_CONFIG")

                if [ -z "$accounts_list" ] 
                then
                    Println "$error 此服务器里没有账号\n" && exit 1
                else
                    Println "$accounts_list\n"
                fi
            fi
        else
            servers_count=0
            servers_address=()
            servers_port=()
            servers_list=""
            while IFS="=" read -r map_address map_port
            do
                servers_count=$((servers_count+1))
                servers_address+=("$map_address")
                servers_port+=("$map_port")
                if [ "$servers_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                servers_list=$servers_list"# $green$servers_count$plain $blank服务器: $green$map_address$plain 端口: $green$map_port$plain\n\n"
            done < <($JQ_FILE -r '.outbounds['"$outbounds_index"'].settings.servers | to_entries | map("\(.value.address)=\(.value.port)") | .[]' "$V2_CONFIG")

            if [ -z "$servers_list" ] 
            then
                Println "$error 此转发账号组里没有账号\n" && exit 1
            else
                Println "$servers_list"
                echo "输入服务器序号"
                while read -p "(默认: 取消): " servers_index
                do
                    case "$servers_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$servers_index" -gt 0 ] && [ "$servers_index" -le "$servers_count" ]
                            then
                                servers_index=$((servers_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                accounts_list=""
                accounts_count=0
                while IFS= read -r line
                do
                    accounts_count=$((accounts_count+1))
                    if [ "$accounts_count" -lt 9 ] 
                    then
                        blank=" "
                    else
                        blank=""
                    fi
                    map_user=${line#*user: }
                    map_user=${map_user%, pass: *}
                    map_pass=${line#*, pass: }
                    map_pass=${map_pass%\"}
                    accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}用户名: $green$map_user$plain 密码: $green$map_pass$plain 链接: $green${outbounds_protocol[match_index]}://$map_user:$map_pass@${servers_address[servers_index]}:${servers_port[servers_index]}$plain\n\n"
                done < <($JQ_FILE '.outbounds['"$outbounds_index"'].settings.servers['"$servers_index"'].users | to_entries | map("user: \(.value.user), pass: \(.value.pass)") | .[]' "$V2_CONFIG")

                if [ -z "$accounts_list" ] 
                then
                    Println "$error 此服务器里没有账号\n" && exit 1
                else
                    Println "$accounts_list\n"
                fi
            fi
        fi
    else
        match_index=$((list_forward_account_num+inbounds_nginx_count-1))
        if [ "${inbounds_listen[match_index]}" == "0.0.0.0" ] 
        then
            server_ip=$(GetServerIp)
        else
            server_ip=${inbounds_listen[match_index]}
        fi
        if [ "${inbounds_protocol[match_index]}" == "vmess" ] 
        then
            accounts_count=0
            accounts_list=""
            while IFS=' ' read -r map_id map_alter_id map_security map_level
            do
                accounts_count=$((accounts_count+1))
                if [ "$accounts_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}ID: $green$map_id$plain alterId: $green$map_alter_id$plain 加密方式: $green$map_security$plain 等级: $green$map_level$plain\n\n"
            done < <($JQ_FILE -r '.inbounds['"$match_index"'].settings.clients | to_entries | map("\(.value.id) \(.value.alterId) \(.value.security) \(.value.level)") | .[]' "$V2_CONFIG")

            if [ -z "$accounts_list" ] 
            then
                Println "$error 此账户组没有账号\n" && exit 1
            else
                Println "服务器 IP: $server_ip\n\n$accounts_list\n"
            fi
        else
            accounts_list=""
            accounts_count=0
            while IFS= read -r line
            do
                accounts_count=$((accounts_count+1))
                if [ "$accounts_count" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                map_user=${line#*user: }
                map_user=${map_user%, pass: *}
                map_pass=${line#*, pass: }
                map_pass=${map_pass%\"}
                accounts_list=$accounts_list"# $green$accounts_count$plain ${blank}用户名: $green$map_user$plain 密码: $green$map_pass$plain 链接: $green${inbounds_protocol[match_index]}://$map_user:$map_pass@$server_ip:${inbounds_port[match_index]}$plain\n\n"
            done < <($JQ_FILE '.inbounds['"$match_index"'].settings.accounts | to_entries | map("user: \(.value.user), pass: \(.value.pass)") | .[]' "$V2_CONFIG")

            if [ -z "$accounts_list" ] 
            then
                 Println "$error 此账户组没有账号\n" && exit 1
            else
                Println "$accounts_list\n"
            fi
        fi
    fi
}

V2rayListDomains()
{
    v2ray_domains_list=""
    v2ray_domains_count=0
    v2ray_domains=()

    if ls -A "/usr/local/nginx/conf/sites_available/"* > /dev/null 2>&1
    then
        for f in "/usr/local/nginx/conf/sites_available/"*
        do
            domain=${f##*/}
            [[ "$domain" =~ ^[A-Za-z0-9.]*$ ]] || continue
            v2ray_domains_count=$((v2ray_domains_count+1))
            domain=${domain%.conf}
            v2ray_domains+=("$domain")
            if [ -e "/usr/local/nginx/conf/sites_enabled/$domain.conf" ] && grep -q "proxy_pass http://127.0.0.1:" < "/usr/local/nginx/conf/sites_enabled/$domain.conf" 
            then
                v2ray_domain_status_text="v2ray: $green开启$plain"
                v2ray_domains_on+=("$domain")
            else
                v2ray_domain_status_text="v2ray: $red关闭$plain"
            fi
            v2ray_domains_list=$v2ray_domains_list"$green$v2ray_domains_count.$plain $domain    $v2ray_domain_status_text\n\n"
        done
    fi
    v2ray_add_domain_num=$((v2ray_domains_count+1))
    Println "$green域名列表:$plain\n\n${v2ray_domains_list:-无\n\n}$green$v2ray_add_domain_num.$plain 添加域名\n\n"
}

V2rayListDomainsInbound()
{
    v2ray_domains_inbound_list=""
    v2ray_domains_inbound_count=0
    v2ray_domains_inbound=()
    v2ray_domains_inbound_https_port=()

    if ls -A "/usr/local/nginx/conf/sites_available/"* > /dev/null 2>&1
    then
        for f in "/usr/local/nginx/conf/sites_available/"*
        do
            domain=${f##*/}
            domain=${domain%.conf}
            if [ -e "/usr/local/nginx/conf/sites_enabled/$domain.conf" ] 
            then
                v2ray_status_text="$green开启$plain"
            else
                v2ray_status_text="$red关闭$plain"
            fi
            if [[ "$domain" =~ ^[A-Za-z0-9.]*$ ]] || grep -q "proxy_pass http://127.0.0.1:${inbounds_port[nginx_index]}" < "/usr/local/nginx/conf/sites_available/$domain.conf" 
            then
                server_found=0
                server_flag=0
                while IFS= read -r line 
                do
                    if [[ $line == *"server {"* ]] 
                    then
                        server_found=1
                        server_ports=""
                        is_inbound=0
                    fi

                    if [[ $server_found -eq 1 ]] && [[ $line == *"{"* ]]
                    then
                        server_flag=$((server_flag+1))
                    fi

                    if [[ $server_found -eq 1 ]] && [[ $line == *"}"* ]]
                    then
                        server_flag=$((server_flag-1))
                        if [[ $server_flag -eq 0 ]] 
                        then
                            server_found=0
                            if [[ $is_inbound -eq 1 ]]
                            then
                                v2ray_domains_inbound_count=$((v2ray_domains_inbound_count+1))
                                v2ray_domains_inbound+=("$domain")
                                v2ray_domains_inbound_https_port+=("$server_ports")
                                if [[ $v2ray_domains_inbound_count -gt 9 ]] 
                                then
                                    blank=" "
                                else
                                    blank=""
                                fi
                                v2ray_domains_inbound_list=$v2ray_domains_inbound_list"$green$v2ray_domains_inbound_count.$plain 域名: $green$domain$plain, 端口: $green$server_ports$plain, 协议: ${green}vmess$plain, 网络: ${green}ws$plain\n$blank   path: $green${inbounds_path[nginx_index]}$plain, security: ${green}tls$plain, 状态: $v2ray_status_text\n\n"
                            fi
                        fi
                    fi

                    if [[ $server_found -eq 1 ]] && [[ $line == *"listen "* ]]
                    then
                        line=${line#*listen }
                        line=${line% ssl;*}
                        lead=${line%%[^[:blank:]]*}
                        line=${line#${lead}}
                        [ -n "$server_ports" ] && server_ports="$server_ports "
                        server_ports="$server_ports$line"
                    fi

                    if [[ $server_found -eq 1 ]] && [[ $line == *"proxy_pass http://127.0.0.1:${inbounds_port[nginx_index]}"* ]]
                    then
                        is_inbound=1
                    fi
                done < "/usr/local/nginx/conf/sites_available/$domain.conf"
            else
                continue
            fi
        done
    fi
    Println "绑定的$green域名列表:$plain\n\n${v2ray_domains_inbound_list:-无\n\n}\n\n"
}

V2rayListDomain()
{
    v2ray_domain_list=""
    v2ray_domain_server_found=0
    v2ray_domain_server_flag=0
    v2ray_domain_servers_count=0
    v2ray_domain_servers_https_port=()
    v2ray_domain_servers_v2ray_path=()
    v2ray_domain_servers_v2ray_port=()
    while IFS= read -r line 
    do
        if [[ $line == *"server {"* ]] 
        then
            v2ray_domain_server_found=1
            https_ports=""
            v2ray_path=""
            v2ray_port=""
            v2ray_path_status=0
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            v2ray_domain_server_flag=$((v2ray_domain_server_flag+1))
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            v2ray_domain_server_flag=$((v2ray_domain_server_flag-1))
            if [[ $v2ray_domain_server_flag -eq 0 ]] 
            then
                v2ray_domain_server_found=0
                if [ -n "$https_ports" ] 
                then
                    v2ray_domain_servers_count=$((v2ray_domain_servers_count+1))
                    v2ray_domain_servers_https_port+=("$https_ports")
                    [ -z "$v2ray_port" ] && v2ray_path=""
                    v2ray_domain_servers_v2ray_path+=("$v2ray_path")
                    v2ray_domain_servers_v2ray_port+=("$v2ray_port")
                    if [ -n "$v2ray_port" ] 
                    then
                        v2ray_port_status="$green$v2ray_port$plain"
                    else
                        v2ray_port_status="$red关闭$plain"
                    fi
                    v2ray_domain_list=$v2ray_domain_list"$green$v2ray_domain_servers_count.$plain https 端口: $green$https_ports$plain, v2ray 端口: $v2ray_port_status\n\n"
                fi
            fi
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *" ssl;"* ]]
        then
            https_port=${line#*listen}
            https_port=${https_port// ssl;/}
            lead=${https_port%%[^[:blank:]]*}
            https_port=${https_port#${lead}}
            [ -n "$https_ports" ] && https_ports="$https_ports "
            https_ports="$https_ports$https_port"
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"location "* ]] && [[ $v2ray_path_status -eq 0 ]]
        then
            v2ray_path=${line#*location }
            lead=${v2ray_path%%[^[:blank:]]*}
            v2ray_path=${v2ray_path#${lead}}
            v2ray_path=${v2ray_path%% *}
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"proxy_pass http://127.0.0.1:"* ]]
        then
            v2ray_port=${line##*:}
            v2ray_port=${v2ray_port%;*}
            v2ray_path_status=1
        fi
    done < "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf"

    v2ray_domain_update_crt_number=$((v2ray_domain_servers_count+1))
    v2ray_domain_add_server_number=$((v2ray_domain_servers_count+2))
    v2ray_domain_edit_server_number=$((v2ray_domain_servers_count+3))
    v2ray_domain_delete_server_number=$((v2ray_domain_servers_count+4))
    v2ray_domain_list="$v2ray_domain_list$green$v2ray_domain_update_crt_number.$plain 更新证书\n\n"
    v2ray_domain_list="$v2ray_domain_list$green$v2ray_domain_add_server_number.$plain 添加配置\n\n"
    v2ray_domain_list="$v2ray_domain_list$green$v2ray_domain_edit_server_number.$plain 修改配置\n\n"
    v2ray_domain_list="$v2ray_domain_list$green$v2ray_domain_delete_server_number.$plain 删除配置\n\n"

    Println "域名 $green${v2ray_domains[v2ray_domains_index]}$plain 配置:\n\n$v2ray_domain_list"
}

V2rayDomainUpdateCrt()
{
    Println "$info 更新证书..."
    if [ ! -e "$HOME/.acme.sh/acme.sh" ] 
    then
        Println "$info 检查依赖..."
        CheckRelease
        if [ "$release" == "rpm" ] 
        then
            yum -y install socat > /dev/null
        else
            apt-get -y install socat > /dev/null
        fi
        bash <(curl --silent -m 10 https://get.acme.sh) > /dev/null
    fi

    nginx -s stop 2> /dev/null || true
    sleep 1

    ~/.acme.sh/acme.sh --force --issue -d "${v2ray_domains[v2ray_domains_index]}" --standalone -k ec-256 > /dev/null
    ~/.acme.sh/acme.sh --force --installcert -d "${v2ray_domains[v2ray_domains_index]}" --fullchainpath /usr/local/nginx/conf/sites_crt/"${v2ray_domains[v2ray_domains_index]}".crt --keypath /usr/local/nginx/conf/sites_crt/"${v2ray_domains[v2ray_domains_index]}".key --ecc > /dev/null

    nginx
    Println "$info 证书更新完成..."
}

V2rayAppendDomainConf()
{
printf '%s' "    server {
        listen      $server_https_port ssl;
        server_name $server_domain;

        access_log off;

        ssl_certificate      /usr/local/nginx/conf/sites_crt/$server_domain.crt;
        ssl_certificate_key  /usr/local/nginx/conf/sites_crt/$server_domain.key;

        location ${inbounds_path[nginx_index]} {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:${inbounds_port[nginx_index]};
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Host \$host;
            # Show real IP in v2ray access.log
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }

" >> "/usr/local/nginx/conf/sites_available/$server_domain.conf"
}

V2rayAddDomain()
{
    if [ ! -e "/usr/local/nginx" ] 
    then
        Println "$error Nginx 未安装 ! 输入 nx 安装 nginx\n" && exit 1
    fi

    NginxConfigSsl

    Println "输入指向本机的IP或域名"
    echo -e "$tip 多个域名用空格分隔\n"
    read -p "(默认: 取消): " server_domain

    if [ -n "$server_domain" ] 
    then
        if [[ $server_domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! $server_domain =~ ^[A-Za-z0-9.]*$ ]] 
        then
            Println "$error 域名格式错误\n" && exit 1
        elif [ -e "/usr/local/nginx/conf/sites_available/$server_domain.conf" ] 
        then
            Println "$error $server_domain 已存在\n" && exit 1
        fi

        NginxConfigServerHttpsPort
        V2rayListNginx

        Println "绑定账号组,输入序号"
        while read -p "(默认: 取消): " nginx_num
        do
            case "$nginx_num" in
                "")
                    Println "已取消...\n" && exit 1
                ;;
                *[!0-9]*)
                    Println "$error 请输入正确的序号\n"
                ;;
                *)
                    if [ "$nginx_num" -gt 0 ] && [ "$nginx_num" -le $inbounds_nginx_count ]
                    then
                        nginx_num=$((nginx_num-1))
                        nginx_index=${inbounds_nginx_index[nginx_num]}
                        break
                    else
                        Println "$error 请输入正确的序号\n"
                    fi
                ;;
            esac
        done

        DomainInstallCert
        V2rayAppendDomainConf
        NginxEnableDomain
        NginxConfigCorsHost
        Println "$info 域名 $server_domain 添加完成...\n"
    else
        Println "已取消...\n" && exit 1
    fi
}

V2rayDomainServerAddV2rayPort()
{
    V2rayListNginx
    Println "绑定账号组,输入序号"
    while read -p "(默认: 取消): " nginx_num
    do
        case "$nginx_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$nginx_num" -gt 0 ] && [ "$nginx_num" -le $inbounds_nginx_count ]
                then
                    nginx_num=$((nginx_num-1))
                    nginx_index=${inbounds_nginx_index[nginx_num]}
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    v2ray_domain_server_found=0
    v2ray_domain_server_flag=0
    conf=""
    index=0
    while IFS= read -r line 
    do
        line_edit=""
        line_add=""
        if [[ $line == *"server {"* ]] 
        then
            v2ray_domain_server_found=1
            v2ray_port_found=0
            https_ports=""
            v2ray_port=""
            server_conf=""
            server_conf_edit=""
            server_conf_add=""
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            v2ray_domain_server_flag=$((v2ray_domain_server_flag+1))
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            v2ray_domain_server_flag=$((v2ray_domain_server_flag-1))
            if [[ $v2ray_domain_server_flag -eq 0 ]] 
            then
                v2ray_domain_server_found=0
                if [ -n "$https_ports" ] 
                then
                    if [[ $index -eq $v2ray_domain_server_index ]] 
                    then
                        if [ "$v2ray_port_found" -eq 1 ] 
                        then
                            line="$server_conf_edit\n$line"
                        else
                            line="$server_conf_add\n$line"
                        fi
                    else
                        line="$server_conf\n$line"
                    fi
                    index=$((index+1))
                else
                    line="$server_conf\n$line"
                fi
            fi
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *" ssl;"* ]]
        then
            https_port=${line#*listen}
            https_port=${https_port// ssl;/}
            lead=${https_port%%[^[:blank:]]*}
            https_port=${https_port#${lead}}
            https_ports="$https_ports$https_port "
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"ssl_certificate_key "* ]]
        then
            line_add="$line\n
        location ${inbounds_path[nginx_index]} {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:${inbounds_port[nginx_index]};
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Host \$host;
            # Show real IP in v2ray access.log
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }"
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"proxy_pass http://127.0.0.1:"* ]]
        then
            v2ray_port_found=1
            v2ray_port=${line##*:}
            v2ray_port=${v2ray_port%;*}
            line_edit="${line%%proxy_pass*}proxy_pass http://127.0.0.1:${inbounds_port[nginx_index]};"
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] 
        then
            [ -n "$server_conf" ] && server_conf="$server_conf\n"
            server_conf="$server_conf$line"
            [ -n "$server_conf_edit" ] && server_conf_edit="$server_conf_edit\n"
            if [ -n "$line_edit" ] 
            then
                server_conf_edit="$server_conf_edit$line_edit"
            else
                server_conf_edit="$server_conf_edit$line"
            fi
            [ -n "$server_conf_add" ] && server_conf_add="$server_conf_add\n"
            if [ -n "$line_add" ] 
            then
                server_conf_add="$server_conf_add$line_add"
            else
                server_conf_add="$server_conf_add$line"
            fi
        fi

        if [[ $v2ray_domain_server_found -eq 0 ]] 
        then
            [ -n "$conf" ] && conf="$conf\n"
            conf="$conf$line"
        fi
    done < "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf"
    PrettyConfig
    echo -e "$conf" > "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf"
    ln -sf "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf" "/usr/local/nginx/conf/sites_enabled/${v2ray_domains[v2ray_domains_index]}.conf"
    if [ -n "${v2ray_domain_servers_v2ray_port[v2ray_domain_server_index]}" ] 
    then
        Println "$info v2ray 端口修改成功\n"
    else
        Println "$info v2ray 端口添加成功\n"
    fi
}

V2rayDomainServerRemoveV2rayPort()
{
    v2ray_domain_server_found=0
    v2ray_domain_server_flag=0
    conf=""
    index=0
    while IFS= read -r line 
    do
        if [[ $line == *"server {"* ]] 
        then
            v2ray_domain_server_found=1
            v2ray_block_found=0
            https_ports=""
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"{"* ]] 
        then
            v2ray_domain_server_flag=$((v2ray_domain_server_flag+1))
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"}"* ]] 
        then
            v2ray_domain_server_flag=$((v2ray_domain_server_flag-1))
            if [[ $v2ray_domain_server_flag -eq 0 ]] 
            then
                v2ray_domain_server_found=0
                if [ -n "$https_ports" ] 
                then
                    index=$((index+1))
                fi
            fi
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *" ssl;"* ]]
        then
            https_port=${line#*listen}
            https_port=${https_port// ssl;/}
            lead=${https_port%%[^[:blank:]]*}
            https_port=${https_port#${lead}}
            https_ports="$https_ports$https_port "
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $line == *"location ${v2ray_domain_servers_v2ray_path[v2ray_domain_server_index]} "* ]] && [ -n "$https_ports" ] && [[ $index -eq $v2ray_domain_server_index ]]
        then
            v2ray_block_found=1
        fi

        if [[ $v2ray_domain_server_found -eq 1 ]] && [[ $v2ray_block_found -eq 1 ]] 
        then
            if [[ $line == *"}"* ]] 
            then
                v2ray_block_found=0
            fi
            continue
        fi

        if [ "${last_line:-}" == "#" ] && [ "$line" == "" ]
        then
            continue
        fi
        last_line="$line#"
        [ -n "$conf" ] && conf="$conf\n"
        conf="$conf$line"
    done < "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf"
    unset last_line
    echo -e "$conf" > "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf"
    ln -sf "/usr/local/nginx/conf/sites_available/${v2ray_domains[v2ray_domains_index]}.conf" "/usr/local/nginx/conf/sites_enabled/${v2ray_domains[v2ray_domains_index]}.conf"
    Println "$info v2ray 端口关闭成功\n"
}

V2rayConfigDomain()
{
    if [ ! -e "/usr/local/nginx" ] 
    then
        Println "$error Nginx 未安装! 输入 nx 安装 Nginx\n" && exit 1
    fi

    V2rayListDomains

    echo "输入序号"
    while read -p "(默认: 取消): " v2ray_domains_index
    do
        case "$v2ray_domains_index" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            $v2ray_add_domain_num)
                V2rayAddDomain
                exit
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$v2ray_domains_index" -gt 0 ] && [ "$v2ray_domains_index" -lt "$v2ray_add_domain_num" ]
                then
                    v2ray_domains_index=$((v2ray_domains_index-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    V2rayListDomain

    echo "输入序号"
    while read -p "(默认: 取消): " v2ray_domain_server_num
    do
        case "$v2ray_domain_server_num" in
            "")
                Println "已取消...\n" && exit 1
            ;;
            $v2ray_domain_update_crt_number)
                V2rayDomainUpdateCrt
                exit 0
            ;;
            $v2ray_domain_add_server_number)
                V2rayDomainAddServer
                exit 0
            ;;
            $v2ray_domain_edit_server_number)
                V2rayDomainEditServer
                exit 0
            ;;
            $v2ray_domain_delete_server_number)
                V2rayDomainDeleteServer
                exit 0
            ;;
            *[!0-9]*)
                Println "$error 请输入正确的序号\n"
            ;;
            *)
                if [ "$v2ray_domain_server_num" -gt 0 ] && [ "$v2ray_domain_server_num" -le "$v2ray_domain_servers_count" ]
                then
                    v2ray_domain_server_index=$((v2ray_domain_server_num-1))
                    break
                else
                    Println "$error 请输入正确的序号\n"
                fi
            ;;
        esac
    done

    if [ -n "${v2ray_domain_servers_v2ray_port[v2ray_domain_server_index]}" ] 
    then
        Println "选择操作

  ${green}1.$plain 修改 https 端口
  ${green}2.$plain 修改 v2ray 端口
  ${green}3.$plain 关闭 v2ray 端口
    \n"
    else
        Println "选择操作

  ${green}1.$plain 修改 https 端口
  ${green}2.$plain 开启 v2ray 端口
    \n"
    fi

    while read -p "(默认：取消): " v2ray_domain_server_action_num 
    do
        case $v2ray_domain_server_action_num in
            "") 
                Println "已取消...\n" && exit 1
            ;;
            1) 
                V2rayDomainServerEditHttpsPort
                break
            ;;
            2) 
                V2rayDomainServerAddV2rayPort
                break
            ;;
            3) 
                if [ -n "${v2ray_domain_servers_v2ray_port[v2ray_domain_server_index]}" ] 
                then
                    V2rayDomainServerRemoveV2rayPort
                    break
                else
                    Println "$error 输入错误\n"
                fi
            ;;
            *) Println "$error 输入错误\n"
            ;;
        esac
    done
}

CheckShFile()
{
    [ ! -e "$SH_FILE" ] && wget --no-check-certificate "$SH_LINK" -qO "$SH_FILE" && chmod +x "$SH_FILE"
    if [ ! -s "$SH_FILE" ] 
    then
        Println "$error 无法连接到 Github ! 尝试备用链接..."
        wget --no-check-certificate "$SH_LINK_BACKUP" -qO "$SH_FILE" && chmod +x "$SH_FILE"
        if [ ! -s "$SH_FILE" ] 
        then
            Println "$error 无法连接备用链接!\n" && exit 1
        fi
    fi
    [ ! -e "$NX_FILE" ] && ln -s "$SH_FILE" "$NX_FILE"
    [ ! -e "$V2_FILE" ] && ln -s "$SH_FILE" "$V2_FILE"
    [ ! -e "$XC_FILE" ] && ln -s "$SH_FILE" "$XC_FILE"

    return 0
}

if [ "${0##*/}" == "nx" ] || [ "${0##*/}" == "nx.sh" ]
then
    CheckShFile

    Println "  Nginx 管理面板 $plain${red}[v$sh_ver]$plain

  ${green}1.$plain 安装
  ${green}2.$plain 卸载
  ${green}3.$plain 升级
————————————
  ${green}4.$plain 查看域名
  ${green}5.$plain 添加域名
  ${green}6.$plain 修改域名
  ${green}7.$plain 开关域名
  ${green}8.$plain 修改本地
————————————
  ${green}9.$plain 状态
 ${green}10.$plain 开关
 ${green}11.$plain 重启
————————————
 ${green}12.$plain 删除域名
 ${green}13.$plain 日志切割
————————————
 ${green}14.$plain 安装 nodejs
 ${green}15.$plain 安装 pdf2htmlEX
 ${green}16.$plain 安装 tesseract

 $tip 输入: nx 打开面板\n"
    read -p "请输入数字 [1-16]：" nginx_num
    case "$nginx_num" in
        1) 
            if [ -e "/usr/local/nginx" ] 
            then
                Println "$error Nginx 已经存在 !\n" && exit 1
            fi

            Println "因为是编译 nginx，耗时会很长，是否继续？[y/N]"
            read -p "(默认: N): " nginx_install_yn
            nginx_install_yn=${nginx_install_yn:-N}
            if [[ $nginx_install_yn == [Yy] ]] 
            then
                InstallNginx
                Println "$info Nginx 安装完成\n"
            else
                Println "已取消...\n" && exit 1
            fi
        ;;
        2) UninstallNginx
        ;;
        3) 
            if [ ! -e "/usr/local/nginx" ] 
            then
                Println "$error Nginx 未安装 !\n" && exit 1
            fi

            Println "$info 更新 nginx 脚本...\n"

            sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "$SH_LINK"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1 || true)

            if [ -z "$sh_new_ver" ] 
            then
                Println "$error 无法连接到 Github ! 尝试备用链接...\n"
                sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "$SH_LINK_BACKUP"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1 || true)
                [ -z "$sh_new_ver" ] && Println "$error 无法连接备用链接!\n" && exit 1
            fi

            if [ "$sh_new_ver" != "$sh_ver" ] 
            then
                [ -e "$LOCK_FILE" ] && rm -f "$LOCK_FILE"
            fi

            wget --no-check-certificate "$SH_LINK" -qO "$SH_FILE" && chmod +x "$SH_FILE"

            if [ ! -s "$SH_FILE" ] 
            then
                wget --no-check-certificate "$SH_LINK_BACKUP" -qO "$SH_FILE"
                if [ ! -s "$SH_FILE" ] 
                then
                    Println "$error 无法连接备用链接!\n" && exit 1
                else
                    Println "$info nginx 脚本更新完成\n"
                fi
            else
                Println "$info nginx 脚本更新完成\n"
            fi

            Println "是否重新编译 nginx ？[y/N]"
            read -p "(默认: N): " nginx_install_yn
            nginx_install_yn=${nginx_install_yn:-N}
            if [[ $nginx_install_yn == [Yy] ]] 
            then
                InstallNginx
                Println "$info Nginx 升级完成\n"
            else
                Println "已取消...\n" && exit 1
            fi
        ;;
        4) 
            NginxCheckDomains
            NginxListDomains
            if [ "$nginx_domains_count" -eq 0 ] 
            then
                Println "$error 没有域名\n"
            else
                echo "输入序号"
                while read -p "(默认: 取消): " nginx_domains_index
                do
                    case "$nginx_domains_index" in
                        "")
                            Println "已取消...\n" && exit 1
                        ;;
                        *[!0-9]*)
                            Println "$error 请输入正确的序号\n"
                        ;;
                        *)
                            if [ "$nginx_domains_index" -gt 0 ] && [ "$nginx_domains_index" -le "$nginx_domains_count" ]
                            then
                                nginx_domains_index=$((nginx_domains_index-1))
                                break
                            else
                                Println "$error 请输入正确的序号\n"
                            fi
                        ;;
                    esac
                done

                NginxListDomain
            fi
        ;;
        5) 
            NginxAddDomain
        ;;
        6) 
            NginxCheckDomains
            NginxEditDomain
        ;;
        7) 
            NginxCheckDomains
            NginxToggleDomain
        ;;
        8) 
            NginxConfigLocalhost
        ;;
        9) 
            if [ ! -e "/usr/local/nginx" ] 
            then
                Println "$error Nginx 未安装 !\n"
            else
                if [ ! -s "/usr/local/nginx/logs/nginx.pid" ] 
                then
                    Println "nginx 状态: $red关闭$plain\n"
                else
                    PID=$(< "/usr/local/nginx/logs/nginx.pid")
                    if kill -0  "$PID" 2> /dev/null
                    then
                        Println "nginx 状态: $green开启$plain\n"
                    else
                        Println "nginx 状态: $red开启$plain\n"
                    fi
                fi
            fi
        ;;
        10) ToggleNginx
        ;;
        11) 
            RestartNginx
            Println "$info Nginx 已重启\n"
        ;;
        12) 
            NginxCheckDomains
            NginxDeleteDomain
        ;;
        13) 
            if [ ! -e "$IPTV_ROOT" ] 
            then
                Println "$error 请先安装脚本 !\n" && exit 1
            fi

            if [ -e "/usr/local/nginx" ] 
            then
                chown nobody:root /usr/local/nginx/logs/*.log
                chmod 660 /usr/local/nginx/logs/*.log
            fi

            if crontab -l | grep -q "$LOGROTATE_CONFIG" 2> /dev/null
            then
                Println "$error 日志切割定时任务已存在 !\n"
            else
                LOGROTATE_FILE=$(command -v logrotate)

                if [ ! -x "$LOGROTATE_FILE" ] 
                then
                    Println "$error 请先安装 logrotate !\n" && exit 1
                fi

                logrotate=""

                if [ -e "/usr/local/nginx" ] 
                then
                    logrotate='
/usr/local/nginx/logs/*.log {
  daily
  missingok
  rotate 14
  compress
  delaycompress
  notifempty
  create 660 nobody root
  sharedscripts
  postrotate
    [ ! -f /usr/local/nginx/logs/nginx.pid ] || /bin/kill -USR1 `cat /usr/local/nginx/logs/nginx.pid`
  endscript
}
'
                fi

                logrotate="$logrotate
$IPTV_ROOT/*.log {
  monthly
  missingok
  rotate 3
  compress
  nodelaycompress
  notifempty
  sharedscripts
}
"
                printf '%s' "$logrotate" > "$LOGROTATE_CONFIG"

                crontab -l > "$IPTV_ROOT/cron_tmp" 2> /dev/null || true
                printf '%s\n' "0 0 * * * $LOGROTATE_FILE $LOGROTATE_CONFIG" >> "$IPTV_ROOT/cron_tmp"
                crontab "$IPTV_ROOT/cron_tmp" > /dev/null
                rm -f "$IPTV_ROOT/cron_tmp"
                Println "$info 日志切割定时任务开启成功 !\n"
            fi
        ;;
        14)
            if [[ ! -x $(command -v node) ]] || [[ ! -x $(command -v npm) ]] 
            then
                InstallNodejs
            fi
            if [ ! -e "$NODE_ROOT/index.js" ] 
            then
                if [[ -x $(command -v node) ]] && [[ -x $(command -v npm) ]] 
                then
                    NodejsConfig
                else
                    Println "$error nodejs 安装发生错误\n" && exit 1
                fi
            else
                Println "$error nodejs 配置已存在\n" && exit 1
            fi
        ;;
        15)
            if [[ ! -x $(command -v pdf2htmlEX) ]] 
            then
                Println "因为是编译 pdf2htmlEX，耗时会很长，是否继续？[y/N]"
                read -p "(默认: N): " pdf2html_install_yn
                pdf2html_install_yn=${pdf2html_install_yn:-N}
                if [[ $pdf2html_install_yn == [Yy] ]] 
                then
                    InstallPdf2html
                    Println "$info pdf2htmlEX 安装完成，输入 source /etc/profile 可立即使用\n"
                else
                    Println "已取消...\n" && exit 1
                fi
            else
                Println "$error pdf2htmlEX 已存在!\n"
            fi
        ;;
        16)
            if [[ ! -x $(command -v tesseract) ]] 
            then
                Println "$info 检查依赖，耗时可能会很长..."
                CheckRelease
                echo
                if [ "$release" == "ubu" ] 
                then
                    add-apt-repository ppa:alex-p/tesseract-ocr -y
                    apt-get -y update
                    apt-get -y install tesseract
                elif [ "$release" == "ubu" ] 
                then
                    Println "$info 参考 https://notesalexp.org/tesseract-ocr/ ...\n"
                else
                    Println "$info 参考 https://tesseract-ocr.github.io/tessdoc/Home.html ...\n"
                fi
            else
                Println "$error tesseract 已存在!\n"
            fi
        ;;
        *) Println "$error 请输入正确的数字 [1-16]\n"
        ;;
    esac
    exit 0
elif [ "${0##*/}" == "v2" ] || [ "${0##*/}" == "v2.sh" ] 
then
    CheckShFile
    [ ! -d "$IPTV_ROOT" ] && JQ_FILE="/usr/local/bin/jq"

    case $* in
        "e") 
            [ ! -e "$V2_CONFIG" ] && Println "$error 尚未安装，请检查 !" && exit 1
            vim "$V2_CONFIG" && exit 0
        ;;
        *) 
        ;;
    esac

    Println "  v2ray 管理面板 $plain${red}[v$sh_ver]$plain

  ${green}1.$plain 安装
  ${green}2.$plain 升级
  ${green}3.$plain 配置域名
————————————
  ${green}4.$plain 查看账号
  ${green}5.$plain 添加账号组
  ${green}6.$plain 添加账号
————————————
  ${green}7.$plain 查看转发账号
  ${green}8.$plain 添加转发账号组
  ${green}9.$plain 添加转发账号
————————————
 ${green}10.$plain 删除账号组
 ${green}11.$plain 删除账号
 ${green}12.$plain 删除转发账号组
 ${green}13.$plain 删除转发账号
————————————
 ${green}14.$plain 设置路由
 ${green}15.$plain 设置等级
————————————
 ${green}16.$plain 查看流量
 ${green}17.$plain 开关
 ${green}18.$plain 重启

 $tip 输入: v2 打开面板\n"
    read -p "请输入数字 [1-18]：" v2ray_num
    case $v2ray_num in
        1) 
            if [ -e "$V2_CONFIG" ] 
            then
                while IFS= read -r line 
                do
                    if [[ $line == *"port"* ]] 
                    then
                        port=${line#*: }
                        port=${port%,*}
                    elif [[ $line == *"id"* ]] 
                    then
                        id=${line#*: \"}
                        id=${id%\"*}
                    elif [[ $line == *"path"* ]] 
                    then
                        path=${line#*: \"}
                        path=${path%\"*}
                        break
                    fi
                done < "$V2_CONFIG"

                if [ -n "${path:-}" ] 
                then
                    Println "$error v2ray 已安装...\n" && exit 1
                fi
            fi

            if grep -q '\--show-progress' < <(wget --help)
            then
                _PROGRESS_OPT="--show-progress"
            else
                _PROGRESS_OPT=""
            fi

            Println "$info 检查依赖，耗时可能会很长..."
            CheckRelease
            InstallJq

            Println "$info 安装 v2ray..."
            bash <(curl --silent -m 10 https://install.direct/go.sh) > /dev/null

            V2rayConfigInstall

            service v2ray start > /dev/null 2>&1
            Println "$info v2ray 安装完成, 请配置域名...\n"
        ;;
        2) 
            if grep -q '\--show-progress' < <(wget --help)
            then
                _PROGRESS_OPT="--show-progress"
            else
                _PROGRESS_OPT=""
            fi

            Println "$info 检查依赖，耗时可能会很长..."
            CheckRelease

            rm -f "${JQ_FILE:-notfound}"
            Println "$info 更新 JQ...\n"
            InstallJq

            echo
            V2rayConfigUpdate
            echo

            bash <(curl --silent -m 10 https://install.direct/go.sh) > /dev/null

            Println "$info 更新 v2ray 脚本...\n"

            sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "$SH_LINK"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1 || true)

            if [ -z "$sh_new_ver" ] 
            then
                Println "$error 无法连接到 Github ! 尝试备用链接...\n"
                sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "$SH_LINK_BACKUP"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1 || true)
                [ -z "$sh_new_ver" ] && Println "$error 无法连接备用链接!\n" && exit 1
            fi

            if [ "$sh_new_ver" != "$sh_ver" ] 
            then
                [ -e "$LOCK_FILE" ] && rm -f "$LOCK_FILE"
            fi

            wget --no-check-certificate "$SH_LINK" -qO "$SH_FILE" && chmod +x "$SH_FILE"

            if [ ! -s "$SH_FILE" ] 
            then
                wget --no-check-certificate "$SH_LINK_BACKUP" -qO "$SH_FILE"
                if [ ! -s "$SH_FILE" ] 
                then
                    Println "$error 无法连接备用链接!\n" && exit 1
                else
                    Println "$info v2ray 脚本更新完成\n"
                fi
            else
                Println "$info v2ray 脚本更新完成\n"
            fi

            Println "$info 升级完成\n"
        ;;
        3) 
            V2rayConfigUpdate
            NginxCheckDomains
            V2rayConfigDomain
        ;;
        4) 
            V2rayStatus
            V2rayConfigUpdate
            NginxCheckDomains
            V2rayListNginx
            V2rayListNginxAccounts
        ;;
        5)
            V2rayConfigUpdate
            NginxCheckDomains
            V2rayAddNginx
        ;;
        6)
            V2rayConfigUpdate
            NginxCheckDomains
            V2rayListNginx
            V2rayAddNginxAccount
        ;;
        7)
            V2rayStatus
            V2rayConfigUpdate
            V2rayListForward
            V2rayListForwardAccount
        ;;
        8)
            V2rayConfigUpdate
            V2rayListForward
            V2rayAddForward
        ;;
        9)
            V2rayConfigUpdate
            V2rayListForward
            V2rayAddForwardAccount
        ;;
        10)
            V2rayConfigUpdate
            V2rayListNginx
            V2rayDeleteNginx
        ;;
        11)
            V2rayConfigUpdate
            V2rayListNginx
            V2rayDeleteNginxAccount
        ;;
        12)
            V2rayConfigUpdate
            V2rayListForward
            V2rayDeleteForward
        ;;
        13)
            V2rayConfigUpdate
            V2rayListForward
            V2rayDeleteForwardAccount
        ;;
        14)
            Println "$error not ready~\n" && exit 1
            V2rayConfigUpdate
            V2rayConfigRouting
        ;;
        15)
            Println "$error not ready~\n" && exit 1
            V2rayConfigUpdate
            V2rayConfigLevels
        ;;
        16)
            Println "$error not ready~\n" && exit 1
            V2rayConfigUpdate
            V2rayListTraffic
        ;;
        17) 
            if [ ! -e "$V2_CONFIG" ] 
            then
                Println "$error v2ray 未安装...\n" && exit 1
            fi

            if service v2ray status > /dev/null 2>&1
            then
                Println "v2ray 正在运行，是否关闭？[Y/n]"
                read -p "(默认: Y): " v2ray_stop_yn
                v2ray_stop_yn=${v2ray_stop_yn:-Y}
                if [[ $v2ray_stop_yn == [Yy] ]] 
                then
                    service v2ray stop > /dev/null 2>&1
                    Println "$info v2ray 已关闭\n"
                else
                    Println "已取消...\n" && exit 1
                fi
            else
                Println "v2ray 未运行，是否开启？[Y/n]"
                read -p "(默认: Y): " v2ray_start_yn
                v2ray_start_yn=${v2ray_start_yn:-Y}
                if [[ $v2ray_start_yn == [Yy] ]] 
                then
                    service v2ray start > /dev/null 2>&1
                    Println "$info v2ray 已开启\n"
                else
                    Println "已取消...\n" && exit 1
                fi
            fi
        ;;
        18) 
            if [ ! -e "$V2_CONFIG" ] 
            then
                Println "$error v2ray 未安装...\n" && exit 1
            fi
            service v2ray restart > /dev/null 2>&1
            Println "$info v2ray 已重启\n"
        ;;
        *) Println "$error 请输入正确的数字 [1-18]\n"
        ;;
    esac
    exit 0
elif [ "${0##*/}" == "cx" ] 
then
    [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1

    Println "  Xtream Codes 面板 $plain

${green}1.$plain 查看账号
${green}2.$plain 添加账号
${green}3.$plain 更新账号
${green}4.$plain 检测账号
${green}5.$plain 获取账号
————————————
${green}6.$plain 查看 mac 地址
${green}7.$plain 添加 mac 地址
${green}8.$plain 浏览频道

"
    read -p "请输入数字 [1-8]：" xtream_codes_num

    case $xtream_codes_num in
        1) 
            ViewXtreamCodesAcc
        ;;
        2) 
            AddXtreamCodesAccount
            ListXtreamCodes
        ;;
        3) 
            [ ! -s "$XTREAM_CODES" ] && Println "$error 没有账号 !\n" && exit 1
            Println "$info 更新中...\n"
            result=""
            while IFS= read -r line 
            do
                line=${line#* }
                domain_line=${line%% *}
                account_line=${line#* }
                IFS="|" read -ra domains <<< "$domain_line"
                IFS=" " read -ra accounts <<< "$account_line"
                for domain in "${domains[@]}"
                do
                    ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
                    if [ -n "${ip:-}" ] 
                    then
                        for account in "${accounts[@]}"
                        do
                            [ -n "$result" ] && result="$result\n"
                            result="$result$ip $domain $account"
                        done
                    fi
                done
            done < "$XTREAM_CODES"
            echo -e "$result" >> "$XTREAM_CODES"
            ListXtreamCodes
            Println "$info 账号更新成功\n"
        ;;
        4) 
            TestXtreamCodes
        ;;
        5) 
            Println "$info 稍等...\n"
            result=""
            while IFS= read -r line 
            do
                line=${line#* }
                domain_line=${line%% *}
                account_line=${line#* }
                IFS="|" read -ra domains <<< "$domain_line"
                IFS=" " read -ra accounts <<< "$account_line"
                for domain in "${domains[@]}"
                do
                    ip=$(getent ahosts "${domain%%:*}" | awk '{ print $1 ; exit }' || true)
                    if [ -n "${ip:-}" ] 
                    then
                        for account in "${accounts[@]}"
                        do
                            [ -n "$result" ] && result="$result\n"
                            result="$result$ip $domain $account"
                        done
                    fi
                done
            done < <(wget --tries=3 --no-check-certificate $XTREAM_CODES_LINK -qO-)
            echo -e "$result" >> "$XTREAM_CODES"
            ListXtreamCodes
            Println "$info 账号添加成功\n"
        ;;
        6) 
            ViewXtreamCodesMac
        ;;
        7) 
            AddXtreamCodesMac
            if [ "$add_mac_success" -eq 1 ] 
            then
                ListXtreamCodes mac
                Println "$info mac 添加成功!\n"
            fi
        ;;
        8) 
            ViewXtreamCodesChnls
        ;;
        *) Println "$error 请输入正确的数字 [1-8]\n"
        ;;
    esac
    exit 0
fi

if [[ -n ${1+x} ]]
then
    case $1 in
        "s") 
            [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请先安装 !" && exit 1
            Schedule "$@"
            exit 0
        ;;
        "m") 
            [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请先安装 !" && exit 1

            cmd=${2:-}

            case $cmd in
                "s"|"stop") 
                    MonitorStop
                ;;
                "l"|"log")
                    if [ -s "$MONITOR_LOG" ] 
                    then
                        Println "$info 监控日志: "
                        count=0
                        log=""
                        last_line=""
                        printf -v this_hour '%(%H)T'
                        while IFS= read -r line 
                        do
                            if [ "$count" -lt "${3:-10}" ] 
                            then
                                message=${line#* }
                                message=${message#* }
                                if [ -z "$last_line" ] 
                                then
                                    count=$((count+1))
                                    log=$line
                                    last_line=$message
                                elif [ "$message" != "$last_line" ] 
                                then
                                    count=$((count+1))
                                    log="$line\n$log"
                                    last_line="$message"
                                fi
                            fi

                            if [ "${line:2:1}" == "-" ] 
                            then
                                hour=${line:6:2}
                            elif [ "${line:2:1}" == ":" ] 
                            then
                                hour=${line:0:2}
                            fi

                            if [ -n "${hour:-}" ] && [ "$hour" != "$this_hour" ] && [ "$count" -eq "${3:-10}" ] 
                            then
                                break
                            elif [ -n "${hour:-}" ] && [ "$hour" == "$this_hour" ] && [[ $line == *"计划重启时间"* ]]
                            then
                                [ -z "${found_line:-}" ] && found_line=$line
                            fi
                        done < <(awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }' "$MONITOR_LOG")
                        Println "$log"
                        [ -n "${found_line:-}" ] && Println "$green${found_line#* }$plain"
                    fi
                    if [ -s "$IP_LOG" ] 
                    then
                        Println "$info AntiDDoS 日志: "
                        tail -n 10 "$IP_LOG"
                    fi
                    if [ ! -s "$MONITOR_LOG" ] && [ ! -s "$IP_LOG" ]
                    then
                        Println "$error 无日志"
                    fi
                ;;
                *) 
                    if ls -A "/tmp/monitor.lockdir/"* > /dev/null 2>&1
                    then
                        Println "$error 监控已经在运行 !\n" && exit 1
                    else
                        printf -v date_now '%(%m-%d %H:%M:%S)T'
                        MonitorSet
                        if [ "$sh_debug" -eq 1 ] 
                        then
                            ( Monitor ) >> "$MONITOR_LOG" 2>> "$MONITOR_LOG" < /dev/null &
                        else
                            ( Monitor ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
                        fi
                        Println "$info 监控启动成功 !"
                        [ -e "$IPTV_ROOT/monitor.pid" ] && rm -f "$IPTV_ROOT/monitor.pid"
                        AntiDDoSSet
                        if [ "$sh_debug" -eq 1 ] 
                        then
                            ( AntiDDoS ) >> "$MONITOR_LOG" 2>> "$MONITOR_LOG" < /dev/null &
                        else
                            ( AntiDDoS ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
                        fi
                        Println "$info AntiDDoS 启动成功 !\n"
                        [ -e "$IPTV_ROOT/ip.pid" ] && rm -f "$IPTV_ROOT/ip.pid"
                    fi
                ;;
            esac
            exit 0
        ;;
        *)
        ;;
    esac
fi

cmd=$*
case "$cmd" in
    "e") 
        [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
        vim "$CHANNELS_FILE" && exit 0
    ;;
    "ee") 
        [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
        GetDefault
        [ -z "$d_sync_file" ] && Println "$error sync_file 未设置，请检查 !" && exit 1
        vim "${d_sync_file%% *}" && exit 0
    ;;
    "d")
        [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
        channels=""
        while IFS= read -r line 
        do
            if [[ $line == *\"pid\":* ]] 
            then
                pid=${line#*:}
                pid=${pid%,*}
                rand_pid=$pid
                while [[ -n $($JQ_FILE '.channels[]|select(.pid=='"$rand_pid"')' "$CHANNELS_FILE") ]] 
                do
                    true &
                    rand_pid=$!
                done
                line=${line//$pid/$rand_pid}
            fi
            channels="$channels$line"
        done < <(wget --no-check-certificate "$DEFAULT_DEMOS" -qO-)
        JQ add "$CHANNELS_FILE" channels "$channels"
        Println "$info 频道添加成功 !\n"
        exit 0
    ;;
    "ffmpeg") 
        [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
        if grep -q '\--show-progress' < <(wget --help)
        then
            _PROGRESS_OPT="--show-progress"
        else
            _PROGRESS_OPT=""
        fi
        mkdir -p "$FFMPEG_MIRROR_ROOT/builds"
        mkdir -p "$FFMPEG_MIRROR_ROOT/releases"
        git_download=0
        release_download=0
        git_version_old=""
        release_version_old=""
        if [ -e "$FFMPEG_MIRROR_ROOT/index.html" ] 
        then
            while IFS= read -r line
            do
                if [[ $line == *"<th>"* ]] 
                then
                    if [[ $line == *"git"* ]] 
                    then
                        git_version_old=$line
                    else
                        release_version_old=$line
                    fi
                fi
            done < "$FFMPEG_MIRROR_ROOT/index.html"
        fi

        wget --no-check-certificate "https://www.johnvansickle.com/ffmpeg/index.html" -qO "$FFMPEG_MIRROR_ROOT/index.html_tmp"
        mv "$FFMPEG_MIRROR_ROOT/index.html_tmp" "$FFMPEG_MIRROR_ROOT/index.html"
        wget --no-check-certificate "https://www.johnvansickle.com/ffmpeg/style.css" -qO "$FFMPEG_MIRROR_ROOT/style.css"

        while IFS= read -r line
        do
            if [[ $line == *"<th>"* ]] 
            then
                if [[ $line == *"git"* ]] 
                then
                    git_version_new=$line
                    [ "$git_version_new" != "$git_version_old" ] && git_download=1
                else
                    release_version_new=$line
                    [ "$release_version_new" != "$release_version_old" ] && release_download=1
                fi
            fi

            if [[ $line == *"tar.xz"* ]]  
            then
                if [[ $line == *"git"* ]] && [ "$git_download" -eq 1 ]
                then
                    line=${line#*<td><a href=\"}
                    git_link=${line%%\" style*}
                    build_file_name=${git_link##*/}
                    wget --timeout=10 --tries=3 --no-check-certificate "$git_link" $_PROGRESS_OPT -qO "$FFMPEG_MIRROR_ROOT/builds/${build_file_name}_tmp"
                    if [ ! -s "$FFMPEG_MIRROR_ROOT/builds/${build_file_name}_tmp" ] 
                    then
                        Println "$error 无法连接 github !" && exit 1
                    fi
                    mv "$FFMPEG_MIRROR_ROOT/builds/${build_file_name}_tmp" "$FFMPEG_MIRROR_ROOT/builds/${build_file_name}"
                else 
                    if [ "$release_download" -eq 1 ] 
                    then
                        line=${line#*<td><a href=\"}
                        release_link=${line%%\" style*}
                        release_file_name=${release_link##*/}
                        wget --timeout=10 --tries=3 --no-check-certificate "$release_link" $_PROGRESS_OPT -qO "$FFMPEG_MIRROR_ROOT/releases/${release_file_name}_tmp"
                        if [ ! -s "$FFMPEG_MIRROR_ROOT/builds/${release_file_name}_tmp" ] 
                        then
                            Println "$error 无法连接 github !" && exit 1
                        fi
                        mv "$FFMPEG_MIRROR_ROOT/releases/${release_file_name}_tmp" "$FFMPEG_MIRROR_ROOT/releases/${release_file_name}"
                    fi
                fi
            fi

        done < "$FFMPEG_MIRROR_ROOT/index.html"

        #Println "输入镜像网站链接(比如：$FFMPEG_MIRROR_LINK)"
        #read -p "(默认: 取消): " FFMPEG_LINK
        #[ -z "$FFMPEG_LINK" ] && echo "已取消..." && exit 1
        #sed -i "s+https://johnvansickle.com/ffmpeg/\(builds\|releases\)/\(.*\).tar.xz\"+$FFMPEG_LINK/\1/\2.tar.xz\"+g" "$FFMPEG_MIRROR_ROOT/index.html"

        sed -i "s+https://johnvansickle.com/ffmpeg/\(builds\|releases\)/\(.*\).tar.xz\"+\1/\2.tar.xz\"+g" "$FFMPEG_MIRROR_ROOT/index.html"

        while IFS= read -r line
        do
            if [[ $line == *"latest stable release is"* ]] 
            then
                line=${line#*<a href=\"}
                poppler_name=${line%%.tar.xz*}
                poppler_name="poppler-0.81.0"
                if [ ! -e "$FFMPEG_MIRROR_ROOT/$poppler_name.tar.xz" ] 
                then
                    rm -f "$FFMPEG_MIRROR_ROOT/poppler-"*.tar.xz
                    wget --timeout=10 --tries=3 --no-check-certificate "https://poppler.freedesktop.org/$poppler_name.tar.xz" -qO "$FFMPEG_MIRROR_ROOT/$poppler_name.tar.xz_tmp"
                    mv "$FFMPEG_MIRROR_ROOT/$poppler_name.tar.xz_tmp" "$FFMPEG_MIRROR_ROOT/$poppler_name.tar.xz"
                fi
            elif [[ $line == *"poppler encoding data"* ]] 
            then
                line=${line#*<a href=\"}
                poppler_data_name=${line%%.tar.gz*}
                if [ ! -e "$FFMPEG_MIRROR_ROOT/$poppler_data_name.tar.gz" ] 
                then
                    rm -f "$FFMPEG_MIRROR_ROOT/poppler-data-"*.tar.gz
                    wget --timeout=10 --tries=3 --no-check-certificate "https://poppler.freedesktop.org/$poppler_data_name.tar.gz" -qO "$FFMPEG_MIRROR_ROOT/$poppler_data_name.tar.gz_tmp"
                    mv "$FFMPEG_MIRROR_ROOT/$poppler_data_name.tar.gz_tmp" "$FFMPEG_MIRROR_ROOT/$poppler_data_name.tar.gz"
                fi
                break
            fi
        done < <( wget --timeout=10 --tries=3 --no-check-certificate "https://poppler.freedesktop.org/" -qO- )

        jq_ver=$(curl --silent -m 10 "https://api.github.com/repos/stedolan/jq/releases/latest" |  grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
        if [ -n "$jq_ver" ]
        then
            mkdir -p "$FFMPEG_MIRROR_ROOT/$jq_ver/"
            wget --timeout=10 --tries=3 --no-check-certificate "https://github.com/stedolan/jq/releases/download/$jq_ver/jq-linux64" $_PROGRESS_OPT -qO "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux64_tmp"
            wget --timeout=10 --tries=3 --no-check-certificate "https://github.com/stedolan/jq/releases/download/$jq_ver/jq-linux32" $_PROGRESS_OPT -qO "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux32_tmp"
            if [ ! -s "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux64_tmp" ] || [ ! -s "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux32_tmp" ]
            then
                Println "$error 无法连接 github !" && exit 1
            fi
            mv "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux64_tmp" "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux64"
            mv "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux32_tmp" "$FFMPEG_MIRROR_ROOT/$jq_ver/jq-linux32"
        fi

        wget --timeout=10 --tries=3 --no-check-certificate "https://github.com/winshining/nginx-http-flv-module/archive/master.zip" -qO "$FFMPEG_MIRROR_ROOT/nginx-http-flv-module.zip_tmp"
        mv "$FFMPEG_MIRROR_ROOT/nginx-http-flv-module.zip_tmp" "$FFMPEG_MIRROR_ROOT/nginx-http-flv-module.zip"
        wget --timeout=10 --tries=3 --no-check-certificate "https://github.com/eddieantonio/imgcat/archive/master.zip" -qO "$FFMPEG_MIRROR_ROOT/imgcat.zip_tmp"
        mv "$FFMPEG_MIRROR_ROOT/imgcat.zip_tmp" "$FFMPEG_MIRROR_ROOT/imgcat.zip"
        wget --timeout=10 --tries=3 --no-check-certificate "https://api.github.com/repos/stedolan/jq/releases/latest" -qO "$FFMPEG_MIRROR_ROOT/jq.json_tmp"
        mv "$FFMPEG_MIRROR_ROOT/jq.json_tmp" "$FFMPEG_MIRROR_ROOT/jq.json"

        if [ ! -e "$FFMPEG_MIRROR_ROOT/fontforge-20190413.tar.gz" ] 
        then
            wget --timeout=10 --tries=3 --no-check-certificate "https://github.com/fontforge/fontforge/releases/download/20190413/fontforge-20190413.tar.gz" -qO "$FFMPEG_MIRROR_ROOT/fontforge-20190413.tar.gz_tmp"
            mv "$FFMPEG_MIRROR_ROOT/fontforge-20190413.tar.gz_tmp" "$FFMPEG_MIRROR_ROOT/fontforge-20190413.tar.gz"
        fi

        if [ ! -e "$FFMPEG_MIRROR_ROOT/pdf2htmlEX-0.18.7-poppler-0.81.0.zip" ] 
        then
            wget --timeout=10 --tries=3 --no-check-certificate "https://github.com/pdf2htmlEX/pdf2htmlEX/archive/v0.18.7-poppler-0.81.0.zip" -qO "$FFMPEG_MIRROR_ROOT/pdf2htmlEX-0.18.7-poppler-0.81.0.zip_tmp"
            mv "$FFMPEG_MIRROR_ROOT/pdf2htmlEX-0.18.7-poppler-0.81.0.zip_tmp" "$FFMPEG_MIRROR_ROOT/pdf2htmlEX-0.18.7-poppler-0.81.0.zip"
        fi
        exit 0
    ;;
    "ts") 
        [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
        TsMenu
        exit 0
    ;;
    "f") 
        [ ! -e "$IPTV_ROOT" ] && Println "$error 尚未安装，请检查 !" && exit 1
        kind="flv"
    ;;
    "l"|"ll") 
        flv_count=0
        chnls_channel_name=()
        chnls_stream_link=()
        chnls_flv_pull_link=()
        while IFS= read -r flv_channel
        do
            flv_count=$((flv_count+1))
            map_channel_name=${flv_channel#*channel_name: }
            map_channel_name=${map_channel_name%, stream_link:*}
            map_stream_link=${flv_channel#*, stream_link: }
            map_stream_link=${map_stream_link%, flv_pull_link:*}
            map_flv_pull_link=${flv_channel#*, flv_pull_link: }
            map_flv_pull_link=${map_flv_pull_link%\"}

            chnls_channel_name+=("$map_channel_name")
            chnls_stream_link+=("${map_stream_link// /, }")
            chnls_flv_pull_link+=("${map_flv_pull_link}")
        done < <($JQ_FILE '.channels | to_entries | map(select(.value.flv_status=="on")) | map("channel_name: \(.value.channel_name), stream_link: \(.value.stream_link), flv_pull_link: \(.value.flv_pull_link)") | .[]' "$CHANNELS_FILE")

        if [ "$flv_count" -gt 0 ] 
        then

            Println "FLV 频道"
            result=""
            for((i=0;i<flv_count;i++));
            do
                if [ "$i" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                chnl_flv_pull_link=${chnls_flv_pull_link[i]}
                result=$result"  $green$((i+1)).$plain $blank$green${chnls_channel_name[i]}$plain\n      源: ${chnls_stream_link[i]}\n      pull: ${chnl_flv_pull_link:-无}\n\n"
            done
            Println "$result"
        fi


        hls_count=0
        chnls_channel_name=()
        chnls_stream_link=()
        chnls_output_dir_name=()
        while IFS= read -r hls_channel
        do
            hls_count=$((hls_count+1))
            map_channel_name=${hls_channel#*channel_name: }
            map_channel_name=${map_channel_name%, stream_link:*}
            map_stream_link=${hls_channel#*stream_link: }
            map_stream_link=${map_stream_link%, output_dir_name:*}
            map_output_dir_name=${hls_channel#*output_dir_name: }
            map_output_dir_name=${map_output_dir_name%\"}

            chnls_channel_name+=("$map_channel_name")
            chnls_stream_link+=("${map_stream_link// /, }")
            chnls_output_dir_name+=("$map_output_dir_name")
        done < <($JQ_FILE '.channels | to_entries | map(select(.value.status=="on")) | map("channel_name: \(.value.channel_name), stream_link: \(.value.stream_link), output_dir_name: \(.value.output_dir_name)") | .[]' "$CHANNELS_FILE")

        if [ "$hls_count" -gt 0 ] 
        then
            Println "HLS 频道"
            result=""
            for((i=0;i<hls_count;i++));
            do
                if [ "$i" -lt 9 ] 
                then
                    blank=" "
                else
                    blank=""
                fi
                result=$result"  $green$((i+1)).$plain $blank$green${chnls_channel_name[i]}$plain\n      源: ${chnls_stream_link[i]}\n\n"
            done
            Println "$result"
        fi

        echo 

        for((i=0;i<hls_count;i++));
        do
            echo -e "  $green$((i+1)).$plain ${chnls_channel_name[i]} ${chnls_stream_link[i]}"
            if [ -e "$LIVE_ROOT/${chnls_output_dir_name[i]}" ] 
            then
                if ls -A "$LIVE_ROOT/${chnls_output_dir_name[i]}"/* > /dev/null 2>&1 
                then
                    ls "$LIVE_ROOT/${chnls_output_dir_name[i]}"/* -lght && echo
                else
                    Println "$error 无\n"
                fi
            else
                Println "$error 目录不存在\n"
            fi
        done
        

        if ls -A $LIVE_ROOT/* > /dev/null 2>&1 
        then
            for output_dir_root in "$LIVE_ROOT"/* ; do
                found=0
                output_dir_name=${output_dir_root#*$LIVE_ROOT/}
                for((i=0;i<hls_count;i++));
                do
                    if [ "$output_dir_name" == "${chnls_output_dir_name[i]}" ] 
                    then
                        found=1
                    fi
                done
                if [ "$found" -eq 0 ] 
                then
                    Println "$error 未知目录 $output_dir_name\n"
                    if ls -A "$output_dir_root"/* > /dev/null 2>&1 
                    then
                        ls "$output_dir_root"/* -lght
                    fi
                fi
            done
        fi

        if [ "$flv_count" -eq 0 ] && [ "$hls_count" -eq 0 ]
        then
            Println "$error 没有开启的频道 !\n" && exit 1
        fi

        exit 0
    ;;
    *)
    ;;
esac

use_menu=1

while getopts "i:l:P:o:p:S:t:s:c:v:a:f:q:b:k:K:m:n:z:T:L:Ce" flag
do
    use_menu=0
    case "$flag" in
        i) stream_link="$OPTARG";;
        l) live_yn="no";;
        P) proxy="$OPTARG";;
        o) output_dir_name="$OPTARG";;
        p) playlist_name="$OPTARG";;
        S) seg_dir_name="$OPTARG";;
        t) seg_name="$OPTARG";;
        s) seg_length="$OPTARG";;
        c) seg_count="$OPTARG";;
        v) video_codec="$OPTARG";;
        a) audio_codec="$OPTARG";;
        f) video_audio_shift="$OPTARG";;
        q) quality="$OPTARG";;
        b) bitrates="$OPTARG";;
        C) const="-C";;
        e) encrypt="-e";;
        k) kind="$OPTARG";;
        K) key_name="$OPTARG";;
        m) input_flags="$OPTARG";;
        n) output_flags="$OPTARG";;
        z) channel_name="$OPTARG";;
        T) flv_push_link="$OPTARG";;
        L) flv_pull_link="$OPTARG";;
        *) Usage;
    esac
done

if [ "$use_menu" == "1" ]
then
    CheckShFile

    Println "  ${gray_underlined}MTimer | http://hbo.epub.fun$plain

  IPTV 一键管理脚本 ${red}[v$sh_ver]$plain

  ${green}1.$plain 安装
  ${green}2.$plain 卸载
  ${green}3.$plain 升级脚本
————————————
  ${green}4.$plain 查看频道
  ${green}5.$plain 添加频道
  ${green}6.$plain 修改频道
  ${green}7.$plain 开关频道
  ${green}8.$plain 重启频道
  ${green}9.$plain 查看日志
 ${green}10.$plain 删除频道

 $tip 输入: tv 打开 HLS 面板, tv f 打开 FLV 面板\n\n"
    read -p "请输入数字 [1-10]：" menu_num
    case "$menu_num" in
        1) Install
        ;;
        2) Uninstall
        ;;
        3) Update
        ;;
        4) ViewChannelMenu
        ;;
        5) AddChannel
        ;;
        6) EditChannelMenu
        ;;
        7) ToggleChannel
        ;;
        8) RestartChannel
        ;;
        9) ViewChannelLog
        ;;
        10) DelChannel
        ;;
        *) Println "$error 请输入正确的数字 [1-10]\n"
        ;;
    esac
else
    if [ -z "${stream_link:-}" ]
    then
        Usage
    else
        if [ ! -e "$IPTV_ROOT" ]
        then
            echo && read -p "尚未安装,是否现在安装？[y/N] (默认: N): " install_yn
            install_yn=${install_yn:-N}
            if [[ $install_yn == [Yy] ]]
            then
                Install
            else
                Println "已取消...\n" && exit 1
            fi
        else
            CheckRelease
            FFMPEG_ROOT=$(dirname "$IPTV_ROOT"/ffmpeg-git-*/ffmpeg)
            FFMPEG="$FFMPEG_ROOT/ffmpeg"
            GetDefault
            export FFMPEG
            live_yn=${live_yn:-yes}
            proxy=${proxy:-$d_proxy}
            if [ "${stream_link:0:4}" != "http" ] 
            then
                proxy=""
            fi
            if [ -n "$proxy" ] 
            then
                proxy_command="-http_proxy $proxy"
            else
                proxy_command=""
            fi
            user_agent=$d_user_agent
            headers=$d_headers
            if [ -n "$headers" ] && [[ ! $headers == *"\r\n" ]] && [[ $headers == *"\r\n"* ]]
            then
                headers="$headers\r\n"
            fi
            cookies=$d_cookies
            output_dir_name=${output_dir_name:-$(RandOutputDirName)}
            output_dir_root="$LIVE_ROOT/$output_dir_name"
            playlist_name=${playlist_name:-$(RandPlaylistName)}
            export SEGMENT_DIRECTORY=${seg_dir_name:-}
            seg_name=${seg_name:-$playlist_name}
            seg_length=${seg_length:-$d_seg_length}
            seg_count=${seg_count:-$d_seg_count}
            export AUDIO_CODEC=${audio_codec:-$d_audio_codec}
            export VIDEO_CODEC=${video_codec:-$d_video_codec}
            
            video_audio_shift=${video_audio_shift:-}
            v_or_a=${video_audio_shift%_*}
            if [ "$v_or_a" == "v" ] 
            then
                video_shift=${video_audio_shift#*_}
            elif [ "$v_or_a" == "a" ] 
            then
                audio_shift=${video_audio_shift#*_}
            fi

            quality=${quality:-$d_quality}
            bitrates=${bitrates:-$d_bitrates}
            quality_command=""
            bitrates_command=""

            if [ -z "${kind:-}" ] && [ "$VIDEO_CODEC" == "copy" ] && [ "$AUDIO_CODEC" == "copy" ]
            then
                quality=""
                bitrates=""
                const=""
                const_yn="no"
                master=0
            else
                if [ -z "${const:-}" ]  
                then
                    if [ "$d_const_yn" == "yes" ] 
                    then
                        const="-C"
                        const_yn="yes"
                    else
                        const=""
                        const_yn="no"
                    fi
                else
                    const_yn="yes"
                fi

                if [ -n "$quality" ] 
                then
                    const=""
                    const_yn="no"
                fi

                if [ -n "$bitrates" ] 
                then
                    if [[ $bitrates != *"-"* ]] && [[ $bitrates == *"x"* ]]
                    then
                        master=0
                    else
                        master=1
                    fi
                else
                    master=0
                fi
            fi

            if [ -z "${encrypt:-}" ]  
            then
                if [ "$d_encrypt_yn" == "yes" ] 
                then
                    encrypt="-e"
                    encrypt_yn="yes"
                else
                    encrypt=""
                    encrypt_yn="no"
                fi
            else
                encrypt_yn="yes"
            fi

            encrypt_session_yn="no"
            keyinfo_name=${keyinfo_name:-$d_keyinfo_name}
            keyinfo_name=${keyinfo_name:-$(RandStr)}
            key_name=${key_name:-$d_key_name}
            key_name=${key_name:-$(RandStr)}

            if [ "${stream_link:0:4}" == "rtmp" ] || [ "${stream_link:0:1}" == "/" ]
            then
                d_input_flags=${d_input_flags//-timeout 2000000000/}
                d_input_flags=${d_input_flags//-reconnect 1/}
                d_input_flags=${d_input_flags//-reconnect_at_eof 1/}
                d_input_flags=${d_input_flags//-reconnect_streamed 1/}
                d_input_flags=${d_input_flags//-reconnect_delay_max 2000/}
                lead=${d_input_flags%%[^[:blank:]]*}
                d_input_flags=${d_input_flags#${lead}}
            elif [[ $stream_link == *".m3u8"* ]]
            then
                d_input_flags=${d_input_flags//-reconnect_at_eof 1/}
            fi

            input_flags=${input_flags:-$d_input_flags}
            if [[ ${input_flags:0:1} == "'" ]] 
            then
                input_flags=${input_flags%\'}
                input_flags=${input_flags#\'}
            fi
            export FFMPEG_INPUT_FLAGS=$input_flags

            if [ "${output_flags:-}" == "omit" ] 
            then
                output_flags=""
            else
                output_flags=${d_input_flags}
            fi

            if [[ ${output_flags:0:1} == "'" ]] 
            then
                output_flags=${output_flags%\'}
                output_flags=${output_flags#\'}
            fi
            export FFMPEG_FLAGS=$output_flags

            channel_name=${channel_name:-$playlist_name}
            sync_yn=$d_sync_yn

            [ ! -e $FFMPEG_LOG_ROOT ] && mkdir $FFMPEG_LOG_ROOT
            from="command"

            if [ -n "${kind:-}" ] 
            then
                if [ "$kind" == "flv" ] 
                then
                    if [ -z "${flv_push_link:-}" ] 
                    then
                        Println "$error 未设置推流地址...\n" && exit 1
                    else
                        flv_pull_link=${flv_pull_link:-}
                        if [ "$sh_debug" -eq 1 ] 
                        then
                            ( FlvStreamCreatorWithShift ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
                        else
                            ( FlvStreamCreatorWithShift ) > /dev/null 2> /dev/null < /dev/null &
                        fi
                    fi
                else
                    Println "$error 暂不支持输出 $kind ...\n" && exit 1
                fi
            elif [ -n "${video_audio_shift:-}" ] || [ "$encrypt_yn" == "yes" ]
            then
                if [ "$sh_debug" -eq 1 ] 
                then
                    ( HlsStreamCreatorPlus ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
                else
                    ( HlsStreamCreatorPlus ) > /dev/null 2> /dev/null < /dev/null &
                fi
            else
                if [ "$sh_debug" -eq 1 ] 
                then
                    ( HlsStreamCreator ) > /dev/null 2>> "$MONITOR_LOG" < /dev/null &
                else
                    ( HlsStreamCreator ) > /dev/null 2> /dev/null < /dev/null &
                fi
            fi

            Println "$info 添加频道成功...\n"
        fi
    fi
fi