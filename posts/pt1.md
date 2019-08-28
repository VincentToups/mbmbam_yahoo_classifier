Part 1: Groundwork for Gathering Data
=====================================

Last time we prepped our repository with a Makefile and a
Dockerfile. In addition to using `git`, these two tools are going to
form the backbone of our project. We now proceed, like a necromancer,
to heap upon that backbone all the muscle and viscera and integument
of a real project.

Starting with: web scraping.

Where to Begin?
---------------

Before we even pull down our first web page, we'll need to develop
some logic to cache the results locally. We're not doing anything time
sensitive, and it will make whatever websites we hit a lot less likely
to ban our ip if we never hit the same page twice. That is, we want to
pass our requests through a local cache. 

Our very first need is to make HTTP requests. Let's use `restler`:

`util.js`
```
const restler = require("restler");

```

I like to promisify things, so:

```
var Promise = require("bluebird");
const restler = require("restler");
```

And we need to parse the resulting HTML documents:

```
var Promise = require("bluebird");
const restler = require("restler");
const cheerio = require("cheerio");

```

The essence of caching is storing results locally. So we'll need the
filesystem library and a micro-library to test whether a file exists:

```
const fs = require("fs");
const fileExists = require("file-exists");
```

Finally, we're going to need to hash the url's so that we don't
produce a lot of ugly file names. URL's are often ambiguous such that
many denotations point to one actual URL. It will be handy to parse
them, so:

```
const md5 = require('md5');
const _parseUrl = require("url-parse");
const parseQueryString = require("query-string").parse;
```

Now we can write code some code. First we'd like to write a little
utility to promise us the HTML at a URL:

```

function promiseGet(url){
    return new Promise((resolve,reject) => {
        restler.get(url).on('complete',(result,response)=>{
            ((result instanceof Error) ? reject : resolve)(result);
        });
    });
}

```

Here `result` is the result of our promise and the contents of the
page.

Next we want to wrap that in a cache layer:

```

function ensureDirectory(dir){
    if (!fs.existsSync(dir)){
        fs.mkdirSync(dir);
    }
}
ensureDirectory('./http-cache');

function urlHash(url){
    return './http-cache/'+md5(url);
};

function promiseGetCached(url){
    return new Promise((resolve,reject)=>{
        fileExists(urlHash(url),(err,exists) => {
            if(err instanceof Error) {
                reject(err);
            } else {
                if(exists){
                    fs.readFile(urlHash(url),'utf8',((err,contents) => {
                        console.log("Cache hit: ",(url));
                        resolve(contents);
                    }));
                } else {
                    promiseGet(url).then((contents)=>{
                        console.log("Cache miss: ",(url));
                        fs.writeFileSync(urlHash(url),contents);
                        resolve(contents);
                    });
                }
            }
        });
    });
}
// A useful interface to both the cached and uncached 
// functions.
function promisePage(url,forceRecache=false){
    if(forceRecache){
        try {
            fs.unlinkSync(urlHash(url));
        } catch (e) {
            //pass 
        }
    }
    return promiseGetCached(url);
}

// Parse the results with cheerio, since that is
// always going to be our first step anyway.
function promiseParsedPage(url, forceRecache=false){
    return promisePage(url,forceRecache).then(contents => {
        return cheerio.load(contents);
    });
}


```

We probably could write this more idiomatically as a promise chain
that relies on a null check of the cache results but I don't like
nulls and I don't like mixing types.

Now, given this minimal code, we can begin to write a crawler.

How are we going to go about that?

First, we identify the input data. The place to start is the episode
list on the [MBMBAM wiki][mbmbamw]. There are just three pages of
episodes so let's just manually grab them and put them someplace nice.

I always organize my data science projects with a `source_data`
directory. One way or another, this data is managed by git (maybe by
git-lfs if its big). It represents the immutable launching point for
our analysis. The important thing is, its not an _artifact_. Its given
to us.

>./source_data/wiki-episode-pages.json
```
["http://mbmbam.wikia.com/wiki/Category:Episodes",
 "http://mbmbam.wikia.com/wiki/Category:Episodes?pagefrom=Episode+197%3A+Number+the+Veins",
 "http://mbmbam.wikia.com/wiki/Category:Episodes?pagefrom=MaxFunDrive+2015%3ABig+Gulp%0AMy+Brother%2C+My+Brother+and+Me+present+Big+Gulp%2C+Live%21+%28MaxFunDrive+2015%29"]
```

Now we ask ourselves: what is the first step? 

The first step is: We have a list of urls pointing to pages containing
links to episode pages. We want to transform that list to a list of
episode urls.

So we add an entry to our Makefile:

```
./derived_data/episode-info.json:\
 grab-episode-info.js
 source_data/wiki-episode-pages.json
	node grab-episode-info.js

```

For those unfamiliar with make, we're just literally saying
`./derived_data/episode-info.json` is an artifact which depends on
`grab-episode-info.js` and `source_data/wiki-episode-pages.json` which
we build by saying `node grab-episode-info.js`.

Why track things like this? 

1. As our project grows in complexity, the Makefile will become a
   crucial piece of documentation: which parts of our analysis depend
   on which other parts. 
2. A makefile is executable: if we make a change somewhere in our
   codebase, Make will automatically understand which steps need to be
   re-executed (and in what order), to update any particular result.
3. We aren't going to check results into our repository (git is code
   code, after all). So a person coming to the repository for the
   first time will want to run code: Make is the perfect
   interface. They won't have to worry about dependencies. They can
   pick a target, and run `make <target>` and make will take care of
   all the intermediate results that that target needs.
   
Because of all this, I always start any task in a data science project
with a Make target.

First a high level plan:

1. Grab the contents of each page. 
2. Get all the anchor tags.
3. Filter out just the tags which point to URLs that look like Episode
   Urls.
4. Parse out some information about each URL
5. Deduplicate them
6. Write them out.

The key to any web data gathering project is poking around the DOM in
your favorite browser (Firefox):

![Inspect An Element][inspect]

In this case, we can tell that an episode URL looks like this:

    https://mbmbam.fandom.com/wiki/Episode_<number>:<title>
    
We can detect such a url like this:

```
function looksLikeEpisodeUrl(url){
    const parsed = u.parseUrl(url);
    return (parsed.host === "mbmbam.wikia.com" &&
            typeof parsed.pathname !== "undefined" &&
            pathnameCheck(parsed.pathname));
    function pathnameCheck(fragment){
        const parts = fragment.split("/");
        return (parts.length === 3 &&
                parts[0] === '' &&
                parts[1] === 'wiki'
                && parts[2].split('_')[0] === 'Episode');
    }
}
```

(Aside: why do I always use `const`?<sup>1</sup>)

So now we just need to put it all together (some code omitted here,
see the [git repository][gitrepo]).

>
```
Promise.all(pages
            .map(_ => u.promiseParsedPage(_)
                 .then(page => u.obj("url",_,"page",page))))
    .then(pages => {
    const o = [];
    pages.map(({url,page}) => {
        const urlP = u.parseUrl(url);
        page("a").each((i,el)=>{
            if(!el.attribs.href) return;
            const maybe_url = urlP.origin+el.attribs.href;
            if(looksLikeEpisodeUrl(maybe_url)){
                const md = parseEpisodeId(extractEpisodeId(maybe_url));
                md.url = maybe_url;
                o.push(md);
            }
        });
    });
    //console.log(o);
    
    u.ensureDirectory("./derived_data/");
    o.sort(by_number);
    fs.writeFileSync("./derived_data/episode-info.json",
                     JSON.stringify(u.deduplicate(o,
                                                  _=>_.number),null," "));
```

This writes out our list of episode URLs. Next time we're going to
basically recurse in and select out the URLs which point to Yahoo
Answers questions. These will for the basis of our labelled data set.

Interpretation
==============

The most important takeaway from today's work is that its good to
treat our projects as a series of Make targets, which explicitly
delineated dependencies. This is great for both documentation and
making this repeatable easily, both for ourselves and people new to
the project.

We also wrote a little web crawler along with a cache, to make it more
friendly. We're gradually building up to have a large data set that we
generated ourselves!

* * *

### Footnotes
#### <sup>1</sup> Why do I always use `const` declarations? 

A computer is just a big state machine. A correct program picks out a
particular sequence of states out of the almost infinite ocean of
possible sequences. Everything you can do to narrow down the possible
sequence of future states makes it easier to reason about the program
and harder to introduce bugs. Unless I specifically anticipate a need
for a binding to be mutable, I make it constant.

Thus, its a great wart on the language of Javascript that there is
nothing like `let` but which binds `const`antly. If you need a binding
in a leg of an if expression you are forced to either `var` or `const`
it, which lifts up to the enclosing function scope, or `let` it, which
is a local binding but is mutable.

[mbmbamw]:https://mbmbam.fandom.com/wiki/Category:Episodes
[inspect]:./inspect.png
[gitrepo]:https://github.com/VincentToups/mbmbam-project
