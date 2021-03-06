#!/bin/sh

function get_ap_results {
  #IFS (internal field separator) is reset
  IFS=
  declare -a urls=('http://api.ap.org/v2/elections/2012-11-06?apiKey='$AP_API_KEY'&statePostal=CA&officeID=P&format=json' 'http://api.ap.org/v2/elections/2012-11-06?apiKey='$AP_API_KEY'&statePostal=CA&officeID=Z&seatNum=3,9,11,15&format=json' 'http://api.ap.org/v2/elections/2012-11-06?apiKey='$AP_API_KEY'&statePostal=CA&officeID=Y&seatNum=4,14,16,24,27&format=json' 'http://api.ap.org/v2/elections/2012-11-06?apiKey='$AP_API_KEY'&statePostal=CA&officeID=H&seatNum=17&format=json')
  for url in "${urls[@]}"
    do
      #Make GET request to AP API and use jq to format into object
      results=$(curl $url | jq -r ' .races[] | {officeName, seatName} + (.reportingUnits[] | {lastUpdated, precinctsReportingPct} + (.candidates[] | {first, last, voteCount, winner}))')
      #Use jq to replace null values with "null" and transform object into list of values separated by commas
      formatted=`echo $results | jq 'if .seatName == null then .seatName="null" else . end' | jq 'if .winner == null then .winner="null" else . end' | jq -r 'map(.) | @csv'`
      #IFS set for to separate on newline 
      IFS=$'\n'

      for line in $formatted
        do
          #Create SQL insert query with data received from AP API
          query=`echo 'INSERT INTO APresults (officename, seatname, lastupdated, precincts, firstname, lastname, votecount, winner) VALUES ('$line');'`
          echo $query | $MYSQL_COMMAND -h $ELECTIONS_DB_HOST --port=$ELECTIONS_DB_PORT --user=$ELECTIONS_DB_USER --password=$ELECTIONS_DB_PASS election2016
      done
  done
}

get_ap_results

function get_sos_results {
  candidatescount=$(xmllint --xpath "count(.//TotalVotes/*[self::Selection])" race.xml)
  seatname=$(xmllint --xpath "string(//Contest/ContestIdentifier/ContestName)" race.xml)
  lastupdated=$(xmllint --xpath "string(//IssueDate)" race.xml)
  precinctsreporting=$(xmllint --xpath "//TotalVotes/CountMetric[@Id='PR']/text()" race.xml)
  totalprecincts=$(xmllint --xpath "//TotalVotes/CountMetric[@Id='TP']/text()" race.xml)

  for (( i=1; i <= $candidatescount; i++ )); do 
    name=$(xmllint --xpath ".//TotalVotes/Selection[position()=$i]/Candidate/CandidateFullName/PersonFullName/text()" race.xml)
    affiliation=$(xmllint --xpath ".//TotalVotes/Selection[position()=$i]/AffiliationIdentifier/RegisteredName/text()" race.xml)
    votecount=$(xmllint --xpath ".//TotalVotes/Selection[position()=$i]/ValidVotes/text()" race.xml)
    percentvotes=$(xmllint --xpath ".//TotalVotes/Selection[position()=$i]/CountMetric/text()" race.xml)

    query=`echo "INSERT INTO SOSresults (seatname, lastupdated, precinctsreporting, totalprecincts, name, affiliation, votecount, percentvotes) VALUES ('$seatname','$lastupdated',$precinctsreporting,$totalprecincts,'$name','$affiliation',$votecount,$percentvotes);"`
    echo $query
    echo $query | $MYSQL_COMMAND -h $ELECTIONS_DB_HOST --port=$ELECTIONS_DB_PORT --user=$ELECTIONS_DB_USER --password=$ELECTIONS_DB_PASS election2016
  done
}

get_sos_results
