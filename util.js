var Promise = require("bluebird");
const cheerio = require("cheerio");
const restler = require("restler");
const fs = require("fs");
const fileExists = require("file-exists");
const md5 = require('md5');
const _parseUrl = require("url-parse");
const parseQueryString = require("query-string").parse;

function ensureDirectory(dir){
    if (!fs.existsSync(dir)){
        fs.mkdirSync(dir);
    }
}
ensureDirectory('./http-cache');

function urlHash(url){
    return './http-cache/'+md5(url);
};

function promiseGet(url){
    return new Promise((resolve,reject) => {
        restler.get(url).on('complete',(result,response)=>{
            ((result instanceof Error) ? reject : resolve)(result);
        });
    });
}

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

function promiseParsedPage(url, forceRecache=false){
    return promisePage(url,forceRecache).then(contents => {
        return cheerio.load(contents);
    });
}

function parseUrl(url) {
    let p = _parseUrl(url);
    p.query = parseQueryString(p.query);
    return p;
};

function uniqueStrings(a){
    const tmp = {};
    a.forEach(k => tmp[k] = true);
    return Object.keys(tmp).sort();
}

function obj(){
    const a = Array.prototype.slice.call(arguments,0,arguments.length);
    const o = {};
    const itmax = a.length/2;
    if(itmax !== Math.round(itmax)){
        throw new Error("obj: need and even number of string/value arguments");
    }
    for(let i = 0; i < itmax; i++){
                                   o[a[i*2]] = a[i*2+1];
                                   }
    return o;
}

function deduplicate(a,f){
    const tmp = {};
    a.forEach(e => {
        const k = f(e);
        const c = tmp[k] || [];
        c.push(e);
        tmp[k] = c;
    });
    return Object.keys(tmp).map(k => tmp[k][0]);    
}

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

function pMapCatSeq(f,a){
    return pMapSeq(f,a).then(r => [].concat.apply([],r));
}

function promiseDelay(amount,jitter=0){
    return (resolve_to)=>{
        return new Promise((resolve,reject)=>setTimeout(_=>resolve(resolve_to),amount+Math.random()*jitter));
    };
}


module.exports = {
    ensureDirectory:ensureDirectory,
    parseUrl:parseUrl,
    promiseDelay:promiseDelay,
    promisePage:promisePage,
    promiseParsedPage:promiseParsedPage,
    pMapSeq:pMapSeq,
    pMapCatSeq:pMapCatSeq,
    uniqueStrings:uniqueStrings,
    deduplicate:deduplicate,
    obj:obj
};
