.PHONY: list

# List all targets in this Makefile
list:
	node list-targets.js

# Grab the urls and meta data for all the Episode Pages
# on the MBMBAM Wiki
./derived_data/episode-info.json: grab-episode-urls.js source_data/wiki-episode-pages.json
	node grab-episode-urls.js

