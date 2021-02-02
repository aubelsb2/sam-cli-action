#!/bin/bash

set -u

function parseInputs(){
	# Required inputs
	if [ "${INPUT_SAM_COMMAND}" == "" ]; then
		echo "Input sam_subcommand cannot be empty"
		exit 1
	fi
}

function installAwsSam(){
	echo "Install aws-sam-cli ${INPUT_SAM_VERSION}"
	if [ "${INPUT_SAM_VERSION}" == "latest" ]; then
		pip install aws-sam-cli >/dev/null 2>&1
		if [ "${?}" -ne 0 ]; then
			echo "Failed to install aws-sam-cli ${INPUT_SAM_VERSION}"
		else
			echo "Successful install aws-sam-cli ${INPUT_SAM_VERSION}"
		fi
	else
		pip install aws-sam-cli==${INPUT_SAM_VERSION} >/dev/null 2>&1
		if [ "${?}" -ne 0 ]; then
			echo "Failed to install aws-sam-cli ${INPUT_SAM_VERSION}"
		else
			echo "Successful install aws-sam-cli ${INPUT_SAM_VERSION}"
		fi
	fi
}

function runSam(){
	if [ -f "${GITHUB_WORKSPACE}/.npmrc" ]; then
	    echo "Copying in workspace .npmrc file ignoring package registry token input"
		cp -v "${GITHUB_WORKSPACE}/.npmrc" ~/.npmrc
	elif [ "x${INPUT_GITHUB_PACKAGE_REGISTRY_TOKEN}" != "x" ]; then
	    echo "Creating .npmrc with GITHUB_PACKAGE_REGISTRY_TOKEN"
		echo "//npm.pkg.github.com/:_authToken=${INPUT_GITHUB_PACKAGE_REGISTRY_TOKEN}" > ~/.npmrc
	fi

	echo "Run sam ${INPUT_SAM_COMMAND}"
	output=$(sam ${INPUT_SAM_COMMAND} 2>&1)
	exitCode=${?}
	echo "${output}"

	commentStatus="Failed"
	if [ "${exitCode}" == "0" ]; then
		commentStatus="Success"
	fi

	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${INPUT_ACTIONS_COMMENT}" == "true" ]; then
		commentWrapper="#### \`sam ${INPUT_SAM_COMMAND}\` ${commentStatus}
<details><summary>Show Output</summary>

\`\`\`
${output}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`*"

		payload=$(echo "${commentWrapper}" | jq -R --slurp '{body: .}')
		commentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)

		echo "${payload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${commentsURL}" > /dev/null
	fi

	if [ "${exitCode}" == "1" ]; then
		if [ "${INPUT_FAIL_COMMAND}" != "" ]; then 
			echo "Executing fail command; ${INPUT_FAIL_COMMAND@Q}";
			eval "${INPUT_FAIL_COMMAND}";
		fi
		exit 1
	fi
}

function gotoDirectory(){
	if [ -z "${INPUT_DIRECTORY}" ]; then
		return 1
	fi

	if [ ! -d "${INPUT_DIRECTORY}" ]; then
		echo "Directory ${INPUT_DIRECTORY} does not exists."
		exit 127
	fi

	echo "cd ${INPUT_DIRECTORY}"
	cd $INPUT_DIRECTORY
}

function setupEnv() {
  mkdir -p ~/.ssh
	ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
}

function main(){
	parseInputs
	setupEnv
	installAwsSam
	gotoDirectory
	runSam
}

main
