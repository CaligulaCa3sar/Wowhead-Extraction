#!/bin/bash
#
# Extracts the data for loot drops in the raid at the specified URL
# Calls the external Python script get-html-element.py

# VARIABLES
DATESTAMP="$(date +%Y-%m-%d-%H%M%S)"
URL="${1}"
TEMPFILE="${URL##*/}-${DATESTAMP}"      # Greedily trim everything from front (##) matching any character (*) until last occurring "/"
TEMPTRIMFILE="${TEMPFILE}-trimmed"
TEMPAWKFILE="${TEMPFILE}-awk"
FINALFILE="${TEMPFILE}-final"
PYTHONSCRIPT="get-html-element.py"

# Retrieve the page with cURL and output to $TEMPFILE:
curl -o "${TEMPFILE}" "${URL}"

# Extract desired element from $TEMPFILE using Python and BeautifulSoup4 and save output to $TEMPTRIMFILE:
python3 "${PYTHONSCRIPT}" "${TEMPFILE}" > "${TEMPTRIMFILE}"

# Extract loot source headers and item hyperlinks from $TEMPTRIMFILE and write back into $TEMPFILE:
grep -o -E "<h3 class=\"heading-size-3\">([a-zA-Z ,']+)<\/h3>\
|<h2 class=\"heading-size-2\">([a-zA-Z ,']+) Trash Loot<\/h2>\
|<a href=\"\/item=[0-9]+\">([a-zA-Z ,':-]+)<\/a>" "${TEMPTRIMFILE}" | sed -n -e '/<h3 /,$p' > "${TEMPFILE}"

# Rewrite each line to strip out the HTML and format the info:
gawk -F [\>\<=\"] -e '/\<h3|\<h2/ { gsub(/Classic | Loot/, ""); print $6 }' \
	-e '/\<a/ { formattedName = tolower($7); \
		formattedName = gensub(/ /, "-", "g", formattedName); \
		formattedName = gensub(/[:,\047]/, "", "g", formattedName); \
		formattedName = gensub(/-{3}/, "-", "g", formattedName); \
		print $5 ";" $7 ";https://classic.wowhead.com/item=" $5 "/" formattedName }' "${TEMPFILE}" > "${TEMPAWKFILE}"

# Split $TEMPAWKFILE into separate files for each boss:
awk -v i=0 -e '{ if (!/;/) i++; print $0 >> "Boss"i }' "${TEMPAWKFILE}"

# Create directory for the "Boss*" files and move them in:


# Tidy up:
#rm "${TEMPFILE}" "${TEMPTRIMFILE}" "${TEMPAWKFILE}"
