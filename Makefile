.PHONY: list

# List all targets in this Makefile
list:
	node list-targets.js

# Grab the urls and meta data for all the Episode Pages
# on the MBMBAM Wiki
./derived_data/episode-info.json: grab-episode-info.js source_data/wiki-episode-pages.json
	node grab-episode-info.js

# Grabt the URLs for all the questions.
./derived_data/question-urls.json: grab-question-urls.js derived_data/episode-urls.json
	node grab-question-urls.js

# Grab a set of control questions.
./derived_data/control-question-urls.json: grab-control-question-urls.js derived_data/question-urls.json
	node grab-control-question-urls.js

# Grab the question data for all the urls we've gathered.
./derived_data/question-info.json\
./derived_data/control-question-info.json:\
 grab-question-info.js\
 derived_data/question-urls.json\
 ./derived_data/control-question-urls.json
	node grab-question-info.js

# Convert the results to ascii for simplicity.
./derived_data/control-question-info.ascii.json:\
 ./derived_data/control-question-info.json
	hy info_to_ascii.hy ./derived_data/control-question-info.json

# Convert the results to ascii for simplicity.
./derived_data/question-info.ascii.json:\
 ./derived_data/control-question-info.json
	hy info_to_ascii.hy ./derived_data/question-info.json

# Deduplicate and pre-process our question information.
./derived_data/deduplicated.json:\
 ./derived_data/question-info.ascii.json\
 ./derived_data/control-question-info.ascii.json
	hy deduplicate.hy

