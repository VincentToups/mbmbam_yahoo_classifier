var Promise = require("bluebird");
const u = require("./util.js");
const fs = require("fs");
const urldecode = require("urldecode");

const looksLikeYAUrl = u.looksLikeYAUrl;

const to_ya_url = u.to_ya_url;


function oneEpisodeToQuestionIds(info){
    const url = info.url;
    return u.url_to_question_urls(url).then(_ => {
        return {
            episode:info.number,
            url:_
        };
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


