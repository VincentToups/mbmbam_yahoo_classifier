const fs = require("fs");
const parseMakefile = require("@kba/makefile-parser");
const slurp = (fn) => fs.readFileSync(fn,"UTF-8");
parseMakefile(slurp("./Makefile")).ast.forEach(element => {
    if("target" in element){
        console.log("- "+element.target+" -");
        console.log(element.comment.map(_=>"* \t"+_).join("\n"));
    }
});


