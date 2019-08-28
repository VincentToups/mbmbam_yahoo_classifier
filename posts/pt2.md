Pt 2: Getting the Entire Data Set
=================================

Last time we built some infrastructure for doing web scraping in an
organized way: a Docker environment, a Makefile, and some Javascript
utilities to grab URLS and parse out results from them. Today we're
going to quickly finish up our data gathering in a series of stages.

I always start with the Make target first:

```
./derived_data/question-urls.json: grab-question-urls.js derived_data/episode-urls.json
	node grab-question-urls.js
```

Before, we had used code like this:

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

To grab a list of all MBMBAM episode pages from the MBMBAM fan
wiki. The results look like this:

```

[
 {
  "number": 1,
  "title": "Gettin’ Beebed",
  "url": "http://mbmbam.wikia.com/wiki/Episode_01:_Gettin%E2%80%99_Beebed"
 },
 {
  "number": 2,
  "title": "Holding a Stranger's Hand",
  "url": "http://mbmbam.wikia.com/wiki/Episode_02:_Holding_a_Stranger%27s_Hand"
 },
 {
  "number": 3,
  "title": "My Walnut is a Temple",
  "url": "http://mbmbam.wikia.com/wiki/Episode_03:_My_Walnut_is_a_Temple"
 },
 {
  "number": 4,
  "title": "Hey Jeffrey",
  "url": "http://mbmbam.wikia.com/wiki/Episode_04:_Hey_Jeffrey"
 },
 {
  "number": 5,
  "title": "Mega-Jessup",
  "url": "http://mbmbam.wikia.com/wiki/Episode_05:_Mega-Jessup"
 },...]

```

Each of these pages contains zero more more links to a Yahoo Answers
question that looks sort of like this:

```

<a rel="nofollow" 
class="external text" 
href="http://answers.yahoo.com/question/index?qid=20180212173251AASf7OL">
Y</a>
   
```

So our plan is to iterate through the list of pages, grab them, parse
them, and then find all the anchor tags that point to a Yahoo Answers
question.

Asyncronous, Polite, Web Crawling
=================================

We have a large list of URLs which we want to grab. We've already got
a cache in place so that we never fetch a page more than
once. However, [restler][restler], which we're using to do http
requests, is asynchronous. We could easily accidentally make 400
requests at almost the same time. 

It would probably be fine to do this, but we'd like to be more polite
and sequence the requests at a reasonable pace. We might even want to
jitter them in time so that our robot doesn't look quite so robotic.

So, we have a function that returns a promise for a URL and we want to
wait for that promise to resolve before launching the next request. So
we want a function to sequentially create a series of dependent
promises and then finally return a promise for an array of the
results.

```
function pMapSeq(f,a){
    function pMapSeqH(f,a,o){
        return new Promise((resolve,reject)=>{
            if(a.length === 0){
                resolve(o);
            } else {
                f(a[0]).then(r => {
                    resolve(pMapSeqH(f,a.slice(1),o.concat([r])));
                });
            }
        });
    }
    return pMapSeqH(f,a.slice(0),[]);
}
```

Woah! This is clearly Javascript written by a Schemer. But its not too
hard to understand what is going on here<sup>1</sup>. 

We're going to pursue a recursive approach (I find recursion much
easier to understand than iteration). We have an array of objects of
some kind and a function, as input. The function takes one element of
the array and returns a promise. 

Our recursive function takes `f`, an array `a`, and another object `o`
which is accumulating the results of each promise. The base case is
that `a` is empty, and in such a situation, we simply return a Promise
for what is in `o`. 

If `a` isn't empty we have work to do. We apply `f` to the first
element of `a`, which produces a Promise. When that promise resolves,
we recurse, through a promise, to the result of `pMapSeqH` on f, the
rest of a, and `o` with `r` appended to the result.

Just one more thing. In our concrete use case that `f` is a function
which takes a URL and returns a _list_ of URLs we are interested in,
we really want to concatenate all those elements onto our output,
rather than the list itself. That case requires this function 

```
function pMapCatSeq(f,a){
    return pMapSeq(f,a).then(r => [].concat.apply([],r));
}
```

`mapcat` should be relatively familiar to anyone from a functional
background as the `bind` operation of the list monad. We've just
produced some kind of `Promise` + `List` monad thing. 

That abstract nonsense out of the way, we can write our concrete code:

The Questions
=============

We need to detect Yahoo Answers question URLs. In fact, we're going to
do something a little more aggressive. We want fine a list of unique
_question ids_.  It seems like Yahoo indexes their questions via a
query paramater called `qid` in their urls:

    http://answers.yahoo.com/question/index?qid=20180212173251AASf7OL
    
So we want any URL which has the domain `answers.yahoo.com` with page
document `question/index` and which has a `qid` query parameter. We've
got all the dependencies we need to do this already, from last time.

```
function looksLikeYAUrl(url){
    if (!url) return false;
    const parsed = u.parseUrl(url);
    return (parsed.query["qid"] &&
            parsed["host"] == "answers.yahoo.com");
}
```

With that code in place:

```
const to_ya_url = (id) => 'http://answers.yahoo.com/question/index?qid='+id;
function oneEpisodeToQuestionIds(info){
    const url = info.url;
    return u.promiseParsedPage(url)
        .then($=>{
            const o = [];
            $("a").each((i,e)=>{
                if(looksLikeYAUrl(e.attribs.href)){
                    o.push({
                        episode:info.number,
                        url:to_ya_url(u.parseUrl(e.attribs.href)
                                      .query.qid)
                    });
                }
            });
            return o;
        });
}

```

And we can use it like this:

```
u.pMapCatSeq(_ => oneEpisodeToQuestionIds(_.url),
             episode_list).then(ids => {
    console.log(u.uniqueStrings(ids).sort());
});
```

Which is almost perfect, but not quite. This version won't make
hundreds of simultaneous requests (the logic of `pMapCatSeq` ensures
that they occur sequentially) but it will make them one after another,
as fast as possible. Let's be a little more polite and add a delay:

```
function promiseDelay(amount,jitter=0){
    return (resolve_to)=>{
        return new Promise((resolve,reject)=>setTimeout(
        _=>resolve(resolve_to),
        amount+Math.random()*jitter));
    };
}
```

So finally:

```
const by_episode = (a,b) => a.episode - b.episode;
u.pMapCatSeq(_ => oneEpisodeToQuestionIds(_)
             .then(u.promiseDelay(1000,100)),
             episode_list).then(url_info => {
                 fs.writeFileSync("./derived_data/question-urls.json",
                                  JSON.stringify(u.deduplicate(url_info,_=>_.url).sort(by_episode),
                                                 null," "));
                 
             });
```

This will write out a list of the unique, sorted question URLs along
with the episode number from which they derive.

Our next step is to transform these into data from the question pages.

Question Pages
==============

Ok, so, first things first as always, the make target:

```
./derived_data/question-info.json: grab-question-info.js derived_data/question-urls.json
	node grab-question-info.js

```

To scrape each question page, we again pull up our trusty element
inspector. 

A quick investigation suggests that we'll have luck if we find the
`h1` tag under `#ya-question-detail`.


```
function extract_text(node){
    return node.children.map((v,i)=>{
        if(v.type=='text'){
            return rmws(v.data);
        } else {
            return '';
        }
    }).join(' ');
}

function get_question($){
    $("#ya-question-detail").find("h1").each((i,v)=>{
        const txt = extract_text(v);
        console.log(txt);
        return v;
    });
}
```

Once we have the parsed document, the above code extracts the titles.

In addition to the title, we want to grab the extended question
information. This one is easy, since its just in the `.ya-q-text`
class elements.

Since these are under the same element, we can modify the above:

```
function get_question($){
    const container = $("#ya-question-detail");
    const question = [];
    container.find("h1").each
    ((i,v)=>{
        const txt = extract_text(v);
        console.log(txt);
        question.push(txt);
    });
    const question_detail = [];
    container.find(".ya-q-text").each
    ((i,v)=>{
        const txt = extract_text(v);
        question_detail.push(txt);
        return v;
    });
    const r = {
        question:question.join(" "),
        detail:question_detail.join(" ")
    };
    console.log(r);
    return r;
}
```

We've probably got enough data to move onto the data science bit, but
MBMBAM often discuss the _answers_ to the questions, so let's figure
out how to grab those. 

This is less easy. The first complication is that the _best_ answer,
if there is one, is separate from the others in terms of the
hierarchical structure of the document. We can grab it like this,
though:

```
function get_best_answer($){
    const result = rmws($("#ya-best-answer").find("[itemprop='text']").text());
    return result === '' ? undefined : result;
}
```

Everything else is under `#ya-qn-answers`. We'd like to collect each
answer separately. This accomplishes the task:

```
function get_other_answers($){
    const c = $("#ya-qn-answers")
          .find(".ya-q-full-text")
          .map((i,v) => rmws($(v).text()));
    const n = c.length;
    return Array.prototype.slice.call(c,0,n);
}
```

We want to combine this into a single function of the cheerio object:

```
function get_question_info($){
    const out = {};
    const q = get_question($);
    const ba = get_best_answer($);
    const a = get_other_answers($);
    out.question = q.question;
    out.detail = q.detail;
    if(ba){
        out.first_best = true;
        out.answers = [ba].concat(a);
    } else {
        out.first_best = false;
    }
    return out;    
}

```

Which we can use thusly:

```
const urls = require("./derived_data/question-urls.json");

u.pMapSeq(_ => u.promiseParsedPage(_.url)
          .then(u.promiseDelay(1000,100))
          .then(get_question_info),urls)
    .then(results => {
        fs.writeFileSync(
            "./derived_data/question-info.json",
            JSON.stringify(results,null, " "));
    });
```

Which will gather up all our data for us. This is a big milestone:
we've grabbed a large subset (potentially all, depending on the wiki
coverage) of the Yahoo Answers questions used on MBMBAM.

The Control Data Set
====================

We're not ready to analyze the data yet, though - we need a _control_
data set. That is, we need some questions which _aren't_ on the show. 

How do we get such a set? 

Well, let's just start on the Yahoo Answers homepage and crawl the
site for question URLs. We'll keep crawling along, grabbing IDs until
we reach some threshold. For our own sanity, we'll also compare the
IDs we get agains the MBMBAM set so we don't accidentally pick any of
those up in the haul.

As always, a Make target:

We're going to do this in two steps, for the sake of clarity and
maintainability. The first step will just grab urls, formatting them
in the same way as our previous URL list. 

Then we'll modify our previous code to grab those questions as well. 

The required code is both a straightforward generalization of the
ideas we've been working with and a non-trivial forward evolution of
the same. Most of that non-triviality is related to the fact that
we've got a genuinely recursive algorithm now - one which needs to
track which urls we've visited, which we've collected, and which are
already in the experimental data set.

Here is a taste - following the detailed code is an exercise for the
reader.


```
function promiseControlSet(unvisited,
                           visited,
                           collected,
                           target_count){
    if(Object.keys(collected).length >= target_count){
        return trivial(Object.keys(collected));
    } if(unvisited.length==0) {
        const e = new Error("Ran out of potential links before reaching target count.");
        e.visited = visited;
        return trivial_rejection(e);
    } else {
        return u.pMapCatSeq(_ => u.url_to_question_urls(_,
                                                        "https://answers.yahoo.com")
                            .then(u.promiseDelay(100,100)),
                            unvisited)
            .then(results => {
                const new_visited =
                      u.indicator_union(visited,u.copy_table(u.to_indicator(unvisited)));
                const new_collected = u.copy_table(collected);
                const new_unvisited = [];
                results.forEach(url => {
                    if(!experimental[url]){
                        new_collected[url] = true;
                    }
                    if(!new_visited[url]){
                        new_unvisited.push(url);
                    }
                });
                const current_count = Object.keys(new_collected).length;
                const visited_count = Object.keys(new_visited).length;
                return promiseControlSet(u.shuffle(new_unvisited).slice(0,500),
                                         new_visited,
                                         new_collected,
                                         target_count);
            });
    }
}

```

Nothing in our dependency graph prevents us from adding logic to
extract the question data for these control urls to our previous
task. We just need to add the control urls to the Makefile.

```

./derived_data/question-info.json\
./derived_data/control-question-info.json:\
 grab-question-info.js\
 derived_data/question-urls.json\
 ./derived_data/control-question-urls.json
	node grab-question-info.js

```

We've added a second target to this task and the appropraite
dependency. Its a straightforward modification of
`grab-question-info.js` to make it grab the control urls and extract
out the question data for them as well.

We've now got our data set. At the time of this writing, it consists
of ~1600 control questions and ~650 questions from the podcast. Next
time we'll start doing data science!

* * *

### Footnotes

<sup>1</sup>: Ok, so it might be a little hard. Since this is a
tutorial, I'm trying to figure out why I wrote the code like this and
whether its non-straigtforwardness is virtuous or not. From where I'm
sitting, this function is easy to understand. It was also easy to
write. But I think what makes it challenging is the way that it
combines idioms from functional programming with the asynchronous
nature of Javascript and the abstraction of a Promise on top of it. In
its own way, Scheme's emphasis on continuations help prepare the brain
for Asynchronous Javascript.

The other thing that makes this a little challenging is the
abstraction penalty. We _were_ talking about HTTP requests and that is
totally absent here - completely hidden in `f` which merely takes an
arbitrary object and only needs to return a Promise for another
arbitrary object. This sudden jump into abstraction is disorienting.

While I'm sure this isn't true for most Data Scientists (and certainly
not for most developers), I do almost all my work on single person
projects. Consequently, I'm usually free to program in a way which I
find comfortable which is bound to be idiosyncratic, without external
pressure. If I were working on this project with another developer,
I'd probably choose a less abstract approach under the assumptions
that their peculiarities don't line up with mine.

