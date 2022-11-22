#!/bin/sh

export PMD
export NB_FILES
export P1
export P2
export P3
export TOKEN_SUM
export NB_DUPLICATES
export NB_FIELD_NO_DESC


#### PMD & CPD functions ####
function generate_pmd_report(){
	local pmdBin=$1
	local minimumPriority=$2
	local pmdRulesFile=$3

	$pmdBin/run.sh pmd --minimum-priority $minimumPriority -d force-app -R $pmdRulesFile -f xslt -l apex --property xsltFilename=pmd-nicerhtml.xsl > PMDReport.html
}

function generate_cpd_report(){
	local pmdBin=$1
	local minimumToken=$2

	$pmdBin/run.sh cpd --minimum-tokens $minimumToken --files ./force-app/main/default --language apex --format csv_with_linecount_per_file > cpd.csv
}

function export_PMD_variables(){
	STR=$(<PMDReport.html)

	PMD=$(awk -F'START_PMD_VERSION|END_PMD_VERSION' '{print $2}' <<< "$STR" | tr -d '\n')
	NB_FILES=$(awk -F'START_TOTAL_FILES|END_TOTAL_FILES' '{print $2}' <<< "$STR" | tr -d '\n')

	P1=$(awk -F'START_PRIORITY_1|END_PRIORITY_1' '{print $2}' <<< "$STR" | tr -d '\n')
	P2=$(awk -F'START_PRIORITY_2|END_PRIORITY_2' '{print $2}' <<< "$STR" | tr -d '\n')
	P3=$(awk -F'START_PRIORITY_3|END_PRIORITY_3' '{print $2}' <<< "$STR" | tr -d '\n')
}

function export_CPD_variables(){
	#count number of lines excluding the csv header
	NB_DUPLICATES=$(cat cpd.csv | tail +2 | sed -n '$=')
	if [ -z "$NB_DUPLICATES" ]
	then
		NB_DUPLICATES=0
	fi

	#extract and sum first column of csv and exclude the csv header
	TOKEN_SUM=$(cat cpd.csv | tail +2 | awk -F , '{print $1}' | xargs | sed -e 's/\ /+/g' | bc)
	echo $TOKEN_SUM
	if [ -z "$TOKEN_SUM" ]
	then
		TOKEN_SUM=0
	fi
}

function check_analyses(){
	local orgAlias=$1
	local pmdBin=$2

	generate_pmd_report $pmdBin "2" "custom-apex-rules.xml"
	generate_cpd_report $pmdBin "65"

	export_PMD_variables
	export_CPD_variables
	export_nb_fields_no_desc

	local result=$(get_last_code_analysis $orgAlias)
	echo $result

	if [[ $result == "0" ]]; then
			echo "PMD & CPD checks suceedeed"
	fi
}

#### End PMD & CPD functions ####


#### File functions ####

# Replace substring in file
function replace_in_file(){
	local searched=$1
	local replacedBy=$2
	local file=$3

	sed -i '' "s|${searched}|${replacedBy}|g" "$file"
}

# Count number of files which does not contains string($1) in files ($2) in folder ($3)
function count_not_in_files(){
	local searched=$1
	local folder=$2
	local fileName=$3

	if [ -d "$searched $folder" ];
	then
		grep -r -L $searched $folder > $fileName
		echo cat $fileName | sed -n '$='
	else
		echo "0"
	fi
}

#### End File functions ####


#### Sfdx functions ####

# Returns org url
function get_org_url(){
	local orgAlias=$1

	local result=$(sfdx force:org:display --targetusername $orgAlias --json)
	local orgUrl=$(jq -r ".result.instanceUrl" <<< $result)
	echo $orgUrl
}

# Returns record id
function get_record_id(){
	local orgAlias=$1
	local query=$2

	local result=$(sfdx force:data:soql:query --targetusername $orgAlias --query "$query" --json)
	local recordId=$(jq -r ".result.records|map(.Id)|.[]" <<< $result)
	echo $recordId
}

function create_code_analysis(){
	local org_username=$1
	local TODAY=$(date +'%Y-%m-%d')

	echo "NumberOfFiles__c,Version__c,Priority1__c,Priority2__c,Priority3__c,NumberOfDuplicates__c,TokensSum__c,NumberOfFieldNoDesc__c,DeploymentDate__c"  > codeAnalysis.csv
	echo "$NB_FILES, $PMD, $P1, $P2, $P3, $NB_DUPLICATES, $TOKEN_SUM, $NB_FIELD_NO_DESC, $TODAY" >> codeAnalysis.csv

	local cmd=$(sfdx force:data:bulk:upsert --targetusername $org_username -s CodeAnalysis__c -i DeploymentDate__c -f codeAnalysis.csv --json --loglevel TRACE -w 3)
	echo $cmd

	#Delete generated csv
	rm codeAnalysis.csv
}

function get_last_code_analysis(){
	local org_username=$1

	export_PMD_variables

	local result=$(sfdx force:data:soql:query --targetusername $org_username --query "SELECT Priority1__c, Priority2__c, Priority3__c, NumberOfDuplicates__c, TokensSum__c, NumberOfFieldNoDesc__c FROM CodeAnalysis__c ORDER BY CreatedDate DESC LIMIT 1" --json)
	local nbResult=$(jq -r ".result.totalSize" <<< $result)

	if [ "$nbResult" = "0" ]
	then
		echo "No result found, create new CodeAnalysis__c record"
		create_code_analysis $org_username
		exit 0
	else
		LAST_P1=$(jq -r ".result.records|map(.Priority1__c)|.[]" <<< $result)
		LAST_P2=$(jq -r ".result.records|map(.Priority2__c)|.[]" <<< $result)
		LAST_P3=$(jq -r ".result.records|map(.Priority3__c)|.[]" <<< $result)
		LAST_NB_DUP=$(jq -r ".result.records|map(.NumberOfDuplicates__c)|.[]" <<< $result)
		LAST_TOKENS_SUM=$(jq -r ".result.records|map(.TokensSum__c)|.[]" <<< $result)
		LAST_NB_FIELD_NO_DESC=$(jq -r ".result.records|map(.NumberOfFieldNoDesc__c)|.[]" <<< $result)

		if [ "$LAST_P1" -lt "$P1" ] || [ "$LAST_P2" -lt "$P2" ] || [ "$LAST_P3" -lt "$P3" ] || [ "$LAST_NB_DUP" -lt "$NB_DUPLICATES" ]
		then
			echo "ERROR: Technical debt increased (lastp1 "$LAST_P1" new "$P1", lastp2 "$LAST_P2" new "$P2",lastp3 "$LAST_P3" new "$P3", last nb duplicates "$LAST_NB_DUP" new "$NB_DUPLICATES", last nb fields without description "$NB_DUPLICATES" new "$LAST_NB_FIELD_NO_DESC")"
		else
			echo 0
		fi
	fi
}

#### End Sfdx functions ####


#### Metadata functions ####

function update_meta_with_org_values(){
	local orgAlias=$1
	local usernameForReports=$2
	update_help_menu_with_org_values $orgAlias
	update_report_dashboard_with_current_username $orgAlias $usernameForReports
}

function update_report_dashboard_with_current_username(){
	local orgAlias=$1
	local usernameForReports=$2

	echo "Update Report and Dashboard to match with your user"
	replace_in_file "myusername@apex-analysis.com" $usernameForReports "./force-app/main/default/reports/CodeAnalysis.reportFolder-meta.xml"
	replace_in_file "myusername@apex-analysis.com" $usernameForReports "./force-app/main/default/dashboards/CodeAnalysis/uPzNCsbXfPrMAjnJxBjpTKvGRODlGf1.dashboard-meta.xml"
	replace_in_file "myusername@apex-analysis.com" $usernameForReports "./force-app/main/default/dashboards/CodeAnalysis.dashboardFolder-meta.xml"
}

# Replace variables in CustomHelpMenuSection with org's values
function update_help_menu_with_org_values(){
	local orgAlias=$1
	local file="./force-app/main/default/customHelpMenuSections/CustomHelpMenuSection.customHelpMenuSection-meta.xml"

	cp ./metadata/CustomHelpMenuSection.customHelpMenuSection-meta.xml $file

	echo "Deploying 'PMDReport' StaticResource"
	sfdx force:source:deploy -p ./force-app/main/default/staticresources

	echo "Replacing values in CustomHelpMenuSection"
	local recordId=$(get_record_id $orgAlias "SELECT Id FROM StaticResource WHERE Name='PMDReport' LIMIT 1")
	replace_in_file "::STATIC_RESOURCE_ID::" $recordId $file

	local orgUrl=$(get_org_url $orgAlias)
	replace_in_file "::ORG_URL::" $orgUrl $file

	echo "End of replacement"
}

# Count number of fields without description
function export_nb_fields_no_desc(){
	NB_FIELD_NO_DESC=$(count_not_in_files "<description>" "./force-app/main/default/objects/*/fields/" "fieldsWithoutDescription.txt")
	echo $NB_FIELD_NO_DESC
}

#### End Update metadata functions ####
