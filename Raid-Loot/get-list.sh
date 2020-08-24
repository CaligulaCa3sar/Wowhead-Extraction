#!/bin/bash
#
# Extracts the data for loot drops in the raid at the specified URL.
# Data is compiled in a semi-colon-separated format for easy importing into
# spreadsheets.
#
# Calls the external Python script get-html-element.py

# GLOBAL VARIABLES
DATESTAMP="$(date +%Y-%m-%d-%H%M%S)"
URL="${1}"
TRIMMEDURL="${URL##*/}"      # Greedily trim everything from front (##) matching any character (*) until last occurring "/"
RAIDNAME="$(awk -v myString=${TRIMMEDURL} -e 'BEGIN { gsub(/-loot.+$/, "", myString); print myString }')"
TEMPFILE="${TRIMMEDURL}-${DATESTAMP}"
TEMPTRIMFILE="${TEMPFILE}-trimmed"
TEMPAWKFILE="${TEMPFILE}-awk"
PYSCRIPT="get-html-element.py"

# FUNCTIONS

# Extract additional information from the specific item page:
function getItemDetails()
{
        local ITEMURL ITEMXML
        ITEMURL="https://classic.wowhead.com/item=${1}&xml"
        ITEMXML=$(curl -s "${ITEMURL}")
        ITEMQUALITY=$(echo "${ITEMXML}" | xmlstarlet sel -t -v '//quality' -n)
        ITEMICON=$(echo "${ITEMXML}" | xmlstarlet sel -t -v '//icon' -n)
        echo "${ITEMQUALITY}" "${ITEMICON}"
}

# SCRIPT

# Retrieve the page with cURL and output to $TEMPFILE:
curl -o "${TEMPFILE}" "${URL}"

# Extract desired element from $TEMPFILE using Python and BeautifulSoup4 and save output to $TEMPTRIMFILE:
python3 "${PYSCRIPT}" "${TEMPFILE}" > "${TEMPTRIMFILE}"

# Extract loot source headers and item hyperlinks from $TEMPTRIMFILE and write back into $TEMPFILE:
grep -o -E "<h3 class=\"heading-size-3\">([a-zA-Z ,']+)<\/h3>\
|<h2 class=\"heading-size-2\">([a-zA-Z ,']+) Trash Loot<\/h2>\
|<a href=\"\/item=[0-9]+\">([a-zA-Z ,':-]+)<\/a>" "${TEMPTRIMFILE}" | sed -n -e '/<h3 /,$p' > "${TEMPFILE}"

# Rewrite each line to strip out the HTML and format the info:
awk -F [\>\<=\"] -e '/\<h3|\<h2/ { gsub(/Classic | Loot/, ""); print $6 }' \
	-e '/\<a/ { formattedName = tolower($7); \
		formattedName = gensub(/ /, "-", "g", formattedName); \
		formattedName = gensub(/[,\047:]/, "", "g", formattedName); \
		formattedName = gensub(/-{3}/, "-", "g", formattedName); \
		print $5 ";" $7 ";https://classic.wowhead.com/item=" $5 "/" formattedName }' "${TEMPFILE}" > "${TEMPAWKFILE}"

# Split $TEMPAWKFILE into separate files for each boss:
awk -v i=0 -e '{ if (!/;/) i++; print $0 >> "Boss"i }' "${TEMPAWKFILE}"

#Get each item's quality level and icon name:
for i in Boss*
do
	while read l
	do
		#Check this is a delimited line of item data:
		if [[ "${l}" =~ .*";".* ]];
		then
			ITEMID=$(awk -F ";" -e '{ print $1 }' <<< "${l}")
			echo "${ITEMID}"

			read ITEMQUALITY ITEMICON < <(getItemDetails "${ITEMID}")

			echo ";${ITEMQUALITY};${ITEMICON}" >> "${i}-2"
		else
			# Blank line to match where the boss name appears in the first file:
			echo "" >> "${i}-2"
		fi
	done <${i}

	# Paste the two Boss files together and tidy up:
	paste -d'\0' "${i}" "${i}-2" > "${i}.csv"
	rm "${i}" "${i}-2"
done

# Create directory for the "Boss*.csv" files and move them in:
mkdir "${RAIDNAME}"
mv ./Boss*.csv "${RAIDNAME}"/

# Tidy up:
rm "${TEMPFILE}" "${TEMPTRIMFILE}" "${TEMPAWKFILE}"
