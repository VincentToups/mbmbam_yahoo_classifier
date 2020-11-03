(require [dotdot [chain]])
(require [hy.contrib.loop [loop]])
(import io
        json
        [sklearn.manifold [TSNE]]
        [random [shuffle]]
        [plotnine [*]]
        [numpy :as np]
        [pandas :as pd])

(setv encoding {"--unknown--" 0
                "--stop--" 1})
(setv decoding {0 "--unknown--"
                1 "--stop--"})

(setv word-counts {})

(defn count-word [word]
  (when (not (in word word-counts))
    (setv (chain word-counts [word]) 0))
  (setv (chain word-counts [word])
        (+ 1 (chain word-counts [word]))))

(setv last-encoded 1)

(defn load-json [filename]
  (print (chain "input: {}" (format filename)))
  (with [f (io.open filename "r" :encoding "ascii")]
        (json.load f)))

(defn write-json [exp filename]
  (print (chain "output: {}" (format filename)))
  (with [f (io.open filename :mode "w" :encoding "ascii")]
        (f.write (json.dumps exp :indent 1))))

(setv data (load-json "./derived_data/deduplicated.json"))
(shuffle data)
(setv max-encoded-length 0)
(setv all_x [])
(setv all_y [])
(for [datum data]
  (setv tokens (chain datum "sanitized_question" (split " ")))
  (setv encoded-question [])
  (for [token tokens]
    (when (not (= "" token))
      (count-word token)
      (when (not (in token encoding))
        (setv (chain encoding [token]) (+ 1 last-encoded))
        (setv (chain decoding [(+ 1 last-encoded)]) token)
        (setv last-encoded (+ 1 last-encoded)))
      (chain encoded-question (append (chain encoding [token])))))
  (when (> (len encoded-question) max-encoded-length)
    (setv max-encoded-length (len encoded-question)))
  (chain all_y (append (chain datum "category")))
  (setv (chain datum "encoded_question") encoded_question))

;; Pad the encoded representations with the stop value

(for [datum data]
  (setv e (chain datum "encoded_question"))
  (setv pad-n (- max-encoded-length (len e)))
  
  (setv (chain datum "encoded_question")
        (+ e
           (* [(chain encoding "--unknown--")]
              pad-n)))
  (chain all_x (append (chain datum "encoded_question"))))

(setv embedding (chain (TSNE :n_components 2)
                       (fit_transform (np.array all_x))))
(setv df (pd.DataFrame
          {
           "x" (get embedding [(slice 0 (len embedding)) 0])
               "y" (get embedding [(slice 0 (len embedding)) 1])
               "label" all_y}))

(chain
 (+ (ggplot df (aes "x" "y"))
    (geom_point (aes :color "label")))
 (save "./figures/featurized-tsne.png"))


(setv word-counts (sorted (chain word-counts (items))
                          :key (fn [tpl] (- (chain tpl 1)))))

;; (setv feature-words
;;       (lfor [word count] word-counts
;;        :if (and (<= count 43) (>= count 3))
;;        (tuple [word count])))

(write-json { "max-encoded-length" max-encoded-length
              "encoding" encoding
              "decoding" decoding
              "word_counts" word-counts}
            "./derived_data/encoding-information.json")
(write-json data "./derived_data/encoded.json")


