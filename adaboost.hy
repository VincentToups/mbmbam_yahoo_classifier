(require [dotdot [chain]])
(require [hy.contrib.loop [loop]])
(import io
        json
        random
        [numpy :as np]
        [pandas :as pd])
(import [sklearn.ensemble [AdaBoostClassifier]]
        [sklearn.manifold [TSNE]]
        [plotnine [*]])

(defn load-json [filename]
  (print (chain "input: {}" (format filename)))
  (with [f (io.open filename "r" :encoding "ascii")]
        (json.load f)))

(defn write-json [exp filename]
  (print (chain "output: {}" (format filename)))
  (with [f (io.open filename :mode "w" :encoding "ascii")]
        (f.write (json.dumps exp :indent 1))))

(setv data (load-json "./derived_data/encoded.json"))

(for [datum data]
  (setv (chain datum "train") (< (random.random) 0.5)))

(setv train_x [])
(setv train_y [])

(setv test_x [])
(setv test_y [])

(setv train [])
(setv test [])

(setv all_x [])
(setv all_y [])
(setv all_status [])

(for [datum data]
     (setv x (if (chain datum "train") train_x test_x))
     (setv y (if (chain datum "train") train_y test_y))
     (setv subset (if (chain datum "train") train test))
     (chain x (append (chain datum "encoded_question")))
     (chain all_x (append (chain datum "encoded_question")))
     (chain all_y (append (= "experimental" (chain datum "category"))))
     (chain y (append (= "experimental" (chain datum "category"))))
     (chain all_status (append (if (chain datum "train")
                                 "train"
                                 "test")))
     (chain subset (append datum)))

(setv train_x (np.array train_x))
(setv test_x (np.array test_x))
(setv train_y (np.array train_y))
(setv test_y (np.array test_y))

(setv ab (AdaBoostClassifier :n_estimators 20))
(chain ab (fit train_x train_y))

(setv train_performance (chain ab (score train_x train_y)))
(setv test_performance (chain ab (score test_x test_y)))

(setv test_predictions (chain ab (predict test_x)))

(print
 (chain "
train acc : {}
test acc  : {}" (format train_performance test_performance)))

(setv embedding (chain (TSNE :n_components 2)
                       (fit_transform all_x)))

(setv df (pd.DataFrame
          {
           "x" (get embedding [(slice 0 (len embedding)) 0])
               "y" (get embedding [(slice 0 (len embedding)) 1])
               "label" all_y
               "status" all_status}))

(chain
 (+ (ggplot df (aes "x" "y"))
    (geom_point (aes :color "label" :shape "status")))
 (save "./figures/featurized-tsne-plus-clustering.png"))
