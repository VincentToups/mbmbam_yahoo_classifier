(require [dotdot [chain]])
(require [hy.contrib.loop [loop]])
(import [Levenshtein [distance]]
        json
        io
        sys)

(setv infile (chain sys argv 1))

(defn encode [sob]
  (cond
   [(isinstance sob bytes)
    (chain sob (decode) (encode "ascii" "ignore") (decode))]
   [(isinstance sob str)
    (chain sob (encode "ascii" "ignore") (decode))]))

(defn re-encode-to-ascii [entry]
  (setv n-answers (if (in "answers" entry)
                    (len (chain entry "answers"))
                    0))
  (if (in "question" entry)
    (setv (chain entry "question")
          (encode (chain entry "question"))))
  (if (in "detail" entry)
    (setv (chain entry "detail")
          (encode (chain entry "detail"))))
  (loop [[i 0]]
        (nonlocal entry)
        (cond
         [(= i n-answers) :done]
         [True (setv (. entry ["answers"] [i])
                     (encode (chain entry ["answers"] [i])))
          (recur (+ i 1))]))
  entry)

(setv exp (with [f (io.open infile :mode "r" :encoding "utf-8")]
                (json.load f)))

(for [v exp]
  (re-encode-to-ascii v))

(print infile)
(setv outfile (chain infile (replace ".json" ".ascii.json")))

(print outfile)

(with [f (io.open outfile :mode "w" :encoding "ascii")]
      (f.write (json.dumps exp)))








