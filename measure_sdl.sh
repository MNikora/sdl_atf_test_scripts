#! /bin/env bash

# apt-get install sysstat linux-tools-common linux-tools-generic linux-tools-`uname -r`

SDL_PID=$(pidof smartDeviceLinkCore)

OUTPUT_DIR="measure"/$1
OUTPUT_PIDSTAT_FILE=$OUTPUT_DIR/pidstat
OUTPUT_PERF_FILE=$OUTPUT_DIR/perf
OUTPUT_PS_FILE=$OUTPUT_DIR/ps

STEP=0.1

rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
function ps_formated() {
     ps  --no-headers --format "start %cpu cp cputime %mem sz thcount " -p $SDL_PID
}


function measure_ps() {
    PS_OUTPUT=$(ps_formated)
    TIME=$(date +'%T:%N')
    echo $TIME $PS_OUTPUT >> $OUTPUT_PS_FILE
}

function measure_pid_stat() {
    export S_TIME_FORMAT=ISO
    STAT_OUTPUT=$(pidstat -urdlv -h -p $SDL_PID | grep $SDL_PID)
    echo $STAT_OUTPUT >> $OUTPUT_PIDSTAT_FILE
}

echo Whait for SDL start
until SDL_PID=$(pidof smartDeviceLinkCore)
do   
    sleep $STEP
    printf "."
done

sudo perf stat -p $SDL_PID > $OUTPUT_PERF_FILE &
while SDL_PID=$(pidof smartDeviceLinkCore)
do   
    measure_pid_stat
    measure_ps
    sleep $STEP
done

python3 ./sdl_graphs.py --pidstat_file=$OUTPUT_PIDSTAT_FILE --ps_file=$OUTPUT_PS_FILE --output_dir=$OUTPUT_DIR --title=$1
