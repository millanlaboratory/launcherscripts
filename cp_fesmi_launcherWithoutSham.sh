#!/bin/bash
cd ~/dev/CNBIscripts/
gnome-terminal --title "loop"\
---tab -e "bash -c 'cl_runloopscope -d gtec'" --title "Loop"

NAME="FESMILauncher"
subject="$(python3 launcher.py)"
if [ "$subject" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi

session="$(python3 launcherSession.py --subject $subject)"
if [ "$session" == "-1" ]; then
    killall cl_keepalive
    cl_killloop
    exit 1
fi

taskset="$(python3 launcherTaskSet.py)"
if [ "$taskset" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi
modality="$(python3 launcherModality.py)"
if [ "$modality" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi

xml="$(python3 getProtocol.py --subject $subject --modality $modality --session $session)"
if [ "$xml" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi


DEFAULT_MI_BLOCK="mi"
DEFAULT_MI_TASKSET="mi_fes_flexion"
DEFAULT_MI_MODALITY="offline"


GetStoreDir(){
	if [[ -z "${CNBITK_DATA}" ]]; then
		storedir="$(readlink -e /proc/$(pgrep cl_acquisition)/cwd)"
	else
		storedir="${CNBITK_DATA}"
	fi
	echo $storedir
}

error_handling(){
	if [ -z $1 ]; then
		return 0
	else
		code=$1
	fi

	if [ -z $2 ]; then
		name="Generic"
	else
		name=$2
	fi

	if [ $code -ne 0 ]; then
		echo "[$NAME] - $name error code: $code: Exit"
		killall cl_keepalive
		cl_killloop
		exit 1
	fi
}

storedir="${HOME}/data/"
block=$DEFAULT_MI_BLOCK

executable=$(ccfg_cli -x $xml -M $modality -B $block -p)
echo "[$NAME] - Xml:        $xml"
echo "[$NAME] - Movements:  $movements"
echo "[$NAME] - Subject:    $subject"
echo "[$NAME] - Block:      $block"
echo "[$NAME] - Taskset:    $taskset"
echo "[$NAME] - Modality:   $modality"
if [ "$executable" == "" ]; then
	echo "[$NAME] - Cannot retrieve executable name" >&2
	killall cl_keepalive
	cl_killloop
	exit 1
fi

subject=$(ccfg_getstring -x $xml -r cnbiconfig -p subject/id)
if [ "$subject" == "" ]; then
	echo "[$NAME] - Cannot retrieve subject id" >&2
	killall cl_keepalive
	cl_killloop
	exit 1
fi

successFES="$(python3 setupFESValues.py --task $taskset --subject $subject)"
if [ "$successFES" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi
successClassifier="$(python3 setClassifier.py --modality $modality --subject $subject --session $session --taskset $taskset)"
if [ "$successClassifier" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi

echo "[$NAME] - Starting FES control"
movements="$(python3 launcherFES.py $subject)"
if [ "$movements" == "-1" ]; then
	killall cl_keepalive
	cl_killloop
	exit 1
fi
gnome-terminal \
---tab -e "bash -c 'sleep 2; cl_keepalive fesControl -d verbose -n /dev -f $movements'" --title "FES control"

storedir="$storedir$subject/$session"
echo "[$NAME] - Data saving: $storedir "

# Get GDF and log names
gdfname=$(ccfg_cli -x $xml -M $modality -B $block -T $taskset -a)
logname=$(ccfg_cli -x $xml -M $modality -B $block -T $taskset -o)
if [ "$logname" == "" ] || [ "$gdfname" == "" ]; then
	echo "[$NAME] - Cannot retrieve gdf and log names " >&2
	killall cl_keepalive
	cl_killloop
	exit 1
fi

echo "[$NAME] - Xml:        $xml"
echo "[$NAME] - Movements:  $movements"
echo "[$NAME] - Subject:    $subject"
echo "[$NAME] - Block:      $block"
echo "[$NAME] - Taskset:    $taskset"
echo "[$NAME] - Modality:   $modality"
echo "[$NAME] - Executable: $executable"
echo "[$NAME] - GDF:        $gdfname"
echo "[$NAME] - LOG:        $logname"

# Upload all parameters to nameserver 
echo "[$NAME] - Uploading XML parameters to nameserver"
if [ "$modality" == "offline" ]; then
	echo "[$NAME] - Intializing offline"
	cl_init -x $xml -lF -B $block -T $taskset
elif [ "$modality" == "online" ]; then
	echo "[$NAME] - Intializing online"
	cl_init -x $xml -lN -B $block -T $taskset
	MATLABPID=$(cl_init -x $xml -sc -N -B $block -T $taskset)
else
	echo "[$NAME] - Unknown modality" >&2
	exit 1
fi

#error_handling $? cl_init

cl_rpc storeconfig $block subject $subject
error_handling $? cl_rpc

echo "[$NAME] - Saving files: $storedir" 

targetlog=$storedir"/"$gdfname".target.log"
cl_rpc storeconfig $block logname $targetlog

# Open GDF and log files
echo "[$NAME] - Opening GDF and log files"
logline=$(ccfg_cli -x $xml -M $modality -t $block -T $taskset -l)
logline="${logline%\"}"
logline="${logline#\"}"
cl_rpc openxdf $storedir"/"$gdfname".gdf" $logname "$storedir$logline"



# Launching the executable protocol
echo "[$NAME] - Launching executable protocol: $executable"
$executable

sleep 10

echo "[$NAME] - Closing GDF file"
cl_rpc closexdf
if [ "$modality" == "online" ]; then
	echo "[$NAME] - Terminate MATLAB process"
	cl_rpc terminate $MATLABPID
fi

# Unload configuration from nameserver
cl_init -u -B $block
cl_rpc eraseconfig $block subject 
cl_rpc eraseconfig $block logname
killall cl_keepalive
cl_killloop
rm *.log 
exit
exit