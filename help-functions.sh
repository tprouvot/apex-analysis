#!/bin/sh

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
	local orgUrl=$(get_org_url $1)
	replace_in_file "::ORG_URL::" $orgUrl $file

	local recordId=$(get_record_id $1 "SELECT Id FROM Account WHERE Name='PMDReport' LIMIT 1")
	replace_in_file "::STATIC_RESOURCE_ID::" $recordId $file

	echo "End of replacement"
}

update_help_menu_with_org_values "test-5bfcvse4x0h5@example.com"