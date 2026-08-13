#!/bin/bash

load helpers/setup

_test_check_for_liferay_license() {
	local liferayWorkspaceProduct=${1}
	local liferayLicenseCheckImagesProperty=${2}

	_debug "RUNNING ${BATS_TEST_NAME}"

	_writeProperty "liferay.workspace.product" "${liferayWorkspaceProduct}"

	rm -f configs/common/osgi/modules/*.xml

	run ./gradlew checkForLiferayLicense "${liferayLicenseCheckImagesProperty}"

	assert_success
}

_assert_attempt_copy_license_from_image() {
	local tags=("${@}")

	for tag in "${tags[@]}"; do
		assert_line "Attempting to copy trial license from liferay/dxp:${tag}"
	done
}

_getLatestTargetPlatformVersion() {
	local year

	year="$(date +%Y)"

	_lec fn _showReleasesJsonFile | jq --arg year "$year" -r '.[] | select(.productGroupVersion | startswith($year)) | .targetPlatformVersion' | sort -V | tail -n 1
}

setup_file() {
	BATS_TEST_NAME_PREFIX="Check Liferay license for DXP version: "
	export BATS_TEST_NAME_PREFIX

	common_setup_file
}

setup() {
	common_setup

	_writeProperty "lr.docker.environment.service.enabled[liferay]" "true"
}

teardown() {
	common_teardown
}

@test "2026.Q1.6 LTS" {
	local targetPlatformVersion="2026.q1.6-lts"

	_test_check_for_liferay_license "dxp-2026.q1.6-lts" "-Pliferay.license.check.images=liferay/dxp:${targetPlatformVersion},liferay/dxp:latest"

	_assert_attempt_copy_license_from_image "${targetPlatformVersion}" "latest"
}

@test "Latest Quarterly Release" {
	local latestTargetPlatformVersion
	latestTargetPlatformVersion="$(_getLatestTargetPlatformVersion)"

	local latestReleaseKey
	latestReleaseKey="$(_lec fn _listReleases | grep "${latestTargetPlatformVersion}")"

	_test_check_for_liferay_license "${latestReleaseKey}" "-Pliferay.license.check.images=liferay/dxp:${latestTargetPlatformVersion}"

	_assert_attempt_copy_license_from_image "${latestTargetPlatformVersion}"

	refute_line "Attempting to copy trial license from liferay/dxp:latest"
}