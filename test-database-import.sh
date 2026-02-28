#!/bin/bash

_clean_dumps_dir() {
	local dumpsFiles=($(ls dumps))

	if (( ${#dumpsFiles[@]} > 0 )); then
		for dumpsFile in ${dumpsFiles[@]}; do
			rm dumps/${dumpsFile}
		done
	fi
}

_download_database_dumps() {
	local urls=($(curl -s https://storage.googleapis.com/storage/v1/b/liferay-devtools/o?prefix=liferay-environment-composer/test-resources/database-support-tests | jq -r '.items[] | select(.name | contains(".")) | .mediaLink'))

	local baseUrl="https://storage.googleapis.com/download/storage/v1/b/liferay-devtools/o/liferay-environment-composer%2Ftest-resources%2Fdatabase-support-tests%2F"

	for url in ${urls[@]}; do
		local filepathUrl=$(echo ${url//${baseUrl}/} | sed -e 's@%2F@/@g' -e 's@?.*@@g')

		curl -s -o testDependencies/${filepathUrl//${baseUrl}/} ${url} --create-dirs
	done
}

_stop_composer() {
	local databaseType=${1}

	./gradlew stop -Plr.docker.environment.clear.volume.data=true -Plr.docker.environment.service.enabled[liferay]=false -Plr.docker.environment.service.enabled[${databaseType}]=true &> /dev/null
}

_test_import_dump() {
	local inputFilepath=${1}

	local filepaths=($(ls ./testDependencies/${inputFilepath}))

	local filepath

	 for filepath in ${filepaths[@]}; do
		echo "Testing ${filepath}..."

		local IFS="/" && read -r fileType databaseType file <<< ${filepath//*testDependencies\//}

		cp "testDependencies/${fileType}/${databaseType}/${file}" "dumps/${file}"

		./gradlew clean start -Plr.docker.environment.service.enabled[liferay]=false -Plr.docker.environment.service.enabled[${databaseType}]=true -Plr.docker.environment.lxc.backup.password=12345 &> /dev/null

		local status=$?

		if [[ ${status} != 0 ]]; then
			echo "[FAILED]"

			_stop_composer ${databaseType}

			_clean_dumps_dir

			continue
		fi

		local sqlQueryOutput=$(./gradlew executeSQLQuery -Plr.docker.environment.service.enabled[${databaseType}]=true -PsqlQuery="select urlTitle from JournalArticle;")

		if [[ ${sqlQueryOutput} =~ "test-web-content-title" ]]; then
			echo "[PASSED]"
		else
			echo "[FAILED]"
		fi

		_stop_composer ${databaseType}

		_clean_dumps_dir
	done
}

${@}