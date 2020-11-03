(require [dotdot [chain]])
(require [hy.contrib.loop [loop]])
(import [Levenshtein [distance]]
        json
        io
        sys
        [numpy :as np]
        [textwrap [fill]]
        [pandas :as pd]
        [nltk.tokenize.casual [TweetTokenizer]]
        [nltk.corpus [stopwords]]
        nltk)

(nltk.download "stopwords")

(defn remove-punctuation [s]
  (setv d {})
  (for [c "!\"#$%&()*+,-./:;<=>?@[\\]^_`{|}~"]
    (setv (chain d [c]) " "))
  (chain s (translate (str.maketrans d))))

(import [plotnine [*]])

(setv tokenizer (TweetTokenizer :preserve-case False))
(defn tokenize-tidy [txt]
  (setv w (stopwords.words "english"))
  (setv txt_ (remove-punctuation txt))
  (list (lfor token (tokenizer.tokenize txt_)
              :if (not (in token w))
              token)))

(defn hd [lst n]
  (cut lst 0 n))

(defn filt [f x]
  (list (filter f x)))

(defn mp [f x]
  (list (map f x)))

(defn sanitize [question-text]
  (chain " " (join
              (lfor token (tokenize-tidy question-text)
                    token))))

(defn load-json [filename]
  (print (chain "input: {}" (format filename)))
  (with [f (io.open filename "r" :encoding "ascii")]
        (json.load f)))

(defn write-json [exp filename]
  (print (chain "output: {}" (format filename)))
  (with [f (io.open filename :mode "w" :encoding "ascii")]
        (f.write (json.dumps exp :indent 1))))

(defn tag [tag-value]
  (fn [item]
    (setv (chain item "category") tag-value)
    item))

(defn has-question? [x]
  (and (in "question" x)
       (not (= "" (chain x "question" (strip))))))

(defn preprocess [category]
  (fn [dataset]
    (filt
     has-question?
     (mp (tag category) dataset))))


(setv data (+ ((preprocess "experimental") (load-json
                                            "./derived_data/question-info.ascii.json"))
              ((preprocess "control") (load-json "./derived_data/control-question-info.ascii.json"))))

(setv ns (len data))
(setv distances [])

(setv i 0)
(for [datum data]
  (setv (chain datum ["duplicates"]) [])
  (setv (chain datum ["id"]) i)
  (setv (chain datum ["sanitized_question"])
        (sanitize
         (chain datum "question")))
  (setv (chain datum ["sanitized_detail"])
        (sanitize
         (chain datum "detail")))
  (when (not (in "answers" datum))
    (setv (chain datum "answers") []))
  (setv (chain datum ["sanitized_answers"])
        (lfor a (chain datum "answers")
              (sanitize a)))
  (setv i (+ i 1)))

(for [i (range ns)]
  (for [j (range (+ 1 i) ns)]
    (setv d (distance
             (chain data [i] "sanitized_question")
             (chain data [j] "sanitized_question")))
    (distances.append d)))

(chain
 (+ (ggplot (pd.DataFrame {"distance" distances}) (aes "distance"))
    (geom_histogram :bins (+ 1 (np.max distances))))
 (save "figures/distance-histogram.png"))

(for [i (range ns)]
  (for [j (range (+ 1 i) ns)]
    (setv qi (chain data [i] "sanitized_question"))
    (setv qj (chain data [j] "sanitized_question"))
    (setv d (distance
             qi
             qj))
    (when (< d 15)
      (chain data [i] "duplicates"
             (append
              (chain data [j] "id")))
      (chain data [j] "duplicates"
             (append
              (chain data [i] "id")))
      (print (chain "\nDuplicates:\n\t{}\n\t{}"
                    (format qi
                            qj))))
    (distances.append d)))

(setv collected-map {})
(setv non-duplicates [])
(for [datum data]
  (setv id (chain datum "id"))
  (when (not (in id collected-map))
    (setv (chain collected-map [id]) True)
    (for [duplicate-id (chain datum "duplicates")]
      (setv (chain collected-map [duplicate-id]) True))
    (chain non-duplicates (append datum))))

(write-json non-duplicates "./derived_data/deduplicated.json")
