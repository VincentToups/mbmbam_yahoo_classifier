var Promise = require("bluebird");
const u = require("./util.js");
const fs = require("fs");
const urldecode = require("urldecode");

const looksLikeYAUrl = u.looksLikeYAUrl;

const to_ya_url = u.to_ya_url;

const experimental = u.to_indicator(
    require("./derived_data/question-urls.json").map(_ => _.url));

const not_in = indicator_table => id => !indicator_table[id];

const f_and = (a,b) => x => a(x) && b(x);

const trivial = (value) => new Promise((resolve,reject)=>resolve(value));
const trivial_rejection = (e) => new Promise((resolve,reject)=>reject(e));

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

function promiseCategoryLinks(){
    return u.promiseParsedPage("https://answers.yahoo.com/").then($ => {
        const urls = [];
        $("#ya-left-rail").find("li.ya-cat-link").find("a").each((i,v) => {
            if(v.attribs.href && v.attribs.href.indexOf("sid") != -1){
                urls.push("https://answers.yahoo.com"+v.attribs.href);
            }
        });
        return urls;
    });
}

promiseCategoryLinks()
    .then(urls => promiseControlSet(urls,
                                    {},
                                    {},
                                    Object.keys(experimental).length))
    .then(_ => fs.writeFileSync("./derived_data/control-question-urls.json",
                               JSON.stringify(_,null," ")));

