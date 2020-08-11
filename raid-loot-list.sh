#!/bin/bash
#
# Extracts the data for loot drops in the raid at the specified URL
# Calls the external Python script extract-html-element.py

# VARIABLES
DATESTAMP="$(date +%Y-%m-%d-%H%M%S)"
URL="${1}"
TEMPFILE="${URL##*/}-${DATESTAMP}"      # Greedily trim everything from front (##) matching any character (*) until last occurring "/"
TEMPTRIMFILE="${TEMPFILE}-trimmed"
TEMPEGREPSCRIPT="${TEMPFILE}-egrep"
TEMPAWKFILE="${TEMPFILE}-awk"
FINALFILE="${TEMPFILE}-final"
PYTHONSCRIPT="extract-html-element.py"

#Populate egrep file:
echo "<h3 class=\"heading-size-3\">([a-zA-Z ,']+)<\/h3>" > "${TEMPEGREPSCRIPT}"
echo "<h2 class=\"heading-size-2\">([a-zA-Z ,']+) Trash Loot<\/h2>" >> "${TEMPEGREPSCRIPT}"
echo "<a href=\"\/item=[0-9]+\">([a-zA-Z ,']+)<\/a>" >> "${TEMPEGREPSCRIPT}"

# Retrieve the page with cURL and output to $TEMPFILE:
curl -o "${TEMPFILE}" "${URL}"

# Extract desired element from $TEMPFILE using Python and BeautifulSoup4 and save output to $TEMPTRIMFILE:
python3 "${PYTHONSCRIPT}" "${TEMPFILE}" > "${TEMPTRIMFILE}"

# Extract loot source headers and item hyperlinks from $TEMPTRIMFILE and write back into $TEMPFILE:
egrep -o -f "${TEMPEGREPSCRIPT}" "${TEMPTRIMFILE}" | sed -n -e '/<h3 /,$p' > "${TEMPFILE}"

# Rewrite each line to strip out the HTML and format the info:
gawk -F [\>\<=\"] -e '/\<h3|\<h2/ { gsub(/Classic | Loot/, ""); print $6 }; /\<a/ { formattedName = tolower(print $7); print $7 ";https://classic.wowhead.com/item=" $5 "/" $formattedName }' "${TEMPFILE}" > "${TEMPAWKFILE}"

# Tidy up:
rm "${TEMPFILE}" "${TEMPTRIMFILE}" "${TEMPEGREPSCRIPT}" "${TEMPAWKFILE}"
