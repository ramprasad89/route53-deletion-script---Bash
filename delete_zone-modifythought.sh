#!/bin/bash

a_record()
{
	aws route53 list-resource-record-sets --hosted-zone-id $2 --query "ResourceRecordSets[?Name == '$1.']" --output text > input.txt
    count=0
    k=0
    #while read line
    #do
    	line=`sed -n '1 p' input.txt` 
    	name=`echo $line | awk '{print $1}'`
    	noffields=`echo $line | wc -w`
    	if [ $name == $record ]
    	then
    		if [ $noffields -eq 3 ]
    		then
    			recordname=`echo $line | awk '{print $1}'`
    			recordttl=`echo $line | awk '{print $2}'`
    			recordtype=`echo $line | awk '{print $3}'`
    		else
    			recordname=`echo $line | awk '{print $1}'`
    			recordtype=`echo $line | awk '{print $2}'`
    			line=`sed -n '2 p' input.txt`
    			dnsname=`echo $line | awk '{print $2}'`
    			targethealth=`echo $line | awk '{print $3}' | tr [A-Z] [a-z]`
    			aliashostid=`echo $line | awk '{print $4}'`

    			echo "{" > change-rr-sets.json
                echo "    \"Changes\": [" >> change-rr-sets.json
                echo "        {" >> change-rr-sets.json
                echo "            \"Action\": \"DELETE\"," >> change-rr-sets.json
                echo "            \"ResourceRecordSet\": {" >> change-rr-sets.json
                echo "                \"Name\": \"$recordname\"," >> change-rr-sets.json
                echo "                \"Type\": \"$recordtype\"," >> change-rr-sets.json
                echo "            \"AliasTarget\": {" >> change-rr-sets.json
                echo "                          \"HostedZoneId\": \"$aliashostid\"," >> change-rr-sets.json
                echo "                  \"DNSName\": \"$dnsname\"," >> change-rr-sets.json
                echo "                  \"EvaluateTargetHealth\": $targethealth" >> change-rr-sets.json
                echo "                  }" >> change-rr-sets.json
                echo "            }" >> change-rr-sets.json
                echo "        }" >> change-rr-sets.json
                echo "    ]" >> change-rr-sets.json
                echo "}" >> change-rr-sets.json

	            echo "Deleting Alias: $recordname   300 IN  $recordtype $dnsname    $targethealth   $aliashostid" | tee -a log/$0.log
                aws route53 change-resource-record-sets --hosted-zone-id "$hostid" --change-batch file:///data/home/rpanda/aws/new/change-rr-sets.json
    		fi
    	elif [ $name != ALIASTARGET ]
    	then
    		while read line
    		do
    			name=`echo $line | awk '{print $1}'`
    			if [ $name == RESOURCERECORDS ]
    			then
    				recordvalue=`echo $line | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}'`
    				Arec[$count]=$recordvalue
    				((++count))
    			else
    				((++k))
    				if [ $k -ge 2]
    				then
    					break
    				fi
    			fi
    		done < input.txt
    	fi

    echo "{" > change-rr-sets.json
    echo "    \"Changes\": [" >> change-rr-sets.json
    echo "        {" >> change-rr-sets.json
    echo "            \"Action\": \"DELETE\"," >> change-rr-sets.json
    echo "            \"ResourceRecordSet\": {" >> change-rr-sets.json
    echo "                \"Name\": \"$Aname\"," >> change-rr-sets.json
    echo "                \"Type\": \"$Atype\"," >> change-rr-sets.json
    echo "                \"TTL\": $Attl," >> change-rr-sets.json
    echo "                \"ResourceRecords\": [" >> change-rr-sets.json
    for i in `seq $inc1`
    do
        echo "                    {" >> change-rr-sets.json
        echo "                        \"Value\": \"${Arec[$i]}\"" >> change-rr-sets.json
        echo "          }," >> change-rr-sets.json
    done
    let n="($inc1 * 3) + 9"
    sed -i "$n s/},/}/" change-rr-sets.json
    echo "                ]" >> change-rr-sets.json
    echo "            }" >> change-rr-sets.json
    echo "        }" >> change-rr-sets.json
    echo "    ]" >> change-rr-sets.json
    echo "}" >> change-rr-sets.json

    echo "Deleting record : $Aname  $Attl   IN      $Atype  ${Arec[*]}" | tee -a log/$0.log
    aws route53 change-resource-record-sets --hosted-zone-id $hostid --change-batch file:///data/home/rpanda/aws/new/change-rr-sets.json
	#done < input.txt
}
remove_a_record()
{
	echo "Enter the record name which you would like to delete"
	read record
	domainname=`echo $record | awk -F"." '{print $(NF-1)"."$NF}'`
	hostid=`aws route53 list-hosted-zones --output text | grep $domainname | awk -F"/" '{print $3}' | awk '{print $1}'`
	aws route53 list-resource-record-sets --hosted-zone-id $hostid --query "ResourceRecordSets[?Name == '$record.']" --output text > input.txt
	#count=0
	#while read line
	#do
	#	name=`echo $line | awk '{print $1}'`
	#	if [ $name != RESOURCERECORDS ]
	#	then
	#		((++count))
	#	fi
	#done < input.txt
	line=`aws route53 list-resource-record-sets --hosted-zone-id $hostid --query "ResourceRecordSets[?Name == '$record.']" --output text | sed -n '1 p'`
	noffields=`echo $line | wc -w`
	if [ $noffields -eq 3 ]
	then
		type=`echo $line | awk '{print $3'`
	elif [ $record == $domainname ]
	then
		read -p "As the entered domain is the main domain so enter the recordtype you want to delete" type
	else
		type=`echo $line | awk '{print $2}'`
	fi

	case $type in
		[A|a])
			a_record $record $hostid
			;;
		*)
			echo "Only Deleting A record for now"
			;;
	esac
}

echo "===================="
echo "1. Delete a record"
echo "2. Delete all record"
echo "===================="
echo "Enter your choice"
read choice
case $choice in
	1)
		remove_a_record
		;;
	2) 
		remove_all_records
		;;
	*)
		echo "Are you kidding me? Choose correctly"
		;;
esac