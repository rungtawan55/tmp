#!/usr/bin/env bash

ScripDirectory=`/bin/dirname $0`



xYesterday=`date -d "yesterday" '+%Y-%m-%d-'`
xPath="/var/www/blocked-domain/webfintering-uploads"

xFile=`ls -1 ${xPath}/webscreen${xYesterday}*.zip | tail -1`

#xFile="${xPath}/webscreen2026-03-19-12-40.zip"

if [ -n "$xFile" ]
then

#	echo $xFile

	rm -f /tmp/webscreen.sql

	unzip -d /tmp $xFile

	sed -n '/-- Table structure for table `previewurllist`/,/UNLOCK TABLES;/p' /tmp/webscreen.sql > /tmp/previewurllist.sql
	/usr/bin/mysql -u admin -p"P@ssword" TIG_WEBSCREEN_BLOCKED_WEB < /tmp/previewurllist.sql


	sed -n '/-- Table structure for table `tempurllist`/,/UNLOCK TABLES;/p' /tmp/webscreen.sql > /tmp/tempurllist.sql
	/usr/bin/mysql -u admin -p"P@ssword" TIG_WEBSCREEN_BLOCKED_WEB < /tmp/tempurllist.sql

	sed -n '/-- Table structure for table `urllist`/,/UNLOCK TABLES;/p' /tmp/webscreen.sql > /tmp/urllist.sql
        /usr/bin/mysql -u admin -p"P@ssword" TIG_WEBSCREEN_BLOCKED_WEB < /tmp/urllist.sql

	cd $ScripDirectory

	# Test new URL 
	for xLine in `mysql -u "root" -p"P@ssword" --skip-column-names  TIG_WEBSCREEN_BLOCKED_WEB -e "SELECT id,',',url FROM previewurllist WHERE url NOT IN (SELECT url FROM ti_url_test)" 2>&1 | grep -v  "^mysql: \[Warning\]"  | tr -d '\t'`
	do
        	./one-domain-decheck-url-tig.sh $xLine
       		sleep 1
	done

 # Test new URL
        for xLine in `mysql -u "root" -p"P@ssword" --skip-column-names  TIG_WEBSCREEN_BLOCKED_WEB -e "SELECT id,',',url FROM tempurllist WHERE url NOT IN (SELECT url FROM ti_url_test)" 2>&1 | grep -v  "^mysql: \[Warning\]"  | tr -d '\t'`
        do
                ./one-domain-decheck-url-tig.sh $xLine

                sleep 1

        done
fi
