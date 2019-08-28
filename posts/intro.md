Let's Do Some Data Science
==========================

I perused my github over the weekend and noticed its been awhile since
I've put anything both new and substantial up there. There are a few
reasons for this. First of all, I've had a steady job as a software
engineer and data scientist for a few years now and thus, most of what
I produce, from a technical perspective, is proprietary. Second, what
I have produced as an independent is closed source, for various
reasons. The biggest example of that is
[The Death of the Corpse Wizard][cw], which I can't release because of
copyright encumberances with respect to assets which I could,
probably, deal with, but haven't had the time. And finally, I'm a dad
now, and I don't have nearly the time I used to for hacking
independently. 

Still, it doesn't do to let your portfolio languish, so I thought I'd
put together a repository which shows the sort of work I'm up to these
days (though obviously in a different domain from my day job).

The Problem
===========

The problem with learning data science (from my point of view) is that
you're always limited to previously existing data sets and thus, after
whatever work you put in, you are bound merely to reproduce some
previous result. This isn't any fun.

Plus, a lot of the publically available data sets out there are boring
as heck. On top of that, just getting handed a data set that has been
pre-tidied is also pretty unrepresentative of the actual trudge and
slog of a real data scientist's life. 

Thus, I wanted to do a series of posts, combined with a repository,
which demonstrate a complete project, from zero data to analysis and
summary, with an emphasis on both the operational and data-scientific
aspects of the job.

About Me
========

I'm Dr Vincent Toups, full spectrum data Scientist where "full
spectrum" is meant to imply a broad experience with a wide variety of
technical tasks (front end, back end software development, data
science, programming language development, game design and
development, etc) and the capital "S" in Scientist meant to imply
that, fundamentally, I still think of myself as primarily connected to
my background as a scientist and physicist.

The Problem
===========

[My Brother, My Brother and Me][mbmbam] is a popular comedy/advice podcast
within which they often read question from [Yahoo Answers][ya] because
they are funny.

The podcast crowdsources the process of selecting questions and thus,
to an extent, it is gamified: those fortunate enough to understand
precisely what is funny and what isn't and thus to get questions on
the show are rewarded with nicknames. An informal leaderboard also
exists.

Can we predict what questions would be accepted on the show. Can we
build a robot to conquer the leaderboards?

The Plan
========

The plan is informed by the fact that I've done a lot of this work
already. In reality, at this stage of a project, we'd probably have
only the vaguest idea of what we really want to get out of this
project. That said, we can cook up the following:

1. Get the data
2. Clean it and characterize it
3. Build a model 

Step 1: Get the Data
====================

Just as The McElroy's crowdsource the collection of questions, we can
crowdsource the data gathering. In particular, there is a relatively
well maintained [MBMBAM Wiki](mbmbamw) which has episode summaries
with links to the associated Yahoo Answers questions. 

So step one is to build a crawler to crawl the wiki and grab the
episode data. From that data set we'll crawl the pages and grab the
Yahoo Answers question URLs. Finally, we'll crawl those pages for the
data we need.

Preliminaries
-------------

### Language Selection

We're going to build our data gatherer in Javascript because:

1. Its a great language
2. As the in-browser language its got lots of web-adjacent tooling
   that will make writing a crawler easy.
   
I'm told Python has good tools for writing crawlers but, frankly, I'm
not super fond of the language. Its always more productive to do what
you enjoy, all other things being equal.
   
### Etiquette

We're going to be writing a lot of code which scrapes the web. As we
do this, we'll probably find outselves running the code over and over
again, refining what we're up to. If you run this code, you might want
to run it a few times to experiment.

Its good manners to make sure we don't generate excessive traffic. The
best way to do that is to maintain a local cache of the results of our
web requests - that way we can run our code over and over but never
request the same page twice. That is our first goal.

### Docker

But before we do that, let's create a Docker environment to actually
run our code. 

I believe strongly in Dockerizing all my Data Science work so that its
easy for people who are new to the project to get started. It can be a
major hassle to set up a Dockerfile for an existing project, but when
you start from scratch, its just a convenient way to keep track of the
dependencies as you go.

Here is our initial docker file:

```
FROM centos:7
MAINTAINER Vincent Toups "vincent.toups@gmail.com"
RUN yum -y groupinstall 'Development Tools'
RUN yum install -y\
        curl\
        sqlite\
        sqlite-devel\
        sqlite\
        wget\
        which\
RUN yum -y install epel-release
RUN yum -y install nodejs
RUN npm install --global\
        bluebird\
        cheerio\
        file-exists\
        md5\
        restler\
        stopword\
        text2token\
        url-parse\
        wink-nlp-utils\
        wink-tokenizer\
        query-string\
        urldecode\
RUN npm install --global @kba/makefile-parser
ARG NODE_PATH_BT=/usr/lib/node_modules
ENV NODE_PATH=$NODE_PATH_BT
WORKDIR /host
CMD /bin/bash

```

This is a little bigger than what you might truly install for a
totally fresh project, but I kinda know where I'm going - basically
we're grabbing nodejs and libraries we'll use for fetching web pages,
parsing them, and then processing the results.

You might also notice I've grabbed a Makefile parser. That is so we
can instrument our build process a little bit.

### Make

Docker manages our dependencies, but its just as important to automate
and document our _build_, even for a data science project. For a
regular software project, builds generally produce software
artifacts. In Data Science, build steps generally produce chunks of
data in various forms. But the idea is the same. We don't store
intermediate results in our repos for various reasons (version control
is for code) and we want every step of our data science to be as
reproducible as is warranted. Hence, we document it all with Make,
which also automates it for us.

Here is our initial Makefile:

```
.PHONY: list

# List all targets in this Makefile
list:
	node list-targets.js

```

So far its got one target: `list`, which is [PHONY][phony]. All it
does is run a node script that parses our Makefile and prints out the
targets, along with the documentation associated with each.

That looks like this:

```
const fs = require("fs");
const parseMakefile = require("@kba/makefile-parser");
const slurp = (fn) => fs.readFileSync(fn,"UTF-8");
parseMakefile(slurp("./Makefile")).ast.forEach(element => {
    if("target" in element){
        console.log("- "+element.target+" -");
        console.log(element.comment.map(_=>"* \t"+_).join("\n"));
    }
});
```

We should now be able to do the thing:

```
> docker build . -t mbmbam
> docker run -v `pwd`:/host -it make list

node list-targets.js
- list -
* 	List all targets in this Makefile

```

Interpretation
=============

If you are the typical slovenly data scientist (and let's be honest,
we've all been there), you may be asking "why go to all this trouble
if we just want to do some exploratory analysis?"

A lesson I've learned from software engineering is that today's quick
one-off often becomes tomorrow's miserable legacy codebase. So we want
to do it right from the first moment. Virtue is its own reward.

My goal is that if I get hit by a bus, or (more likely) attain true
software enlightenment tomorrow (and never spend another minute
looking at a screen), that anyone can pick up my repository,
understand its entire history and how to run it, right away.

* * *

[cw]:https://featurecreeps.itch.io/corpsewizard
[mbmbam]:https://www.themcelroy.family/
[mbmbamw]:http://mbmbam.wikia.com/wiki/Category:Episodes
[ya]:https://answers.yahoo.com/
[phony]:https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
