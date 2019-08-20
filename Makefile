.PHONY: list

# List all targets in this Makefile
list:
	node list-targets.js

# Grab the urls and meta data for all the Episode Pages
# on the MBMBAM Wiki
./derived_data/episode-info.json: grab-episode-info.js source_data/wiki-episode-pages.json
	node grab-episode-info.js

./derived_data/question-urls.json: grab-question-urls.js derived_data/episode-urls.json
	node grab-question-urls.js

./derived_data/question-info.json: grab-question-info.js derived_data/question-urls.json
	node grab-question-info.js

./derived_data/control-question-urls.json: grab-control-question-urls.js derived_data/question-urls.json
	node grab-control-question-urls.js
