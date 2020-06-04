#!/bin/sh

HIBERNATE_DATE_FILE=/tmp/hibernate_timestamp
SESSIONS_IDS_FILE=/tmp/sessions

function hibernate_date () {
	SLEEP_CONF_FILES="$(find /{usr/lib,etc,run}/systemd/sleep.conf.d -name "*.conf") \
		/etc/systemd/sleep.conf"
	HibernateDelaySec=$(grep -hs ^HibernateDelaySec $SLEEP_CONF_FILES | tail -n 1 | cut -d '=' -f 2)
	HibernateDelaySec=${HibernateDelaySec:-$(grep \#HibernateDelaySec /etc/systemd/sleep.conf | tail -n 1 | cut -d '=' -f 2)}

	HibernateDate=$(date -d "+$HibernateDelaySec" +%s)
	echo $HibernateDate
}

function is_lockable () {
	session_type=$(loginctl show-session $1 -p Type --value)
	[ $session_type = "wayland" -o "$session_type" = "x11" ]
	return $?
}

function is_not_lockable () {
	! is_lockable $1
	return $?
}

function list_sessions () {
	loginctl list-sessions --output json | jq -r ".[].session"
}

function filter () {
	list=()
	for i in $1
	do
		if $2 $i
		then
			list+=($i)
		fi
	done

	echo $list
}

CMD=echo


######## Script

case $1/$2 in
	suspend-then-hibernate/lock)
		(umask 077; touch $HIBERNATE_TIMESTAMP $SESSIONS_IDS_FILE)
		hibernate_date > "$HIBERNATE_DATE_FILE"
		session_ids=$(list_sessions)
		lockable_sessions=$(filter "$session_ids" is_lockable)
		echo "$lockable_sessions" > "$SESSIONS_IDS_FILE"
		$CMD lock-session $lockable_sessions
		$CMD kill-session $(filter "$session_ids" is_not_lockable)
		;;
	suspend-then-hibernate/unlock)
		if (( $(date +%s) > $(< $HIBERNATE_DATE_FILE) ))
		then
			$CMD unlock $(< $SESSIONS_IDS_FILE )
		fi
		rm $HIBERNATE_TIMESTAMP $SESSIONS_IDS_FILE
		;;
	*)
		session_ids=$(list_sessions)
		lockable_sessions=$(filter "$session_ids" is_lockable)
		$CMD lock-session $lockable_sessions
		$CMD kill-session $(filter "$session_ids" is_not_lockable)
		;;
esac
