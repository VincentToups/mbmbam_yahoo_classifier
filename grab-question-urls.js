var Promise = require("bluebird");
const u = require("./util.js");
const fs = require("fs");
const urldecode = require("urldecode");

function looksLikeYAUrl(url){
    if (!url) return false;
    const parsed = u.parseUrl(url);
    return (parsed.query["qid"] &&
            parsed["host"] == "answers.yahoo.com");
}

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

const episode_list = require("./derived_data/episode-info.json");

const by_url = (a,b) => a < b ? -1 : a > b ? 1 : 0;
const by_episode = (a,b) => a.episode - b.episode;
u.pMapCatSeq(_ => oneEpisodeToQuestionIds(_)
             .then(u.promiseDelay(1000,100)),
             episode_list).then(url_info => {
                 fs.writeFileSync("./derived_data/question-urls.json",
                                  JSON.stringify(u.deduplicate(url_info,_=>_.url).sort(by_episode),
                                                 null," "));
                 
             });


