#!/bin/sh

export PMD
export NB_FILES
export P1
export P2
export P3
export LAST_P1
export LAST_P2
export LAST_P3

function export_PMD_variables(){
	STR=$(<PMDReport.html)

	PMD=$(awk -F'START_PMD_VERSION|END_PMD_VERSION' '{print $2}' <<< "$STR")
	NB_FILES=$(awk -F'START_TOTAL_FILES|END_TOTAL_FILES' '{print $2}' <<< "$STR")
	P1=$(awk -F'START_PRIORITY_1|END_PRIORITY_1' '{print $2}' <<< "$STR")
	P2=$(awk -F'START_PRIORITY_2|END_PRIORITY_2' '{print $2}' <<< "$STR")
	P3=$(awk -F'START_PRIORITY_3|END_PRIORITY_3' '{print $2}' <<< "$STR")
}

function create_code_analysis(){
	local org_username=$1

	local cmd=$(sfdx force:data:record:create --targetusername $org_username -s CodeAnalysis__c -v "NumberOfFiles__c='$NB_FILES' Version__c='$PMD' Priority1__c='$P1' Priority2__c='$P2' Priority3__c='$P3'" --json --loglevel TRACE)
	echo $cmd
	local status=$(jq '.status' <<< $cmd)
	echo $status
}

function get_last_code_analysis(){
	local org_username=$1

	local result=$(sfdx force:data:soql:query --targetusername $org_username --query "SELECT Priority1__c, Priority2__c, Priority3__c FROM CodeAnalysis__c ORDER BY CreatedDate DESC LIMIT 1" --json)
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

		if [ $LAST_P1 < $P1 ] || [ $LAST_P2 < $P2 ] || [ $LAST_P3 < $P3 ]
		then
			echo "Number of errors increased : lastp1 "$LAST_P1" current "$P1", lastp2 "$LAST_P2" current "$P2",lastp3 "$LAST_P3" current "$P3
			exit 1
		fi
	fi
}

# Replace substring in file
function replace_in_file(){
	local searched=$1
	local replacedBy=$2
	local file=$3

	sed -i '' "s|${searched}|${replacedBy}|g" "$file"
}

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

# Replace variables in CustomHelpMenuSection with org's values
function update_help_menu_with_org_values(){
	local orgAlias=$1
	local file="./force-app/main/default/customHelpMenuSections/CustomHelpMenuSection.customHelpMenuSection-meta.xml"

	echo "Replacing values in CustomHelpMenuSection"
	local recordId=$(get_record_id $orgAlias "SELECT Id FROM StaticResource WHERE Name='PMDReport' LIMIT 1")
	replace_in_file "::STATIC_RESOURCE_ID::" $recordId $file

	local orgUrl=$(get_org_url $orgAlias)
	replace_in_file "::ORG_URL::" $orgUrl $file

	echo "End of replacement"
}

function generate_pmd_report(){
	local pmdBin=$1
	local minimumPriority=$2
	local pmdRulesFile=$3

	$pmdBin/run.sh pmd --minimum-priority $minimumPriority -d force-app -R $pmdRulesFile -f xslt -l apex -property xsltFilename=pmd-nicerhtml.xsl > PMDReport.html
}

