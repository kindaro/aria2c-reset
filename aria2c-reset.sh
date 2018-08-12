#!/bin/sh -e

Stop () {
    reason="$1"
    if [ "$reason" ]
    then echo "Stopping! Reason: $reason"
    else echo "Stopping for unknown reason!"
    fi

    Terminate "Because of stopping."
    Clean "Because of stopping."
    trap - EXIT
    exit 1
}

Clean () {
    reason="$1"
    if [ "$reason" ]
    then echo "Cleaning! Reason: $reason"
    else echo "Cleaning for unknown reason!"
    fi

    rm "$tmpfifo"
    rmdir "$tmpdir"
}

Terminate () {
    reason="$1"
    if [ "$reason" ]
    then echo "Terminating! Reason: $reason"
    else echo "Terminating for unknown reason!"
    fi

    if [ "$aria2c_pid" ]
    then
        if ps "$aria2c_pid" > /dev/null
        then
            echo "Terminating $aria2c_pid!"
            /bin/kill "$aria2c_pid"
            sleep 1

            if ps "$aria2c_pid" > /dev/null
            then
                echo "Killing $aria2c_pid!"
                /bin/kill --signal kill "$aria2c_pid"
            fi
        fi
    else
        echo "Process ID unavailable!"
    fi
}

echo "Starting aria2c with arguments:" "$@"

strikes=0
speed=0

expected_raw_speed="$1"
shift
tolerance="$1"
shift

tmpdir=`mktemp --directory`
tmpfifo="$tmpdir/aria2c-fifo"
mkfifo "$tmpfifo"

trap Stop INT TERM TSTP EXIT

while true
do
    echo "Starting download."

    aria2c "$@" --log - > "$tmpfifo" &
    aria2c_pid=$!
    echo "Aria pid: $aria2c_pid"

    cat "$tmpfifo" | grep --line-buffered '\[.* DL:[^ ]\+ ETA:[^ ]\+.*\]' |
        while read -r line
        do
            progress="` echo "$line" | grep -o '([0-9]\+%)' | grep -o '[0-9]\+%' `"
            raw_speed="` echo "$line" | grep -o ' DL:[0-9.]\+[K]iB ' `"
            number_speed="` echo "$raw_speed" | grep -o '[0-9]\+' | head -n 1 `"
            suffix_speed="` echo "$raw_speed" | grep -o '[A-Za-z]*B' `"

            echo "Progress: $progress Speed: $number_speed $suffix_speed"
            case "$suffix_speed" in
                KiB  ) 
                    speed=$((number_speed * 1))
                    ;;
                MiB  ) 
                    speed=$((number_speed * 1024))
                    ;;
                B    )
                    speed=0
                    ;;
                *     ) 
                    Stop "Cannot parse speed!"
                    ;;
            esac

            if [ "$speed" -lt "$expected_raw_speed" ]
            then
                strikes=$((strikes + 1))
            fi
            
            if [ "$strikes" -ge "$tolerance" ]
            then
                Terminate "$strikes strikes collected."
                strikes=0
                sleep 1
                continue 2
            fi
        done
done
Stop "Successfully completed download."
