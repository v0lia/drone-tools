#!/usr/bin/env bats

setup() {
	export TESTING=1
	source create_log_folder.sh
	
	TEST_DIR=$(mktemp -d)

	LOGS_BASE_DIR="$TEST_DIR/logs"
	TMP_FILE_READ="$TEST_DIR/folder_log_path"
	TMP_FILE_SOURCE="$TEST_DIR/folder_log_path.env"
    
	export LOGS_BASE_DIR
	export TMP_FILE_READ
	export TMP_FILE_SOURCE
	
	mkdir -p -m 700 "$LOGS_BASE_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "01. check_permissions - OK" {
	touch "$TMP_FILE_READ"
	touch "$TMP_FILE_SOURCE"
	chmod 600 "$TMP_FILE_READ"
	chmod 600 "$TMP_FILE_SOURCE"

	run check_permissions
	[ "$status" -eq 0 ]
}

@test "02. check_permissions - denied" {
    chmod 000 "$LOGS_BASE_DIR"
    run check_permissions
    [ "$status" -eq 1 ]
    chmod 700 "$LOGS_BASE_DIR"	# for teardown
}

@test "03. check_disk_space - OK" {
	export MIN_SPACE_MB=1
    run check_disk_space
    [ "$status" -eq 0 ]
}

@test "04. check_disk_space - not enough" {
    export MIN_SPACE_MB=$((1024*1024*1024*1024))	# should be enough ;) I do not mock df to check its presence
    run check_disk_space
    [ "$status" -eq 1 ]
}

@test "05. calculate_new_index returns index 0 when no folders exist" {
    calculate_new_index
    [ $((10#$NEW_INDEX)) -eq 0 ]
}

@test "06. calculate_new_index returns next index" {
    mkdir -p "$LOGS_BASE_DIR/00000_2025-12-31_23-59-50_test"
    mkdir -p "$LOGS_BASE_DIR/00001_2025-12-31_23-59-51_test"
	# ... # missing indexed do not matter; only max index matters
    mkdir -p "$LOGS_BASE_DIR/00008_2025-12-31_23-59-58_test"
	
    calculate_new_index
    [ $((10#$NEW_INDEX)) -eq 9 ]
}

@test "07. secure_logname removes invalid chars & uses default if empty" {
    LOG_NAME='!@#$%^&*()'
    NEW_INDEX="00000"
    secure_logname
    [ "$LOG_NAME" = "$DEFAULT_LOG_NAME" ]
}

@test "08. secure_logname truncates if too long" {
    LOG_NAME=$(head -c 300 < /dev/zero | tr '\0' 'a')
    NEW_INDEX="00000"
    secure_logname
    max_basename_length=255
    max_logname_length=$((max_basename_length - ${#NEW_INDEX} - ${#TIMESTAMP} - 2))
    [ "${#LOG_NAME}" -le "$max_logname_length" ]
}

@test "09. main aborts when check_permissions fails" {
    chmod 000 "$LOGS_BASE_DIR"
    run main
    [ "$status" -eq 1 ]
    chmod 700 "$LOGS_BASE_DIR"
}

@test "10. main aborts when check_disk_space fails" {
    export MIN_SPACE_MB=$((1024*1024*1024))
    run main
    [ "$status" -eq 1 ]
}

@test "11. main integrational success test" {
    export MIN_SPACE_MB=1
    mkdir -p "$LOGS_BASE_DIR/00000_2025-12-31_23-59-58_test"
    mkdir -p "$LOGS_BASE_DIR/00001_2025-12-31_23-59-59_test"
    LOG_NAME='a!@#$%b^&*()c'
    run main
	
	FULL_LOG_FOLDER=$(< "$TMP_FILE_READ")
	
    [ "$status" -eq 0 ]

    [ -d "$FULL_LOG_FOLDER" ]
    [ "$(stat -c "%a" "$FULL_LOG_FOLDER")" -eq 700 ]
	[[ "$FULL_LOG_FOLDER" =~ 00002_ ]]
    [[ "$FULL_LOG_FOLDER" =~ abc ]]

    [ -f "$TMP_FILE_READ" ]
	[ "$(stat -c "%a" "$TMP_FILE_READ")" -eq 600 ]
    [ -f "$TMP_FILE_SOURCE" ]
    [ "$(stat -c "%a" "$TMP_FILE_SOURCE")" -eq 600 ]
	
    READ_CONTENT=$(< "$TMP_FILE_READ")
    SOURCE_CONTENT=$(< "$TMP_FILE_SOURCE")

    [ "$READ_CONTENT" = "$FULL_LOG_FOLDER" ]
    [[ "$SOURCE_CONTENT" =~ "$FULL_LOG_FOLDER" ]]
}
