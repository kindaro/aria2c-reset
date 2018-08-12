#!/bin/sh -e

Stop () {
    echo "Stopping!"
    Terminate
    Clean
    exit 1
}

Clean () {
    echo "Cleaning!"
    rm "$tmpfifo"
    rmdir "$tmpdir"
}

Terminate () {
    echo "Terminating $aria2c_pid!"
    /bin/kill "$aria2c_pid"
    sleep 1
    if ps "$aria2c_pid" > /dev/null
    then
        echo "Killing $aria2c_pid!"
        /bin/kill --signal kill "$aria2c_pid"
    fi
}

echo "Starting aria2c with arguments:" "$@"

declare -i strikes=0
declare -i speed=0

declare -i expected_raw_speed="$1"
shift
declare -i tolerance="$1"
shift

tmpdir=`mktemp --directory`
tmpfifo="$tmpdir/aria2c-fifo"
mkfifo "$tmpfifo"

trap Stop SIGINT SIGTERM SIGTSTP EXIT

while true
do
    echo "Starting download."
    flag="In process"

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
                    echo "Cannot parse speed!"
                    exit
                    ;;
            esac

            if [ "$speed" -lt "$expected_raw_speed" ]
            then
                strikes=$((strikes + 1))
            fi
            
            if [ "$strikes" -ge "$tolerance" ]
            then
                strikes=0
                Terminate
                sleep 1
                continue 2
            fi
        done
done
Stop
