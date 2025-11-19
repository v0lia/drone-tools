#!/usr/bin/env bash

: "${TESTING:=0}"	# only sourcable for testing
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ "$TESTING" -ne 1 ]]; then
    echo -e "Do not source this script. Run it:\n    ${BASH_SOURCE[0]}"
    return 1
fi

# Strict mode: fail on exception, unknown var, wrong pipe
set -eu -o pipefail

# CHANGABLE VARIABLES
MIN_SPACE_MB=100		# Minimum free disk space to start
LOGS_BASE_DIR="$HOME/logs"	# Where logs will be created
TMP_FILE_READ="/tmp/log_folder_path"
TMP_FILE_SOURCE="/tmp/log_folder_path.env"
DEFAULT_LOG_NAME="log"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_NAME=${1:-"$DEFAULT_LOG_NAME"}

# Checking permissions
check_permissions() {
	if [[ -d "$LOGS_BASE_DIR" ]]; then
		if ! [[ -r "$LOGS_BASE_DIR" && -w "$LOGS_BASE_DIR" && -x "$LOGS_BASE_DIR" ]]; then
			echo "Permission denied to $LOGS_BASE_DIR"
			return 1
		fi
	fi
	if [[ -e "$TMP_FILE_READ" ]]; then
		if ! [[ -r "$TMP_FILE_READ" && -w "$TMP_FILE_READ" ]]; then
			echo "Permission denied to $TMP_FILE_READ"
			return 1
		fi
	fi
	if [[ -e "$TMP_FILE_SOURCE" ]]; then
		if ! [[ -r "$TMP_FILE_SOURCE" && -w "$TMP_FILE_SOURCE" ]]; then
			echo "Permission denied to $TMP_FILE_SOURCE"
			return 1
		fi
	fi
	return 0
}

# Checking disk space
check_disk_space() {
	echo "Checking disk space..."
	FREE_SPACE_KB=$(df --output=avail "$LOGS_BASE_DIR" | tail -1)
	FREE_SPACE_MB=$((FREE_SPACE_KB / 1024))
	if [[ $FREE_SPACE_MB -lt $MIN_SPACE_MB ]]; then
		echo "ERROR: Not enough disk space!"
		echo "Only ${FREE_SPACE_MB} MB available, but minimum ${MIN_SPACE_MB} MB required. Aborting."
		return 1
	else
		echo "OK. ${FREE_SPACE_MB} MB available (minimum ${MIN_SPACE_MB} MB required)."
		return 0
	fi
}


# Calculating new index...
calculate_new_index() {
	max_index=-1

	# making items array null if /logs folder is empty to skip the cycle
	shopt -s nullglob
	items=("$LOGS_BASE_DIR"/*)	#array
	shopt -u nullglob
	for item in "${items[@]}"; do
		# skip if item is NOT a directory
		[[ -d "$item" ]] || continue

		# Getting <log_index> from item name
		folder_basename=$(basename "$item")
		if [[ "$folder_basename" =~ ^([0-9]+)_ ]] && \
					((10#${BASH_REMATCH[1]} > max_index)); then
			max_index=$((10#${BASH_REMATCH[1]}))
		fi
	done
	NEW_INDEX=$(printf "%05d" "$((max_index+1))")
}


secure_logname() {
	# Making LOG_NAME safe
	LOG_NAME="${LOG_NAME//[^a-zA-Z0-9_-]/}"

	if [[ -z "$LOG_NAME" ]]; then
		LOG_NAME="$DEFAULT_LOG_NAME"
	fi

	# Making LOG_NAME not too long
	max_basename_length=255
	max_logname_length=$((max_basename_length - ${#NEW_INDEX} - ${#TIMESTAMP} - 2))
	if (( ${#LOG_NAME} > max_logname_length )); then
		LOG_NAME="${LOG_NAME:0:max_logname_length}"
	fi
}

main () {
	if ! check_permissions; then
		echo "Aborting: permission denied."
		return 1
	fi

	# Creating "logs/" folder
		#shellcheck disable=SC2174
	mkdir -p -m 700 "$LOGS_BASE_DIR" || { echo "Failed to create /logs folder"; return 1; }

	if ! check_disk_space; then
		echo "Aborting: not enough disk space"
		return 1
	fi

	calculate_new_index
	secure_logname

	# Creating log folder
	FOLDER_NAME="${NEW_INDEX}_${TIMESTAMP}_${LOG_NAME}"
	FULL_LOG_FOLDER="${LOGS_BASE_DIR}/${FOLDER_NAME}"
		#shellcheck disable=SC2174
	mkdir -p -m 700 "$FULL_LOG_FOLDER" || { echo "Failed to create log folder"; return 1; }
	echo "Created log folder: $FULL_LOG_FOLDER"

	# Saving path to created folder to two /tmp files
	echo "$FULL_LOG_FOLDER" > "$TMP_FILE_READ"
	chmod 600 "$TMP_FILE_READ"
	echo "export LOG_FOLDER_PATH=\"$FULL_LOG_FOLDER\"" > "$TMP_FILE_SOURCE"
	chmod 600 "$TMP_FILE_SOURCE"

	echo -e "Path to the created folder was saved.\nTo read the path, do either:"
		#shellcheck disable=SC2016
	echo '    LOG_FOLDER_PATH=$(< /tmp/log_folder_path)'
	echo "or"
	echo '    source /tmp/log_folder_path.env'

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
# ${BASH_SOURCE[0]} is path to & name of currently running script
# ${0} is name of procced being currently executed
