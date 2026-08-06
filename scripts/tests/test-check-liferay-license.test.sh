#!/bin/bash

load helpers/setup

_test_check_for_liferay_license() {
	local liferayWorkspaceProduct=${1}

	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "liferay.workspace.product" "${liferayWorkspaceProduct}"

	rm -f configs/common/osgi/modules/*.xml

	run ./gradlew checkForLiferayLicense

	assert_success
}

_assert_attempt_copy_license_from_image() {
	local tags=("${@}")

	for tag in "${tags[@]}"; do
		assert_line "Attempting to copy trial license from liferay/dxp:${tag}"
	done
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Check Liferay license for DXP version: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	local dxpDockerImages=()
	local dxpDockerImage

	while IFS= read -r dxpDockerImage; do
		dxpDockerImages+=("${dxpDockerImage}")
	done < <(docker image ls --filter reference="liferay/dxp" --format "{{.Repository}}:{{.Tag}}")

	if [[ ${#dxpDockerImages[@]} -gt 0 ]]; then
		docker rmi "${dxpDockerImages[@]}"
	fi

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"
}

teardown() {
	common_teardown
}

@test "2026.Q1.6 LTS" {
	_test_check_for_liferay_license "dxp-2026.q1.6-lts"

	_assert_attempt_copy_license_from_image "2026.q1.6-lts" "latest"
}

@test "2026.Q2.0" {
	_test_check_for_liferay_license "dxp-2026.q2.0"

	_assert_attempt_copy_license_from_image "2026.q2.0"

	refute_line "Attempting to copy trial license from liferay/dxp:latest"
}