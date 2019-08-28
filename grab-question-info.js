var Promise = require("bluebird");
const u = require("./util.js");
const fs = require("fs");
const urldecode = require("urldecode");
const rmws = require("condense-whitespace");

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
    const container = $("#ya-question-detail");
    const question = [];
    container.find("h1").each
    ((i,v)=>{
        const txt = extract_text(v);
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
    return r;
}

function get_best_answer($){
    const result = rmws($("#ya-best-answer").find("[itemprop='text']").text());
    return result === '' ? undefined : result;
}

function get_other_answers($){
    const c = $("#ya-qn-answers")
          .find(".ya-q-full-text")
          .map((i,v) => rmws($(v).text()));
    const n = c.length;
    return Array.prototype.slice.call(c,0,n);
}

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

const urls = require("./derived_data/question-urls.json");
const control = require("./derived_data/control-question-urls.json");

u.pMapSeq(_ => u.promiseParsedPage(_.url)
          .then(u.promiseDelay(1000,100))
          .then(get_question_info),urls)
    .then(results => {
        fs.writeFileSync(
            "./derived_data/question-info.json",
            JSON.stringify(results,null, " "));
    });

u.pMapSeq(_ => u.promiseParsedPage(_)
          .then(u.promiseDelay(1000,100))
          .then(get_question_info),control)
    .then(results => {
        fs.writeFileSync(
            "./derived_data/control-question-info.json",
            JSON.stringify(results,null, " "));
    });








