var Promise = require("bluebird");
const u = require("./util.js");
const fs = require("fs");
const urldecode = require("urldecode");

const pages = require("./source_data/wiki-episode-pages.json");

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

function extractEpisodeId(url){
    return u.parseUrl(url).pathname.split('/')[2];
}

const not_empty = x => x.length != 0;

function parseEpisodeId(ep){
    const o = {};
    const parts = ep.split(":");
    const p1 = parts[0].split("_");
    const p2 = parts.slice(1).join(":").split("_").filter(not_empty);
    const number = +p1[1];
    return {
        number:number,
        title:urldecode(p2.join(" "))
    };
}

const by_number = (a,b) => {
    return a.number - b.number;
};

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
    return o;
});
