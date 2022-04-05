#!/bin/bash

groupID=""
groupName=""

apiUser=""
apiPass=""
jssURL=""
jssComputerGroupsURL="${jssURL}/JSSResource/computergroups"
userNames=".csv"

xmlOutputFile=".xml"
totalEntries=$(wc -l < $userNames)
totalEntries="$(echo -e "${totalEntries}" | tr -d '[:space:]')"

#curl -sku "${apiUser}":"${apiPass}" "${jssComputerGroupsURL}/id/${groupID}" -X GET -H "accept: text/xml" | xmllint --format -



echo '<?xml version="1.0" encoding="UTF-8"?>
<computer_group>
	<name>'$groupName'</name>
	<is_smart>true</is_smart>
	<site>
		<id>-1</id>
		<name>None</name>
	</site>
	<criteria>
		<size>'$totalEntries'</size>' > $xmlOutputFile

prioNum=0
while read -r name; do
	name="$(echo -e "${name}" | tr -d '[:space:]')"
	#echo "Found $name"
	echo '		<criterion>
			<name>Username</name>
			<priority>'$prioNum'</priority>
			<and_or>or</and_or>
			<search_type>is</search_type>
			<value>'$name'</value>
			<opening_paren>false</opening_paren>
			<closing_paren>false</closing_paren>
		</criterion>' >> $xmlOutputFile
	((prioNum+=1))
done < "$userNames"

		

echo '	</criteria>
</computer_group>' >> $xmlOutputFile

set -x

curl -skfu "${apiUser}":"${apiPass}" "${jssComputerGroupsURL}"/id/"${groupID}" -T "$xmlOutputFile" -X POST;
