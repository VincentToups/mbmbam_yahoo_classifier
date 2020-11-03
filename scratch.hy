(require [dotdot [chain]])
(require [hy.contrib.loop [loop]])
(import [Levenshtein [distance]]
        json
        io
        sys
        [numpy :as np]
        [textwrap [fill]]
        [nltk.tokenize.casual [TweetTokenizer]])

(setv tokenizer (TweetTokenizer :preserve-case False))
(defn token-set [str]
  (set (filter (fn [x] (> (len x) 3)) (chain tokenizer (tokenize str)))))

(defn normalized-levenshtein [a b]
  (setv seta (token-set a))
  (setv setb (token-set b))
  (setv tmp seta)
  (setv seta (- seta setb))
  (setv setb (- setb tmp))
  (setv a-prime (chain " " (join (sorted (list seta)))))
  (setv b-prime (chain " " (join (sorted (list setb)))))
  (if (and
       (= 0 (len b-prime))
       (= 0 (len a-prime))) 0
       (/ (distance a-prime b-prime)
          (/ (+ (len a-prime)
                (len b-prime)) 2.0))))

(import [plotly [graph_objects :as go]])

(defn hd [lst n]
  (cut lst 0 n))

(defn filt [f x]
  (list (filter f x)))

(defn mp [f x]
  (list (map f x)))

(defn load-json [filename]
  (with [f (io.open filename "r" :encoding "ascii")]
        (json.load f)))

(defn write-json [filename]
  (with [f (io.open filename :mode "w" :encoding "ascii")]
        (f.write (json.dumps exp))))

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

(defn lv-normed [a b]
  (setv na (len a))
  (setv nb (len b))
  (setv av (/ (+ na nb) 2))
  (/ (distance a b) av))

(setv config (load-json "./dedup.config.json"));
(setv threshold (chain config "threshold"))
(setv metric (chain
              {
               "levenshtein"
               distance
               "normalized-levenshtein"
               normalized-levenshtein}              
              [(chain config "metric")]))

(setv data (+ ((preprocess "experimental") (load-json
                                            "./derived_data/question-info.ascii.json"))
              ((preprocess "control") (load-json "./derived_data/control-question-info.ascii.json"))))
(setv ns (len data))

;; assign each question a unique id
;; and add a duplicates field to each
(for [i (range ns)]
  (setv (chain data [i] "id") i)
  (setv (chain data [i] "duplicates") []))

(setv distances [])

(for [i (range ns)]
  (for [j (range (+ 1 i) ns)]
    (setv d (metric
             (chain data [i] "question")
             (chain data [j] "question")))
    (when (< d threshold)
      (when (!= d 0)
        (print (chain "Duplicates ({}): \n  {}\n  {}"
                      (format d
                              (fill (chain data [i] "question"))
                              (fill (chain data [j] "question"))))))
      (chain data [i] "duplicates" (append (chain data [j] "id")))
      (chain data [j] "duplicates" (append (chain data [i] "id"))))
    (distances.append d)))

(setv n-control-with-duplicates
      (len (filt (fn [x]
                   (and (= (chain x "category") "control")
                        (!= 0 (len (chain x "duplicates")))))
                 data)))
(setv n-exp-with-duplicates
            (len (filt (fn [x]
                   (and (= (chain x "category") "experimental")
                        (!= 0 (len (chain x "duplicates")))))
                       data)))

(setv n-blackballed 0)
(for [i (range ns)]
  (setv c (chain data [i]))
  (setv dups (chain c "duplicates"))
  (setv n-dups (len dups))
  (when (and (not (in "blackballed" c))
             (!= 0 n-dups))
    (for [j (range n-dups)]
      (setv (chain data [(chain dups [j])] "blackballed") True)
      (setv n-blackballed (+ n-blackballed 1)))))

(print (chain "Blackballed {} questions for duplication." (format n-blackballed)))


(setv bins (np.arange 0 (np.max distances)
                      (if (all (lfor x distances
                                     (isinstance x int))) 1
                                     0.01)))

(setv h (np.histogram (np.array distances) bins))

(setv fig (go.Figure :data (go.Bar :x (. h [1,]) :y (. h [0,]))))

(fig.write_html "figures/levenshtein-distances-hist.html" :auto_open False)
